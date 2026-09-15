#import "KTClipboardManager.h"
#import "KTSettings.h"

static NSString * const KTStoreKey = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.history.plist";
static NSString * const KTLastPasteboard = @"KTLastPasteboard";

@implementation KTClipboardItem
- (NSDictionary *)dictionary {
    return @{ @"text": self.text ?: @"", @"bundle": self.bundleIdentifier ?: @"", @"app": self.appName ?: @"", @"favorite": @(self.favorite) };
}
+ (instancetype)itemWithDictionary:(NSDictionary *)d {
    KTClipboardItem *i = [KTClipboardItem new];
    i.text = [d[@"text"] isKindOfClass:NSString.class] ? d[@"text"] : @"";
    i.bundleIdentifier = [d[@"bundle"] isKindOfClass:NSString.class] ? d[@"bundle"] : @"";
    i.appName = [d[@"app"] isKindOfClass:NSString.class] ? d[@"app"] : @"";
    i.favorite = [d[@"favorite"] boolValue];
    return i;
}
@end

@interface KTClipboardManager ()
@property(nonatomic,strong) NSMutableArray<KTClipboardItem *> *mutableItems;
@property(nonatomic,copy) NSString *lastString;
@end

@implementation KTClipboardManager
+ (instancetype)sharedManager { static KTClipboardManager *m; static dispatch_once_t once; dispatch_once(&once, ^{ m=[self new]; }); return m; }
- (instancetype)init {
    if ((self=[super init])) {
        NSArray *saved=[NSArray arrayWithContentsOfFile:KTStoreKey];
        _mutableItems=[NSMutableArray array];
        for (NSDictionary *d in saved) if ([d isKindOfClass:NSDictionary.class]) [_mutableItems addObject:[KTClipboardItem itemWithDictionary:d]];
    }
    return self;
}
- (void)save {
    NSMutableArray *a=[NSMutableArray array];
    for (KTClipboardItem *i in self.mutableItems) [a addObject:[i dictionary]];
    [a writeToFile:KTStoreKey atomically:YES];
}
- (void)startMonitoring { if (KTEnabled() && KTRecordClipboard()) [self addCurrentClipboard]; }
- (void)addCurrentClipboard {
    if (!KTEnabled() || !KTRecordClipboard()) return;
    UIPasteboard *pb=UIPasteboard.generalPasteboard;
    NSString *s=pb.string;
    if (s.length) {
        NSString *last=[[NSUserDefaults standardUserDefaults] stringForKey:KTLastPasteboard];
        if (![last isEqualToString:s]) {
            [[NSUserDefaults standardUserDefaults] setObject:s forKey:KTLastPasteboard];
            NSString *bid=NSBundle.mainBundle.bundleIdentifier ?: @"";
            NSString *name=NSBundle.mainBundle.localizedInfoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleName"] ?: bid;
            [self addText:s bundleIdentifier:bid appName:name];
        }
    }
}
- (void)addText:(NSString *)text bundleIdentifier:(NSString *)bid appName:(NSString *)name {
    if (!text.length) return;
    for (KTClipboardItem *i in [self.mutableItems copy]) if ([i.text isEqualToString:text]) [self.mutableItems removeObject:i];
    KTClipboardItem *i=[KTClipboardItem new]; i.text=text; i.bundleIdentifier=bid; i.appName=name; i.favorite=NO;
    [self.mutableItems insertObject:i atIndex:0];
    while (self.mutableItems.count>KTHistoryLimit()) {
        KTClipboardItem *last=self.mutableItems.lastObject;
        if (last.favorite && self.mutableItems.count>1) { [self.mutableItems removeObjectAtIndex:self.mutableItems.count-2]; }
        else [self.mutableItems removeLastObject];
    }
    [self save];
}
- (NSArray *)items { if (KTEnabled() && KTRecordClipboard()) [self addCurrentClipboard]; return [self.mutableItems copy]; }
- (NSArray *)favorites { NSMutableArray *a=[NSMutableArray array]; for (KTClipboardItem *i in self.mutableItems) if (i.favorite) [a addObject:i]; return a; }
- (void)setFavorite:(BOOL)favorite forItem:(KTClipboardItem *)item { item.favorite=favorite; [self save]; }
- (void)removeItem:(KTClipboardItem *)item { [self.mutableItems removeObject:item]; [self save]; }
- (void)clearClipboardHistory { NSIndexSet *idx=[self.mutableItems indexesOfObjectsPassingTest:^BOOL(KTClipboardItem *i, NSUInteger n, BOOL *stop){ return !i.favorite; }]; [self.mutableItems removeObjectsAtIndexes:idx]; [self save]; }
- (void)clearImages { UIPasteboard *pb=UIPasteboard.generalPasteboard; if (pb.hasImages) pb.items=@[]; }
- (void)pasteItem:(KTClipboardItem *)item intoInput:(id<UITextInput>)input {
    if (!item.text.length || !input) return;
    UITextRange *r=input.selectedTextRange;
    if (r) [input replaceRange:r withText:item.text];
}
@end
