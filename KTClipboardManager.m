#import "KTClipboardManager.h"
#import "KTSettings.h"
#import <objc/runtime.h>
#import <sys/file.h>
#import <fcntl.h>
#include <unistd.h>

static NSString * const KTStoreKey = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.history.plist";
static NSString * const KTLockKey = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.history.lock";

static NSString *KTAppName(void) {
    NSBundle *b = NSBundle.mainBundle;
    return b.localizedInfoDictionary[@"CFBundleDisplayName"] ?: b.infoDictionary[@"CFBundleDisplayName"] ?: b.infoDictionary[@"CFBundleName"] ?: b.bundleIdentifier ?: @"未知应用";
}

static NSString *KTTextFromPasteboard(UIPasteboard *pb) {
    NSString *s = pb.string;
    return [s isKindOfClass:NSString.class] ? s : @"";
}

@interface KTClipboardManager ()
@property(nonatomic,strong) NSMutableArray<KTClipboardItem *> *mutableItems;
@end

@implementation KTClipboardItem
- (NSDictionary *)dictionary {
    return @{ @"text": self.text ?: @"",
              @"bundle": self.bundleIdentifier ?: @"",
              @"app": self.appName ?: @"",
              @"favorite": @(self.favorite),
              @"date": self.date ?: [NSDate date] };
}
+ (instancetype)itemWithDictionary:(NSDictionary *)d {
    KTClipboardItem *i = [KTClipboardItem new];
    i.text = [d[@"text"] isKindOfClass:NSString.class] ? d[@"text"] : @"";
    i.bundleIdentifier = [d[@"bundle"] isKindOfClass:NSString.class] ? d[@"bundle"] : @"";
    i.appName = [d[@"app"] isKindOfClass:NSString.class] ? d[@"app"] : @"";
    i.favorite = [d[@"favorite"] boolValue];
    i.date = [d[@"date"] isKindOfClass:NSDate.class] ? d[@"date"] : [NSDate date];
    return i;
}
@end

@interface UIPasteboard (KTClipboardHooks)
- (void)kt_setString:(NSString *)string;
- (void)kt_setItems:(NSArray *)items;
- (void)kt_setItems:(NSArray *)items options:(NSDictionary *)options;
@end

static void KTHookPasteboard(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class cls = UIPasteboard.class;
        Method m = class_getInstanceMethod(cls, @selector(setString:));
        Method h = class_getInstanceMethod(cls, @selector(kt_setString:));
        if (m && h) method_exchangeImplementations(m, h);

        m = class_getInstanceMethod(cls, @selector(setItems:));
        h = class_getInstanceMethod(cls, @selector(kt_setItems:));
        if (m && h) method_exchangeImplementations(m, h);

        m = class_getInstanceMethod(cls, @selector(setItems:options:));
        h = class_getInstanceMethod(cls, @selector(kt_setItems:options:));
        if (m && h) method_exchangeImplementations(m, h);
    });
}

@implementation KTClipboardManager
+ (instancetype)sharedManager {
    static KTClipboardManager *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ m = [self new]; });
    return m;
}

- (instancetype)init {
    if ((self = [super init])) {
        _mutableItems = [NSMutableArray array];
        [self reloadFromDisk];
        KTHookPasteboard();
    }
    return self;
}

- (void)reloadFromDisk {
    NSArray *saved = [NSArray arrayWithContentsOfFile:KTStoreKey];
    [self.mutableItems removeAllObjects];
    for (NSDictionary *d in saved) {
        if ([d isKindOfClass:NSDictionary.class]) [self.mutableItems addObject:[KTClipboardItem itemWithDictionary:d]];
    }
}

- (void)saveUnlocked {
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:self.mutableItems.count];
    for (KTClipboardItem *i in self.mutableItems) [a addObject:[i dictionary]];
    [a writeToFile:KTStoreKey atomically:YES];
}

- (void)withStoreLock:(void (^)(void))block {
    int fd = open(KTLockKey.UTF8String, O_CREAT | O_RDWR, 0600);
    if (fd < 0) { if (block) block(); return; }
    flock(fd, LOCK_EX);
    if (block) block();
    flock(fd, LOCK_UN);
    close(fd);
}

- (void)startMonitoring {
    if (KTEnabled() && KTRecordClipboard()) [self addCurrentClipboard];
}

