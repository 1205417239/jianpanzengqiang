#import "KTClipboardManager.h"
#import "KTSettings.h"

static NSString * const KTStoreKey = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.history.plist";
static NSString * const KTLastChangeCountKey = @"KTLastPasteboardChangeCount";
static CFStringRef const KTSharedPrefsDomain = CFSTR("com.keyboardtoolskayoko");

@implementation KTClipboardItem
- (NSDictionary *)dictionary {
    return @{
        @"text": self.text ?: @"",
        @"bundle": self.bundleIdentifier ?: @"",
        @"app": self.appName ?: @"",
        @"timestamp": @([self.recordedAt timeIntervalSince1970]),
        @"changeCount": @(self.changeCount),
        @"favorite": @(self.favorite)
    };
}
+ (instancetype)itemWithDictionary:(NSDictionary *)d {
    KTClipboardItem *i = [KTClipboardItem new];
    i.text = [d[@"text"] isKindOfClass:NSString.class] ? d[@"text"] : @"";
    i.bundleIdentifier = [d[@"bundle"] isKindOfClass:NSString.class] ? d[@"bundle"] : @"";
    i.appName = [d[@"app"] isKindOfClass:NSString.class] ? d[@"app"] : @"";
    NSNumber *ts = [d[@"timestamp"] isKindOfClass:NSNumber.class] ? d[@"timestamp"] : nil;
    i.recordedAt = ts ? [NSDate dateWithTimeIntervalSince1970:ts.doubleValue] : NSDate.date;
    i.changeCount = [d[@"changeCount"] integerValue];
    i.favorite = [d[@"favorite"] boolValue];
    return i;
}
@end

@interface KTClipboardManager ()
@property(nonatomic,strong) NSMutableArray<KTClipboardItem *> *mutableItems;
@property(nonatomic,assign) NSInteger lastChangeCount;
@end

@implementation KTClipboardManager
+ (instancetype)sharedManager {
    static KTClipboardManager *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ m = [self new]; });
    return m;
}

- (instancetype)init {
    if ((self = [super init])) {
        NSArray *saved = [NSArray arrayWithContentsOfFile:KTStoreKey];
        _mutableItems = [NSMutableArray array];
        for (NSDictionary *d in saved) {
            if ([d isKindOfClass:NSDictionary.class]) [_mutableItems addObject:[KTClipboardItem itemWithDictionary:d]];
        }
        CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)KTLastChangeCountKey, KTSharedPrefsDomain);
        _lastChangeCount = value ? [(__bridge id)value integerValue] : -1;
        if (value) CFRelease(value);
    }
    return self;
}

- (void)save {
    NSMutableArray *a = [NSMutableArray array];
    for (KTClipboardItem *i in self.mutableItems) [a addObject:[i dictionary]];
    [a writeToFile:KTStoreKey atomically:YES];
}

- (void)startMonitoring {
    if (!KTEnabled() || !KTRecordClipboard()) return;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIPasteboardChangedNotification object:UIPasteboard.generalPasteboard];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pasteboardChanged:) name:UIPasteboardChangedNotification object:UIPasteboard.generalPasteboard];
    [self addCurrentClipboard];
}

- (void)pasteboardChanged:(NSNotification *)note {
    if ([NSThread isMainThread]) [self addCurrentClipboard];
    else dispatch_async(dispatch_get_main_queue(), ^{ [self addCurrentClipboard]; });
}

- (void)addCurrentClipboard {
    if (!KTEnabled() || !KTRecordClipboard()) return;
    UIPasteboard *pb = UIPasteboard.generalPasteboard;
    NSInteger changeCount = pb.changeCount;
    if (changeCount == self.lastChangeCount) return;
    self.lastChangeCount = changeCount;
    CFPreferencesSetAppValue((__bridge CFStringRef)KTLastChangeCountKey, (__bridge CFPropertyListRef)@(changeCount), KTSharedPrefsDomain);
    CFPreferencesAppSynchronize(KTSharedPrefsDomain);

    NSString *s = pb.string;
    if (!s.length) return;

    NSString *bid = NSBundle.mainBundle.bundleIdentifier ?: @"";
    NSString *name = NSBundle.mainBundle.localizedInfoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleName"] ?: bid;
    [self addText:s bundleIdentifier:bid appName:name];
}

