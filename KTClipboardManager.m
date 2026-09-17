#import "KTClipboardManager.h"
#import "KTSettings.h"
#import <objc/message.h>
#import <sys/file.h>
#import <fcntl.h>
#import <unistd.h>

static NSString * const KTStore=@"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.history.json";
static NSString * const KTLock=@"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.history.lock";

static NSDictionary *KTRead(void){
    int f=open(KTLock.UTF8String,O_CREAT|O_RDONLY,0600);
    if(f>=0)flock(f,LOCK_SH);
    NSData*d=[NSData dataWithContentsOfFile:KTStore];
    NSDictionary*j=d?[NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:nil]:nil;
    if(![j isKindOfClass:NSDictionary.class])j=@{};
    if(f>=0){flock(f,LOCK_UN);close(f);}
    return j;
}

static void KTWrite(NSDictionary*j){
    NSData*d=[NSJSONSerialization dataWithJSONObject:j options:0 error:nil];
    if(!d)return;
    int f=open(KTLock.UTF8String,O_CREAT|O_RDWR,0600);
    if(f>=0)flock(f,LOCK_EX);
    [d writeToFile:KTStore atomically:YES];
    if(f>=0){flock(f,LOCK_UN);close(f);}
}

static NSMutableDictionary *KTJSON(void){
    NSMutableDictionary*j=[KTRead() mutableCopy];
    if(![j isKindOfClass:NSMutableDictionary.class])j=[NSMutableDictionary dictionary];
    if(![j[@"history"]isKindOfClass:NSArray.class])j[@"history"]=[NSMutableArray array];
    if(![j[@"favorites"]isKindOfClass:NSArray.class])j[@"favorites"]=[NSMutableArray array];
    return j;
}

static id KTFront(void){
    UIApplication*a=UIApplication.sharedApplication;
    SEL s=NSSelectorFromString(@"_accessibilityFrontMostApplication");
    return[a respondsToSelector:s]?((id(*)(id,SEL))objc_msgSend)(a,s):nil;
}

static NSString *KTBundle(void){
    id a=KTFront();
    SEL s=@selector(bundleIdentifier);
    id v=(a&&[a respondsToSelector:s])?((id(*)(id,SEL))objc_msgSend)(a,s):nil;
    return[v isKindOfClass:NSString.class]?v:@"";
}

@implementation KTClipboardItem
- (NSDictionary*)dictionary{return @{@"text":self.text?:@"",@"bundle":self.bundleIdentifier?:@"",@"app":self.appName?:@"",@"timestamp":@((self.recordedAt?:NSDate.date).timeIntervalSince1970),@"favorite":@(self.favorite)};}
+ (instancetype)itemWithDictionary:(NSDictionary*)d{KTClipboardItem*i=[KTClipboardItem new];i.text=[d[@"text"]isKindOfClass:NSString.class]?d[@"text"]:@"";i.bundleIdentifier=[d[@"bundle"]isKindOfClass:NSString.class]?d[@"bundle"]:@"";i.appName=[d[@"app"]isKindOfClass:NSString.class]?d[@"app"]:@"";NSNumber*t=[d[@"timestamp"]isKindOfClass:NSNumber.class]?d[@"timestamp"]:nil;i.recordedAt=t?[NSDate dateWithTimeIntervalSince1970:t.doubleValue]:NSDate.date;i.favorite=[d[@"favorite"]boolValue];return i;}
@end

@interface KTClipboardManager ()
@property(nonatomic,strong) NSMutableArray *mutableItems;
@property(nonatomic,assign) NSInteger lastChangeCount;

@end

