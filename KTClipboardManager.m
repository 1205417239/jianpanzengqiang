#import "KTClipboardManager.h"
#import "KTSettings.h"
#import <UIKit/UIKit.h>
#import <sys/file.h>
#import <fcntl.h>
#import <unistd.h>

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

- (void)saveLocked {
    int fd=open(KTLockKey.UTF8String, O_CREAT|O_RDWR, 0600);
    if (fd < 0) { [self save]; return; }
    flock(fd, LOCK_EX);
    [self reloadFromDisk];
    [self save];
    flock(fd, LOCK_UN);
    close(fd);
}

- (void)startMonitoring {
    if (!KTEnabled() || !KTRecordClipboard()) return;
}

static BOOL KTIsIgnoredProcess(void) {
    NSString *bid=NSBundle.mainBundle.bundleIdentifier ?: @"";
    return [bid isEqualToString:@"com.apple.springboard"] || [bid isEqualToString:@"com.apple.UIKit"] || bid.length == 0;
}

static BOOL KTIsForegroundApp(void) {
    UIApplication *app=UIApplication.sharedApplication;
    if (app.applicationState != UIApplicationStateActive) return NO;
    for (UIScene *scene in app.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) return YES;
    }
    return YES;
}

static NSString *KTAppName(void) {
    NSBundle *b=NSBundle.mainBundle;
    NSString *name=b.localizedInfoDictionary[@"CFBundleDisplayName"];
    if (!name.length) name=b.infoDictionary[@"CFBundleDisplayName"];
    if (!name.length) name=b.infoDictionary[@"CFBundleName"];
    return name.length ? name : (b.bundleIdentifier ?: @"未知应用");
}

- (void)pasteboardChanged:(NSNotification *)note {
    if (!KTEnabled() || !KTRecordClipboard()) return;
    if (KTIsIgnoredProcess() || !KTIsForegroundApp()) return;

    UIPasteboard *pb=UIPasteboard.generalPasteboard;
    NSInteger change=pb.changeCount;
    NSString *text=pb.string;
    if (!text.length) return;

    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
    NSNumber *last=[defaults objectForKey:KTLastPasteboardChange];
    if (last && last.integerValue == change) return;
    [defaults setObject:@(change) forKey:KTLastPasteboardChange];
    [defaults synchronize];

    NSString *bid=NSBundle.mainBundle.bundleIdentifier ?: @"";
    NSString *name=KTAppName();
    NSDate *recordedAt=NSDate.date;
    [self addCapturedText:text bundleIdentifier:bid appName:name recordedAt:recordedAt];
}

- (void)addCurrentClipboard {
    if (!KTEnabled() || !KTRecordClipboard()) return;
    if (KTIsIgnoredProcess() || !KTIsForegroundApp()) return;
    UIPasteboard *pb=UIPasteboard.generalPasteboard;
    NSInteger change=pb.changeCount;
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
    NSNumber *last=[defaults objectForKey:KTLastPasteboardChange];
    if (last && last.integerValue == change) return;
    [defaults setObject:@(change) forKey:KTLastPasteboardChange];
    [defaults synchronize];

    NSString *text=pb.string;
    if (!text.length) return;
    NSString *bid=NSBundle.mainBundle.bundleIdentifier ?: @"";
    [self addCapturedText:text bundleIdentifier:bid appName:KTAppName() recordedAt:NSDate.date];
}

- (void)addCapturedText:(NSString *)text bundleIdentifier:(NSString *)bid appName:(NSString *)name recordedAt:(NSDate *)recordedAt {
    if (!text.length) return;

    int fd=open(KTLockKey.UTF8String, O_CREAT|O_RDWR, 0600);
    if (fd >= 0) flock(fd, LOCK_EX);

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

    if (fd >= 0) { flock(fd, LOCK_UN); close(fd); }
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

- (void)setFavorite:(BOOL)favorite forItem:(KTClipboardItem *)item {
    if (!item) return;
    int fd=open(KTLockKey.UTF8String, O_CREAT|O_RDWR, 0600);
    if (fd >= 0) flock(fd, LOCK_EX);
    [self reloadFromDisk];
    for (KTClipboardItem *saved in self.mutableItems) {
        if ([saved.text isEqualToString:item.text] && fabs(saved.recordedAt.timeIntervalSince1970-item.recordedAt.timeIntervalSince1970)<0.001) {
            saved.favorite=favorite;
            break;
        }
    }
    [self save];
    if (fd >= 0) { flock(fd, LOCK_UN); close(fd); }
}

- (void)removeItem:(KTClipboardItem *)item {
    if (!item) return;
    int fd=open(KTLockKey.UTF8String, O_CREAT|O_RDWR, 0600);
    if (fd >= 0) flock(fd, LOCK_EX);
    [self reloadFromDisk];
    for (NSInteger n=(NSInteger)self.mutableItems.count-1; n>=0; n--) {
        KTClipboardItem *saved=self.mutableItems[(NSUInteger)n];
        if ([saved.text isEqualToString:item.text] && fabs(saved.recordedAt.timeIntervalSince1970-item.recordedAt.timeIntervalSince1970)<0.001) {
            [self.mutableItems removeObjectAtIndex:(NSUInteger)n];
            break;
        }
    }
    [self save];
    if (fd >= 0) { flock(fd, LOCK_UN); close(fd); }
}

- (void)clearClipboardHistory {
    int fd=open(KTLockKey.UTF8String, O_CREAT|O_RDWR, 0600);
    if (fd >= 0) flock(fd, LOCK_EX);
    [self reloadFromDisk];
    NSIndexSet *idx=[self.mutableItems indexesOfObjectsPassingTest:^BOOL(KTClipboardItem *i, NSUInteger n, BOOL *stop){ return !i.favorite; }];
    [self.mutableItems removeObjectsAtIndexes:idx];
    [self save];
    if (fd >= 0) { flock(fd, LOCK_UN); close(fd); }
}

- (void)clearImages { UIPasteboard *pb=UIPasteboard.generalPasteboard; if (pb.hasImages) pb.items=@[]; }

- (void)pasteItem:(KTClipboardItem *)item intoInput:(id<UITextInput>)input {
    if (!item.text.length || !input) return;
    UITextRange *r=input.selectedTextRange;
    if (r) [input replaceRange:r withText:item.text];
}
@end
