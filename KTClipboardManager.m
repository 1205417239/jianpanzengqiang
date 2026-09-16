#import "KTClipboardManager.h"
#import "KTSettings.h"
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>

static NSString * const KTStoreKey = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.history.plist";
static NSString * const KTLastPasteboardChange = @"KTLastPasteboardChangeCount";
static NSString * const KTLockKey = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.history.lock";

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

- (int)lockHistory {
    int fd=open(KTLockKey.UTF8String, O_CREAT|O_RDWR, 0600);
    if (fd>=0) flock(fd, LOCK_EX);
    return fd;
}

- (void)unlockHistory:(int)fd {
    if (fd>=0) { flock(fd, LOCK_UN); close(fd); }
}

- (void)reloadFromDisk {
    NSArray *saved=[NSArray arrayWithContentsOfFile:KTStoreKey];
    [self.mutableItems removeAllObjects];
    for (NSDictionary *d in saved) if ([d isKindOfClass:NSDictionary.class]) [self.mutableItems addObject:[KTClipboardItem itemWithDictionary:d]];
}

- (void)save {
    NSMutableArray *a=[NSMutableArray arrayWithCapacity:self.mutableItems.count];
    for (KTClipboardItem *i in self.mutableItems) [a addObject:i.dictionary];
    [a writeToFile:KTStoreKey atomically:YES];
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
    [self addCapturedText:text bundleIdentifier:bid appName:name recordedAt:recordedAt];
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
    int fd=[self lockHistory];
    [self reloadFromDisk];
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
    [self unlockHistory:fd];
}

- (void)addText:(NSString *)text bundleIdentifier:(NSString *)bid appName:(NSString *)name {
    [self addCapturedText:text bundleIdentifier:bid appName:name recordedAt:NSDate.date];
}

- (NSArray *)items {
    int fd=[self lockHistory];
    [self reloadFromDisk];
    NSArray *result=[self.mutableItems copy];
    [self unlockHistory:fd];
    return result;
}

- (NSArray *)favorites {
    int fd=[self lockHistory];
    [self reloadFromDisk];
    NSMutableArray *a=[NSMutableArray array];
    for (KTClipboardItem *i in self.mutableItems) if (i.favorite) [a addObject:i];
    NSArray *result=[a copy];
    [self unlockHistory:fd];
    return result;
}

- (KTClipboardItem *)matchingItem:(KTClipboardItem *)item inArray:(NSArray *)array {
    for (KTClipboardItem *x in array) {
        if (fabs(x.recordedAt.timeIntervalSince1970-item.recordedAt.timeIntervalSince1970)<0.001 && [x.text isEqualToString:item.text ?: @""] && [x.bundleIdentifier isEqualToString:item.bundleIdentifier ?: @""]) return x;
    }
    return nil;
}

- (void)setFavorite:(BOOL)favorite forItem:(KTClipboardItem *)item {
    if (!item) return;
    int fd=[self lockHistory];
    [self reloadFromDisk];
    KTClipboardItem *target=[self matchingItem:item inArray:self.mutableItems];
    if (target) { target.favorite=favorite; [self save]; }
    [self unlockHistory:fd];
}

- (void)removeItem:(KTClipboardItem *)item {
    if (!item) return;
    int fd=[self lockHistory];
    [self reloadFromDisk];
    KTClipboardItem *target=[self matchingItem:item inArray:self.mutableItems];
    if (target) { [self.mutableItems removeObject:target]; [self save]; }
    [self unlockHistory:fd];
}

- (void)clearClipboardHistory {
    int fd=[self lockHistory];
    [self reloadFromDisk];
    NSIndexSet *idx=[self.mutableItems indexesOfObjectsPassingTest:^BOOL(KTClipboardItem *i, NSUInteger n, BOOL *stop){ return !i.favorite; }];
    [self.mutableItems removeObjectsAtIndexes:idx];
    [self save];
    [self unlockHistory:fd];
}

- (void)clearImages { UIPasteboard *pb=UIPasteboard.generalPasteboard; if (pb.hasImages) pb.items=@[]; }

- (void)pasteItem:(KTClipboardItem *)item intoInput:(id<UITextInput>)input {
    if (!item.text.length || !input) return;
    UITextRange *r=input.selectedTextRange;
    if (r) [input replaceRange:r withText:item.text];
}
@end