@implementation KTClipboardManager
+ (instancetype)sharedManager{static KTClipboardManager*m;static dispatch_once_t once;dispatch_once(&once,^{m=[self new];});return m;}
- (instancetype)init{if((self=[super init])){self.mutableItems=[NSMutableArray array];self.lastChangeCount=UIPasteboard.generalPasteboard.changeCount;}return self;}
- (void)reloadFromDisk{NSArray*h=KTRead()[@"history"];self.mutableItems=[NSMutableArray array];for(NSDictionary*d in [h isKindOfClass:NSArray.class]?h:@[])if([d isKindOfClass:NSDictionary.class])[self.mutableItems addObject:[KTClipboardItem itemWithDictionary:d]];}
- (void)startMonitoring{[self reloadFromDisk];self.lastChangeCount=UIPasteboard.generalPasteboard.changeCount;}
- (void)pullPasteboardChanges{
    if(!KTEnabled()||!KTRecordClipboard())return;
    static dispatch_queue_t q;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ q=dispatch_queue_create("com.keyboardtoolskayoko.capture", DISPATCH_QUEUE_SERIAL); });
    dispatch_async(q, ^{
        if(!KTEnabled()||!KTRecordClipboard())return;
        UIPasteboard *p=UIPasteboard.generalPasteboard;
        NSInteger changeCount=p.changeCount;
        if(changeCount==self.lastChangeCount)return;
        NSString *text=p.string;
        if(![text isKindOfClass:NSString.class] || text.length==0){
            self.lastChangeCount=changeCount;
            return;
        }
        NSDate *date=NSDate.date;
        [self addCapturedText:text bundleIdentifier:@"" appName:@"" recordedAt:date];
        self.lastChangeCount=changeCount;
    });
}
- (void)addCurrentClipboard{[self pullPasteboardChanges];}
- (void)addCapturedText:(NSString*)t bundleIdentifier:(NSString*)b appName:(NSString*)n recordedAt:(NSDate*)date{
    if(!t.length)return;
    NSMutableDictionary*j=KTJSON();
    NSMutableArray*h=[j[@"history"]mutableCopy];
    NSMutableDictionary *record=[@{@"text":t,@"bundle":b?:@"",@"app":n?:@"",@"timestamp":@((date?:NSDate.date).timeIntervalSince1970),@"favorite":@NO} mutableCopy];
    [h insertObject:record atIndex:0];
    NSUInteger lim=MAX(1,(NSUInteger)KTHistoryLimit());
    while(h.count>lim){
        NSInteger r=NSNotFound;
        for(NSInteger i=h.count-1;i>=0;i--)if(![h[i][@"favorite"]boolValue]){r=i;break;}
        if(r==NSNotFound)break;
        [h removeObjectAtIndex:r];
    }
    j[@"history"]=h;
    KTWrite(j);
}
- (void)addText:(NSString*)t bundleIdentifier:(NSString*)b appName:(NSString*)n{[self addCapturedText:t bundleIdentifier:b appName:n recordedAt:NSDate.date];}
- (NSArray*)items{[self reloadFromDisk];return[self.mutableItems copy];}
- (NSArray*)favorites{[self reloadFromDisk];NSMutableArray*a=[NSMutableArray array];for(KTClipboardItem*i in self.mutableItems)if(i.favorite)[a addObject:i];return a;}
- (void)setFavorite:(BOOL)v forItem:(KTClipboardItem*)item{if(!item)return;NSMutableDictionary*j=KTJSON();NSMutableArray*h=[j[@"history"]mutableCopy];for(NSUInteger i=0;i<h.count;i++){NSMutableDictionary*d=[h[i]mutableCopy];if([d[@"text"]isEqualToString:item.text]){d[@"favorite"]=@(v);h[i]=d;break;}}j[@"history"]=h;KTWrite(j);[self reloadFromDisk];}
- (void)removeItem:(KTClipboardItem*)item{if(!item)return;NSMutableDictionary*j=KTJSON();NSMutableArray*h=[j[@"history"]mutableCopy];for(NSDictionary*d in[h copy])if([d[@"text"]isEqualToString:item.text])[h removeObject:d];j[@"history"]=h;KTWrite(j);[self reloadFromDisk];}
- (void)clearClipboardHistory{NSMutableDictionary*j=KTJSON();j[@"history"]=[NSMutableArray array];KTWrite(j);[self reloadFromDisk];}
- (void)clearImages{if(UIPasteboard.generalPasteboard.hasImages)UIPasteboard.generalPasteboard.items=@[];}
- (void)pasteItem:(KTClipboardItem*)item intoInput:(id<UITextInput>)input{if(!item.text.length)return;UIPasteboard.generalPasteboard.string=item.text;if(input){UITextRange*r=input.selectedTextRange;if(r)[input replaceRange:r withText:item.text];}}
@end