- (void)recordCurrentClipboard {
    if (!KTEnabled() || !KTRecordClipboard()) return;
    NSString *s = KTTextFromPasteboard(UIPasteboard.generalPasteboard);
    if (!s.length) return;
    NSString *bid = NSBundle.mainBundle.bundleIdentifier ?: @"";
    [self addText:s bundleIdentifier:bid appName:KTAppName()];
}

- (void)addCurrentClipboard {
    [self recordCurrentClipboard];
}

- (void)addText:(NSString *)text bundleIdentifier:(NSString *)bid appName:(NSString *)name {
    if (!text.length || !KTEnabled() || !KTRecordClipboard()) return;

    [self withStoreLock:^{
        [self reloadFromDisk];

        KTClipboardItem *first = self.mutableItems.firstObject;
        if (first && [first.text isEqualToString:text]) {
            first.bundleIdentifier = bid ?: @"";
            first.appName = name ?: @"未知应用";
            first.date = [NSDate date];
            [self saveUnlocked];
            return;
        }

        KTClipboardItem *item = [KTClipboardItem new];
        item.text = text;
        item.bundleIdentifier = bid ?: @"";
        item.appName = name ?: @"未知应用";
        item.favorite = NO;
        item.date = [NSDate date];
        [self.mutableItems insertObject:item atIndex:0];

        NSUInteger limit = MAX(1, KTHistoryLimit());
        while (self.mutableItems.count > limit) {
            NSInteger removeIndex = -1;
            for (NSInteger idx = self.mutableItems.count - 1; idx >= 0; idx--) {
                if (!self.mutableItems[idx].favorite) { removeIndex = idx; break; }
            }
            if (removeIndex < 0) break;
            [self.mutableItems removeObjectAtIndex:removeIndex];
        }
        [self saveUnlocked];
    }];
}

- (NSArray *)items {
    if (!KTEnabled() || !KTRecordClipboard()) return @[];
    [self reloadFromDisk];
    return [self.mutableItems copy];
}

- (NSArray *)favorites {
    [self reloadFromDisk];
    NSMutableArray *a = [NSMutableArray array];
    for (KTClipboardItem *i in self.mutableItems) if (i.favorite) [a addObject:i];
    return a;
}

- (void)setFavorite:(BOOL)favorite forItem:(KTClipboardItem *)item {
    if (!item) return;
    [self withStoreLock:^{
        [self reloadFromDisk];
        for (KTClipboardItem *saved in self.mutableItems) {
            if ([saved.text isEqualToString:item.text] && [saved.date isEqualToDate:item.date]) {
                saved.favorite = favorite;
                break;
            }
        }
        [self saveUnlocked];
    }];
}

- (void)removeItem:(KTClipboardItem *)item {
    if (!item) return;
    [self withStoreLock:^{
        [self reloadFromDisk];
        for (KTClipboardItem *saved in [self.mutableItems copy]) {
            if ([saved.text isEqualToString:item.text] && [saved.date isEqualToDate:item.date]) {
                [self.mutableItems removeObject:saved];
                break;
            }
        }
        [self saveUnlocked];
    }];
}

- (void)clearClipboardHistory {
    [self withStoreLock:^{
        [self reloadFromDisk];
        NSIndexSet *idx = [self.mutableItems indexesOfObjectsPassingTest:^BOOL(KTClipboardItem *i, NSUInteger n, BOOL *stop) {
            return !i.favorite;
        }];
        [self.mutableItems removeObjectsAtIndexes:idx];
        [self saveUnlocked];
    }];
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

@implementation UIPasteboard (KTClipboardHooks)
- (void)kt_setString:(NSString *)string {
    [self kt_setString:string];
    if (self == UIPasteboard.generalPasteboard) [[KTClipboardManager sharedManager] addText:string bundleIdentifier:NSBundle.mainBundle.bundleIdentifier ?: @"" appName:KTAppName()];
}
- (void)kt_setItems:(NSArray *)items {
    [self kt_setItems:items];
    if (self == UIPasteboard.generalPasteboard) [[KTClipboardManager sharedManager] recordCurrentClipboard];
}
- (void)kt_setItems:(NSArray *)items options:(NSDictionary *)options {
    [self kt_setItems:items options:options];
    if (self == UIPasteboard.generalPasteboard) [[KTClipboardManager sharedManager] recordCurrentClipboard];
}
@end
