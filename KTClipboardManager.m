#import "KTClipboardManager.h"
#import "KTSettings.h"

static NSString * const KTStoreKey = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.history.plist";
static NSString * const KTLastPasteboardChange = @"KTLastPasteboardChangeCount";

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
        NSArray *saved=[NSArray arrayWithContentsOfFile:KTStoreKey];
        _mutableItems=[NSMutableArray array];
        for (NSDictionary *d in saved) if ([d isKindOfClass:NSDictionary.class]) [_mutableItems addObject:[KTClipboardItem itemWithDictionary:d]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pasteboardChanged:) name:UIPasteboardChangedNotification object:UIPasteboard.generalPasteboard];
    }
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

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

#import "KTHistoryAggregator.h"
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>

static NSString * const KTAStore = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.aggregate.plist";
static NSString * const KTALock = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.aggregate.lock";

static NSArray *KTALoad(void) {
    NSArray *a = [NSArray arrayWithContentsOfFile:KTAStore];
    return [a isKindOfClass:NSArray.class] ? a : @[];
}

static int KTALockFD(void) {
    return open(KTALock.UTF8String, O_CREAT | O_RDWR, 0600);
}

static NSString *KTAKey(NSDictionary *d) {
    return [NSString stringWithFormat:@"%.6f|%@|%@",
            [d[@"timestamp"] doubleValue],
            d[@"bundle"] ?: @"",
            d[@"text"] ?: @""];
}

@implementation KTHistoryAggregator

+ (void)mergeItems:(NSArray<KTClipboardItem *> *)items {
    if (!items.count) return;

    int fd = KTALockFD();
    if (fd < 0) return;
    flock(fd, LOCK_EX);

    NSMutableArray *all = [KTALoad() mutableCopy];
    NSMutableSet *keys = [NSMutableSet setWithCapacity:all.count + items.count];
    for (NSDictionary *d in all) {
        if ([d isKindOfClass:NSDictionary.class]) [keys addObject:KTAKey(d)];
    }

    for (KTClipboardItem *item in items) {
        if (!item.text.length) continue;
        NSDictionary *d = [item dictionary];
        NSString *key = KTAKey(d);
        if ([keys containsObject:key]) continue;
        [keys addObject:key];
        [all addObject:d];
    }

    [all sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSTimeInterval ta = [a[@"timestamp"] doubleValue];
        NSTimeInterval tb = [b[@"timestamp"] doubleValue];
        if (ta > tb) return NSOrderedAscending;
        if (ta < tb) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    NSUInteger limit = KTHistoryLimit();
    while (all.count > limit) [all removeLastObject];
    [all writeToFile:KTAStore atomically:YES];

    flock(fd, LOCK_UN);
    close(fd);
}

+ (NSArray<KTClipboardItem *> *)items {
    int fd = KTALockFD();
    if (fd < 0) return @[];
    flock(fd, LOCK_SH);

    NSArray *saved = KTALoad();
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:saved.count];
    for (NSDictionary *d in saved) {
        if ([d isKindOfClass:NSDictionary.class]) {
            [result addObject:[KTClipboardItem itemWithDictionary:d]];
        }
    }

    flock(fd, LOCK_UN);
    close(fd);
    return result;
}

+ (NSArray<KTClipboardItem *> *)favorites {
    NSMutableArray *result = [NSMutableArray array];
    for (KTClipboardItem *item in self.items) {
        if (item.favorite) [result addObject:item];
    }
    return result;
}

@end

