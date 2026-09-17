#import "KTClipboardManager.h"
#import "KTSettings.h"
#import "KTDebugLogger.h"
#include <unistd.h>

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
        KTDebugLog(@"INIT pid=%d app=%@ bundle=%@ history=%lu", getpid(), NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"] ?: @"", NSBundle.mainBundle.bundleIdentifier ?: @"", (unsigned long)saved.count);
        _mutableItems=[NSMutableArray array];
        for (NSDictionary *d in saved) if ([d isKindOfClass:NSDictionary.class]) [_mutableItems addObject:[KTClipboardItem itemWithDictionary:d]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pasteboardChanged:) name:UIPasteboardChangedNotification object:UIPasteboard.generalPasteboard];
    }
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)save {
    KTDebugLog(@"SAVE count=%lu", (unsigned long)self.mutableItems.count);
    NSMutableArray *a=[NSMutableArray arrayWithCapacity:self.mutableItems.count];
    for (KTClipboardItem *i in self.mutableItems) [a addObject:i.dictionary];
    [a writeToFile:KTStoreKey atomically:YES];
}

- (void)startMonitoring {
    KTDebugLog(@"MONITOR enabled=%d record=%d", KTEnabled(), KTRecordClipboard());
    if (!KTEnabled() || !KTRecordClipboard()) return;
}

- (void)pasteboardChanged:(NSNotification *)note {
    if (!KTEnabled() || !KTRecordClipboard()) return;
    UIPasteboard *pb=UIPasteboard.generalPasteboard;
    NSInteger change=pb.changeCount;
    KTDebugLog(@"PB change=%ld pid=%d", (long)change, getpid());
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
    NSNumber *last=[defaults objectForKey:KTLastPasteboardChange];
    if (last && last.integerValue == change) return;
    [defaults setObject:@(change) forKey:KTLastPasteboardChange];

    NSString *text=pb.string;
    KTDebugLog(@"READ text=%lu", (unsigned long)text.length);
    if (!text.length) return;

    NSString *bid=NSBundle.mainBundle.bundleIdentifier ?: @"";
    NSString *name=NSBundle.mainBundle.localizedInfoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleName"] ?: bid;
    NSDate *recordedAt=NSDate.date;
    KTDebugLog(@"CAPTURE bundle=%@ app=%@", bid, name);

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
    KTDebugLog(@"ADD count=%lu", (unsigned long)self.mutableItems.count);
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
