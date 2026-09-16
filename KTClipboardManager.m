#import "KTClipboardManager.h"
#import "KTSettings.h"
#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>

static NSString * const KTStoreKey = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.history.plist";
static NSString * const KTLastPasteboardChange = @"KTLastPasteboardChangeCount";
static NSString * const KTLockKey = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.history.lock";

static int KTLock(void) {
    int fd=open(KTLockKey.UTF8String, O_CREAT|O_RDWR, 0600);
    if (fd < 0) return -1;
    if (flock(fd, LOCK_EX) != 0) { close(fd); return -1; }
    return fd;
}

static void KTUnlock(int fd) {
    if (fd >= 0) { flock(fd, LOCK_UN); close(fd); }
}

@implementation KTClipboardItem
- (NSDictionary *)dictionary {
    return @{
        @"text": self.text ?: @"",
        @"bundle": self.bundleIdentifier ?: @"",
        @"app": self.appName ?: @"",
        @"timestamp": @((self.recordedAt ?: NSDate.date).timeIntervalSince1970),
        @"favorite": @(self.favorite)
    };
}
+ (instancetype)itemWithDictionary:(NSDictionary *)d {
    KTClipboardItem *i=[KTClipboardItem new];
    i.text=[d[@"text"] isKindOfClass:NSString.class] ? d[@"text"] : @"";
    i.bundleIdentifier=[d[@"bundle"] isKindOfClass:NSString.class] ? d[@"bundle"] : @"";
    i.appName=[d[@"app"] isKindOfClass:NSString.class] ? d[@"app"] : @"";
    NSNumber *ts=[d[@"timestamp"] isKindOfClass:NSNumber.class] ? d[@"timestamp"] : nil;
    i.recordedAt=ts ? [NSDate dateWithTimeIntervalSince1970:ts.doubleValue] : NSDate.date;
    i.favorite=[d[@"favorite"] boolValue];
    return i;
}
@end

@interface KTClipboardManager ()
@property(nonatomic,strong) NSMutableArray<KTClipboardItem *> *mutableItems;
@end

@implementation KTClipboardManager
+ (instancetype)sharedManager { static KTClipboardManager *m; static dispatch_once_t once; dispatch_once(&once, ^{ m=[self new]; }); return m; }

- (instancetype)init {
    if ((self=[super init])) {
        _mutableItems=[NSMutableArray array];
        [self reloadFromDisk];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pasteboardChanged:) name:UIPasteboardChangedNotification object:UIPasteboard.generalPasteboard];
    }
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)save {
    int fd=KTLock();
    NSArray *disk=[NSArray arrayWithContentsOfFile:KTStoreKey];
    NSMutableArray *merged=[NSMutableArray array];
    for (NSDictionary *d in disk) if ([d isKindOfClass:NSDictionary.class]) [merged addObject:d];
    for (KTClipboardItem *item in self.mutableItems) {
        NSDictionary *d=item.dictionary;
        BOOL exists=NO;
        NSNumber *ts=d[@"timestamp"];
        NSString *text=d[@"text"];
        NSString *bundle=d[@"bundle"];
        for (NSDictionary *e in merged) {
            if ([e[@"timestamp"] doubleValue] == [ts doubleValue] && [e[@"text"] isEqual:text] && [e[@"bundle"] isEqual:bundle]) { exists=YES; break; }
        }
        if (!exists) [merged addObject:d];
    }
    [merged sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"timestamp"] doubleValue] > [a[@"timestamp"] doubleValue] ? NSOrderedAscending : ([b[@"timestamp"] doubleValue] < [a[@"timestamp"] doubleValue] ? NSOrderedDescending : NSOrderedSame);
    }];
    while (merged.count > KTHistoryLimit()) {
        NSUInteger removeIndex=NSNotFound;
        for (NSInteger n=(NSInteger)merged.count-1; n>=0; n--) if (![merged[(NSUInteger)n][@"favorite"] boolValue]) { removeIndex=(NSUInteger)n; break; }
        if (removeIndex==NSNotFound) break;
        [merged removeObjectAtIndex:removeIndex];
    }
    [merged writeToFile:KTStoreKey atomically:YES];
    [self.mutableItems removeAllObjects];
    for (NSDictionary *d in merged) [self.mutableItems addObject:[KTClipboardItem itemWithDictionary:d]];
    KTUnlock(fd);
}

