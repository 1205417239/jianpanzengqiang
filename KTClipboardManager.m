#import "KTClipboardManager.h"
#import "KTSettings.h"
#import <math.h>
#import <CoreFoundation/CoreFoundation.h>

extern NSString *KTCurrentForegroundAppName(void);
extern NSString *KTCurrentForegroundBundleIdentifier(void);

static NSString * const KTStoreKey = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.history.plist";
static NSString * const KTLastPasteboardChange = @"KTLastPasteboardChangeCount";
static NSString * const KTHistoryChangedNotification = @"KTClipboardHistoryDidChange";
static CFStringRef const KTHistoryDarwinNotification = CFSTR("com.keyboardtoolskayoko.history.changed");

static void KTHistoryDarwinCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:KTHistoryChangedNotification object:nil];
    });
}

static NSArray *KTLoadHistory(void) {
    NSArray *saved=[NSArray arrayWithContentsOfFile:KTStoreKey];
    return [saved isKindOfClass:NSArray.class] ? saved : @[];
}

static BOOL KTDictionarySame(NSDictionary *a, NSDictionary *b) {
    if (![a isKindOfClass:NSDictionary.class] || ![b isKindOfClass:NSDictionary.class]) return NO;
    NSNumber *ta=a[@"timestamp"], *tb=b[@"timestamp"];
    NSString *textA=a[@"text"], *textB=b[@"text"];
    NSString *bundleA=a[@"bundle"], *bundleB=b[@"bundle"];
    return [ta isKindOfClass:NSNumber.class] && [tb isKindOfClass:NSNumber.class] &&
           fabs(ta.doubleValue-tb.doubleValue)<0.000001 &&
           [textA isEqual:textB] && [bundleA isEqual:bundleB];
}

static NSArray *KTMergedHistory(NSArray *disk, NSArray *local) {
    NSMutableArray *merged=[NSMutableArray array];
    for (NSDictionary *d in disk) if ([d isKindOfClass:NSDictionary.class]) [merged addObject:d];
    for (NSDictionary *d in local) {
        if (![d isKindOfClass:NSDictionary.class]) continue;
        BOOL found=NO;
        for (NSDictionary *old in merged) {
            if (KTDictionarySame(d,old)) { found=YES; break; }
        }
        if (!found) [merged addObject:d];
    }
    [merged sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        double ta=[a[@"timestamp"] doubleValue];
        double tb=[b[@"timestamp"] doubleValue];
        if (ta>tb) return NSOrderedAscending;
        if (ta<tb) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    NSUInteger limit=KTHistoryLimit();
    if (limit<1) limit=200;
    if (merged.count>limit) [merged removeObjectsInRange:NSMakeRange(limit, merged.count-limit)];
    return merged;
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
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, KTHistoryDarwinCallback, KTHistoryDarwinNotification, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, KTHistoryDarwinNotification, NULL);
}

- (void)reloadFromDisk {
    NSArray *saved=KTLoadHistory();
    NSMutableArray *items=[NSMutableArray arrayWithCapacity:saved.count];
    for (NSDictionary *d in saved) if ([d isKindOfClass:NSDictionary.class]) [items addObject:[KTClipboardItem itemWithDictionary:d]];
    self.mutableItems=items;
}

- (void)save {
    NSMutableArray *local=[NSMutableArray arrayWithCapacity:self.mutableItems.count];
    for (KTClipboardItem *i in self.mutableItems) [local addObject:i.dictionary];
    NSArray *merged=KTMergedHistory(KTLoadHistory(),local);
    [merged writeToFile:KTStoreKey atomically:YES];
    [self reloadFromDisk];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), KTHistoryDarwinNotification, NULL, NULL, true);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:KTHistoryChangedNotification object:self];
    });
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

    NSString *bid=KTCurrentForegroundBundleIdentifier() ?: @"";
    NSString *name=KTCurrentForegroundAppName();
    if (!name.length) name=bid;
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
    NSString *bid=KTCurrentForegroundBundleIdentifier() ?: @"";
    NSString *name=KTCurrentForegroundAppName();
    if (!name.length) name=bid;
    [self addCapturedText:text bundleIdentifier:bid appName:name recordedAt:NSDate.date];
}

- (void)addCapturedText:(NSString *)text bundleIdentifier:(NSString *)bid appName:(NSString *)name recordedAt:(NSDate *)recordedAt {
    if (!text.length) return;
    [self reloadFromDisk];
    KTClipboardItem *i=[KTClipboardItem new];
    i.text=text;
    i.bundleIdentifier=bid ?: @"";
    i.appName=name ?: @"";
    i.recordedAt=recordedAt ?: NSDate.date;
    i.favorite=NO;
    [self.mutableItems insertObject:i atIndex:0];
    [self save];
}

- (void)addText:(NSString *)text bundleIdentifier:(NSString *)bid appName:(NSString *)name {
    [self addCapturedText:text bundleIdentifier:bid appName:name recordedAt:NSDate.date];
}

- (NSArray *)items {
    [self reloadFromDisk];
    return [self.mutableItems copy];
}

- (NSArray *)favorites {
    [self reloadFromDisk];
    NSMutableArray *a=[NSMutableArray array];
    for (KTClipboardItem *i in self.mutableItems) if (i.favorite) [a addObject:i];
    return a;
}

- (void)setFavorite:(BOOL)favorite forItem:(KTClipboardItem *)item { if (!item) return; [self reloadFromDisk]; item.favorite=favorite; [self save]; }
- (void)removeItem:(KTClipboardItem *)item { if (!item) return; [self reloadFromDisk]; [self.mutableItems removeObject:item]; [self save]; }

- (void)clearClipboardHistory {
    [self reloadFromDisk];
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