- (void)addText:(NSString *)text bundleIdentifier:(NSString *)bid appName:(NSString *)name {
    if (!text.length) return;
    NSArray *saved = [NSArray arrayWithContentsOfFile:KTStoreKey];
    if ([saved isKindOfClass:NSArray.class]) {
        NSMutableArray *merged = [NSMutableArray array];
        for (NSDictionary *d in saved) {
            if ([d isKindOfClass:NSDictionary.class]) [merged addObject:[KTClipboardItem itemWithDictionary:d]];
        }
        for (KTClipboardItem *existing in self.mutableItems) {
            BOOL present = NO;
            if (existing.changeCount > 0) {
                for (KTClipboardItem *diskItem in merged) {
                    if (diskItem.changeCount > 0 && diskItem.changeCount == existing.changeCount && [diskItem.text isEqualToString:existing.text]) { present = YES; break; }
                }
            }
            if (!present) [merged addObject:existing];
        }
        self.mutableItems = merged;
    }
    KTClipboardItem *i = [KTClipboardItem new];
    i.text = text;
    i.bundleIdentifier = bid ?: @"";
    i.appName = name ?: @"";
    i.recordedAt = NSDate.date;
    i.changeCount = self.lastChangeCount;
    i.favorite = NO;
    for (KTClipboardItem *existing in self.mutableItems) {
        if (i.changeCount > 0 && existing.changeCount == i.changeCount && [existing.text isEqualToString:i.text]) return;
    }
    [self.mutableItems insertObject:i atIndex:0];

    NSInteger limit = MAX(100, KTHistoryLimit());
    while (self.mutableItems.count > limit) {
        NSUInteger removeIndex = NSNotFound;
        for (NSInteger n = self.mutableItems.count - 1; n >= 0; n--) {
            KTClipboardItem *candidate = self.mutableItems[n];
            if (!candidate.favorite) { removeIndex = (NSUInteger)n; break; }
        }
        if (removeIndex == NSNotFound) break;
        [self.mutableItems removeObjectAtIndex:removeIndex];
    }
    [self save];
}

- (NSArray *)items {
    if (KTEnabled() && KTRecordClipboard()) [self addCurrentClipboard];
    return [self.mutableItems copy];
}

- (NSArray *)favorites {
    NSMutableArray *a = [NSMutableArray array];
    for (KTClipboardItem *i in self.mutableItems) if (i.favorite) [a addObject:i];
    return a;
}

- (void)setFavorite:(BOOL)favorite forItem:(KTClipboardItem *)item {
    item.favorite = favorite;
    [self save];
}

- (void)removeItem:(KTClipboardItem *)item {
    [self.mutableItems removeObject:item];
    [self save];
}

- (void)clearClipboardHistory {
    NSIndexSet *idx = [self.mutableItems indexesOfObjectsPassingTest:^BOOL(KTClipboardItem *i, NSUInteger n, BOOL *stop) {
        return !i.favorite;
    }];
    [self.mutableItems removeObjectsAtIndexes:idx];
    [self save];
}

- (void)clearImages {
    UIPasteboard *pb = UIPasteboard.generalPasteboard;
    if (pb.hasImages) pb.items = @[];
}

- (void)pasteItem:(KTClipboardItem *)item intoInput:(id<UITextInput>)input {
    if (!item.text.length || !input) return;
    UITextRange *r = input.selectedTextRange;
    if (r) [input replaceRange:r withText:item.text];
}
@end
