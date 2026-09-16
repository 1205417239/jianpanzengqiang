#import "KTClipboardManager.h"
#import "KTSettings.h"
#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>

static NSString * const KTStoreKey = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.history.plist";
static NSString * const KTLockKey = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.history.lock";
static NSString * const KTStateKey = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.state.plist";
static NSString * const KTLastChangeKey = @"lastChangeCount";

@implementation KTClipboardItem
- (NSDictionary *)dictionary {
    NSMutableDictionary *d=[NSMutableDictionary dictionaryWithDictionary:@{ @"text": self.text ?: @"", @"bundle": self.bundleIdentifier ?: @"", @"app": self.appName ?: @"", @"timestamp": @((self.recordedAt ?: NSDate.date).timeIntervalSince1970), @"favorite": @(self.favorite) }];
    if(self.imageData.length) d[@"imageData"]=self.imageData;
    return d;
}
+ (instancetype)itemWithDictionary:(NSDictionary *)d {
    KTClipboardItem *i=[KTClipboardItem new];
    i.text=[d[@"text"] isKindOfClass:NSString.class] ? d[@"text"] : @"";
    i.bundleIdentifier=[d[@"bundle"] isKindOfClass:NSString.class] ? d[@"bundle"] : @"";
    i.appName=[d[@"app"] isKindOfClass:NSString.class] ? d[@"app"] : @"";
    NSNumber *ts=[d[@"timestamp"] isKindOfClass:NSNumber.class] ? d[@"timestamp"] : nil;
    i.recordedAt=ts ? [NSDate dateWithTimeIntervalSince1970:ts.doubleValue] : NSDate.date;
    i.imageData=[d[@"imageData"] isKindOfClass:NSData.class] ? d[@"imageData"] : nil;
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
        [self loadItems];
    }
    return self;
}
- (void)dealloc {}
- (int)lockFile {
    int fd=open(KTLockKey.UTF8String,O_CREAT|O_RDWR,0600);
    if(fd>=0) flock(fd,LOCK_EX);
    return fd;
}
- (void)unlockFile:(int)fd { if(fd>=0){ flock(fd,LOCK_UN); close(fd); } }
- (void)loadItems {
    NSArray *saved=[NSArray arrayWithContentsOfFile:KTStoreKey];
    [_mutableItems removeAllObjects];
    for(NSDictionary *d in saved) if([d isKindOfClass:NSDictionary.class]) [_mutableItems addObject:[KTClipboardItem itemWithDictionary:d]];
}
- (void)saveUnlocked {
    [[NSFileManager defaultManager] createDirectoryAtPath:@"/var/mobile/Library/Preferences" withIntermediateDirectories:YES attributes:nil error:nil];
    NSMutableArray *a=[NSMutableArray arrayWithCapacity:self.mutableItems.count];
    for(KTClipboardItem *i in self.mutableItems) [a addObject:i.dictionary];
    [a writeToFile:KTStoreKey atomically:YES];
}
- (void)save { int fd=[self lockFile]; [self saveUnlocked]; [self unlockFile:fd]; }
- (void)startMonitoring {}
- (void)pasteboardChanged:(NSNotification *)note {}
- (void)addCurrentClipboard {
    if(!KTEnabled() || !KTRecordClipboard()) return;
    NSString *bid=NSBundle.mainBundle.bundleIdentifier ?: @"";
    NSString *name=NSBundle.mainBundle.localizedInfoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleName"] ?: bid;
    [self recordCurrentClipboardFromBundleIdentifier:bid appName:name];
}
- (void)recordCurrentClipboardFromBundleIdentifier:(NSString *)bid appName:(NSString *)name {
    if(!KTEnabled() || !KTRecordClipboard()) return;
    UIPasteboard *pb=UIPasteboard.generalPasteboard;
    NSString *s=pb.string ?: @"";
    UIImage *image=pb.image;
    if(!s.length && !image) return;
    NSInteger change=pb.changeCount;
    int fd=[self lockFile];
    NSDictionary *state=[NSDictionary dictionaryWithContentsOfFile:KTStateKey];
    NSInteger last=[state[KTLastChangeKey] integerValue];
    if(last==change){ [self unlockFile:fd]; return; }
    [self loadItems];
    KTClipboardItem *i=[KTClipboardItem new];
    i.text=s.length ? s : @"图片"; i.bundleIdentifier=bid ?: @""; i.appName=name ?: @""; i.recordedAt=NSDate.date; i.favorite=NO;
    if(image) i.imageData=UIImagePNGRepresentation(image);
    [self.mutableItems insertObject:i atIndex:0];
    while(self.mutableItems.count>KTHistoryLimit()){
        NSUInteger removeIndex=NSNotFound;
        for(NSInteger n=(NSInteger)self.mutableItems.count-1;n>=0;n--) if(!self.mutableItems[(NSUInteger)n].favorite){ removeIndex=(NSUInteger)n; break; }
        if(removeIndex==NSNotFound) break;
        [self.mutableItems removeObjectAtIndex:removeIndex];
    }
    [self saveUnlocked];
    [@{KTLastChangeKey:@(change)} writeToFile:KTStateKey atomically:YES];
    [self unlockFile:fd];
}
- (void)addText:(NSString *)text bundleIdentifier:(NSString *)bid appName:(NSString *)name {
    if(!text.length) return;
    int fd=[self lockFile];
    [self loadItems];
    KTClipboardItem *i=[KTClipboardItem new]; i.text=text; i.bundleIdentifier=bid ?: @""; i.appName=name ?: @""; i.recordedAt=NSDate.date;
    [self.mutableItems insertObject:i atIndex:0];
    while(self.mutableItems.count>KTHistoryLimit()){
        NSUInteger removeIndex=NSNotFound;
        for(NSInteger n=(NSInteger)self.mutableItems.count-1;n>=0;n--) if(!self.mutableItems[(NSUInteger)n].favorite){ removeIndex=(NSUInteger)n; break; }
        if(removeIndex==NSNotFound) break;
        [self.mutableItems removeObjectAtIndex:removeIndex];
    }
    [self saveUnlocked];
    [self unlockFile:fd];
}
- (NSArray *)items { int fd=[self lockFile]; [self loadItems]; NSArray *a=[self.mutableItems copy]; [self unlockFile:fd]; return a; }
- (NSArray *)favorites { int fd=[self lockFile]; [self loadItems]; NSMutableArray *a=[NSMutableArray array]; for(KTClipboardItem *i in self.mutableItems) if(i.favorite) [a addObject:i]; [self unlockFile:fd]; return a; }
- (void)setFavorite:(BOOL)favorite forItem:(KTClipboardItem *)item { if(!item)return; int fd=[self lockFile]; [self loadItems]; for(KTClipboardItem *i in self.mutableItems) if(i==item || ([i.text isEqualToString:item.text] && fabs(i.recordedAt.timeIntervalSince1970-item.recordedAt.timeIntervalSince1970)<0.001)){ i.favorite=favorite; break; } [self saveUnlocked]; [self unlockFile:fd]; }
- (void)removeItem:(KTClipboardItem *)item { if(!item)return; int fd=[self lockFile]; [self loadItems]; NSUInteger idx=[self.mutableItems indexOfObject:item]; if(idx==NSNotFound){ for(NSUInteger n=0;n<self.mutableItems.count;n++){ KTClipboardItem *i=self.mutableItems[n]; if([i.text isEqualToString:item.text] && fabs(i.recordedAt.timeIntervalSince1970-item.recordedAt.timeIntervalSince1970)<0.001){ idx=n; break; } } } if(idx!=NSNotFound)[self.mutableItems removeObjectAtIndex:idx]; [self saveUnlocked]; [self unlockFile:fd]; }
- (void)clearClipboardHistory { int fd=[self lockFile]; [self loadItems]; NSIndexSet *idx=[self.mutableItems indexesOfObjectsPassingTest:^BOOL(KTClipboardItem *i,NSUInteger n,BOOL *stop){ return !i.favorite; }]; [self.mutableItems removeObjectsAtIndexes:idx]; [self saveUnlocked]; [self unlockFile:fd]; }
- (void)clearImages { UIPasteboard *pb=UIPasteboard.generalPasteboard; if(pb.hasImages) pb.items=@[]; }
- (void)pasteItem:(KTClipboardItem *)item intoInput:(id<UITextInput>)input { if(!item.text.length||!input)return; UITextRange *r=input.selectedTextRange; if(r)[input replaceRange:r withText:item.text]; }
@end