- (void)reloadFromDisk {
    int fd=KTLock();
    NSArray *saved=[NSArray arrayWithContentsOfFile:KTStoreKey];
    NSMutableArray *fresh=[NSMutableArray array];
    for (NSDictionary *d in saved) if ([d isKindOfClass:NSDictionary.class]) [fresh addObject:[KTClipboardItem itemWithDictionary:d]];
    [fresh sortUsingComparator:^NSComparisonResult(KTClipboardItem *a, KTClipboardItem *b) {
        return [b.recordedAt compare:a.recordedAt];
    }];
    [self.mutableItems removeAllObjects];
    [self.mutableItems addObjectsFromArray:fresh];
    KTUnlock(fd);
}

- (void)startMonitoring {
    if (!KTEnabled() || !KTRecordClipboard()) return;
}

- (void)pasteboardChanged:(NSNotification *)note {
    if (!KTEnabled() || !KTRecordClipboard()) return;
    UIPasteboard *pb=UIPasteboard.generalPasteboard;
    NSInteger change=pb.changeCount;
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
    NSNumber *last=[defaults objectForKey:KTLastPasteboardChange];
    if (last && last.integerValue == change) return;
    [defaults setObject:@(change) forKey:KTLastPasteboardChange];

    NSString *text=pb.string;
    if (!text.length) return;

    NSString *bid=NSBundle.mainBundle.bundleIdentifier ?: @"";
    NSString *name=NSBundle.mainBundle.localizedInfoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleName"] ?: bid;
    NSDate *recordedAt=NSDate.date;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self addCapturedText:text bundleIdentifier:bid appName:name recordedAt:recordedAt];
    });
}

- (void)addCurrentClipboard {
    if (!KTEnabled() || !KTRecordClipboard()) return;
    UIPasteboard *pb=UIPasteboard.generalPasteboard;
    NSInteger change=pb.changeCount;
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
    NSNumber *last=[defaults objectForKey:KTLastPasteboardChange];
    if (last && last.integerValue == change) return;
    [defaults setObject:@(change) forKey:KTLastPasteboardChange];

    NSString *text=pb.string;
    if (!text.length) return;
    NSString *bid=NSBundle.mainBundle.bundleIdentifier ?: @"";
    NSString *name=NSBundle.mainBundle.localizedInfoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleName"] ?: bid;
    [self addCapturedText:text bundleIdentifier:bid appName:name recordedAt:NSDate.date];
}

- (void)addCapturedText:(NSString *)text bundleIdentifier:(NSString *)bid appName:(NSString *)name recordedAt:(NSDate *)recordedAt {
    if (!text.length) return;
    KTClipboardItem *i=[KTClipboardItem new];
    i.text=text;
    i.bundleIdentifier=bid ?: @"";
    i.appName=name ?: @"";
    i.recordedAt=recordedAt ?: NSDate.date;
    i.favorite=NO;
    [self.mutableItems insertObject:i atIndex:0];
    while (self.mutableItems.count>KTHistoryLimit()) {
        NSUInteger removeIndex=NSNotFound;
        for (NSInteger n=(NSInteger)self.mutableItems.count-1; n>=0; n--) {
            if (!self.mutableItems[(NSUInteger)n].favorite) { removeIndex=(NSUInteger)n; break; }
        }
        if (removeIndex==NSNotFound) break;
        [self.mutableItems removeObjectAtIndex:removeIndex];
    }
    [self save];
}

- (void)addText:(NSString *)text bundleIdentifier:(NSString *)bid appName:(NSString *)name {
    [self addCapturedText:text bundleIdentifier:bid appName:name recordedAt:NSDate.date];
}

- (NSArray *)items {
    return [self.mutableItems copy];
}

- (NSArray *)favorites {
    NSMutableArray *a=[NSMutableArray array];
    for (KTClipboardItem *i in self.mutableItems) if (i.favorite) [a addObject:i];
    return a;
}

- (void)setFavorite:(BOOL)favorite forItem:(KTClipboardItem *)item { if (!item) return; item.favorite=favorite; [self save]; }
- (void)removeItem:(KTClipboardItem *)item { if (!item) return; [self.mutableItems removeObject:item]; [self save]; }

- (void)clearClipboardHistory {
    NSIndexSet *idx=[self.mutableItems indexesOfObjectsPassingTest:^BOOL(KTClipboardItem *i, NSUInteger n, BOOL *stop){ return !i.favorite; }];
    [self.mutableItems removeObjectsAtIndexes:idx];
    [self save];
}

- (void)clearImages { UIPasteboard *pb=UIPasteboard.generalPasteboard; if (pb.hasImages) pb.items=@[]; }

- (void)pasteItem:(KTClipboardItem *)item intoInput:(id<UITextInput>)input {
    if (!item.text.length || !input) return;
    UITextRange *r=input.selectedTextRange;
    if (r) [input replaceRange:r withText:item.text];
}
@end
