#import "KTClipboardManager.h"
#import "KTSettings.h"
#import <objc/message.h>
#import <sys/file.h>
#import <fcntl.h>
#import <unistd.h>

static NSString * const KTStore=@"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.history.json";
static NSString * const KTLock=@"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.history.lock";

static NSDictionary *KTRead(void){int f=open(KTLock.UTF8String,O_CREAT|O_RDONLY,0600);if(f>=0)flock(f,LOCK_SH);NSData*d=[NSData dataWithContentsOfFile:KTStore];NSDictionary*j=d?[NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:nil]:nil;if(![j isKindOfClass:NSDictionary.class])j=@{};if(f>=0){flock(f,LOCK_UN);close(f);}return j;}
static void KTWrite(NSDictionary*j){NSData*d=[NSJSONSerialization dataWithJSONObject:j options:NSJSONWritingPrettyPrinted error:nil];if(!d)return;int f=open(KTLock.UTF8String,O_CREAT|O_RDWR,0600);if(f>=0)flock(f,LOCK_EX);[d writeToFile:KTStore atomically:YES];if(f>=0){flock(f,LOCK_UN);close(f);}}
static NSMutableDictionary *KTJSON(void){NSMutableDictionary*j=[KTRead() mutableCopy];if(![j[@"history"]isKindOfClass:NSArray.class])j[@"history"]=[NSMutableArray array];if(![j[@"favorites"]isKindOfClass:NSArray.class])j[@"favorites"]=[NSMutableArray array];return j;}
static id KTFront(void){UIApplication*a=UIApplication.sharedApplication;SEL s=NSSelectorFromString(@"_accessibilityFrontMostApplication");return[a respondsToSelector:s]?((id(*)(id,SEL))objc_msgSend)(a,s):nil;}
static NSString *KTBundle(void){id a=KTFront();SEL s=@selector(bundleIdentifier);id v=(a&&[a respondsToSelector:s])?((id(*)(id,SEL))objc_msgSend)(a,s):nil;return[v isKindOfClass:NSString.class]?v:@"";}
static NSString *KTName(void){id a=KTFront();for(NSString*n in @[@"displayName",@"localizedName"]){SEL s=NSSelectorFromString(n);id v=(a&&[a respondsToSelector:s])?((id(*)(id,SEL))objc_msgSend)(a,s):nil;if([v isKindOfClass:NSString.class]&&[v length])return v;}return KTBundle();}

@implementation KTClipboardItem
- (NSDictionary*)dictionary{return @{ @"text":self.text?:@"", @"bundle":self.bundleIdentifier?:@"", @"app":self.appName?:@"", @"timestamp":@((self.recordedAt?:NSDate.date).timeIntervalSince1970), @"favorite":@(self.favorite)};}
+ (instancetype)itemWithDictionary:(NSDictionary*)d{KTClipboardItem*i=[KTClipboardItem new];i.text=[d[@"text"]isKindOfClass:NSString.class]?d[@"text"]:@"";i.bundleIdentifier=[d[@"bundle"]isKindOfClass:NSString.class]?d[@"bundle"]:@"";i.appName=[d[@"app"]isKindOfClass:NSString.class]?d[@"app"]:@"";NSNumber*t=[d[@"timestamp"]isKindOfClass:NSNumber.class]?d[@"timestamp"]:nil;i.recordedAt=t?[NSDate dateWithTimeIntervalSince1970:t.doubleValue]:NSDate.date;i.favorite=[d[@"favorite"]boolValue];return i;}
@end

@interface KTClipboardManager ()
@property(nonatomic,strong) NSMutableArray *mutableItems;
@end

@implementation KTClipboardManager
+ (instancetype)sharedManager{static KTClipboardManager*m;static dispatch_once_t once;dispatch_once(&once,^{m=[self new];});return m;}
- (instancetype)init{if((self=[super init]))self.mutableItems=[NSMutableArray array];return self;}
- (void)reloadFromDisk{NSArray*h=KTRead()[@"history"];self.mutableItems=[NSMutableArray array];for(NSDictionary*d in [h isKindOfClass:NSArray.class]?h:@[])if([d isKindOfClass:NSDictionary.class])[self.mutableItems addObject:[KTClipboardItem itemWithDictionary:d]];}
- (void)startMonitoring{[self reloadFromDisk];}
- (void)pullPasteboardChanges{if(!KTEnabled()||!KTRecordClipboard())return;UIPasteboard*p=UIPasteboard.generalPasteboard;if(!p.hasStrings&&!p.hasImages)return;NSString*b=KTBundle(),*n=KTName();for(NSString*t in p.strings)if(t.length)[self addCapturedText:t bundleIdentifier:b appName:n recordedAt:NSDate.date];}
- (void)addCurrentClipboard{[self pullPasteboardChanges];}
- (void)addCapturedText:(NSString*)t bundleIdentifier:(NSString*)b appName:(NSString*)n recordedAt:(NSDate*)date{if(!t.length)return;NSMutableDictionary*j=KTJSON();NSMutableArray*h=[j[@"history"]mutableCopy];for(NSDictionary*d in[h copy])if([d[@"text"]isEqualToString:t]){[h removeObject:d];break;}[h insertObject:@{ @"text":t, @"bundle":b?:@"", @"app":n?:@"", @"timestamp":@((date?:NSDate.date).timeIntervalSince1970), @"favorite":@NO} atIndex:0];NSUInteger lim=MAX(1,(NSUInteger)KTHistoryLimit());while(h.count>lim){NSInteger r=NSNotFound;for(NSInteger i=h.count-1;i>=0;i--)if(![h[i][@"favorite"]boolValue]){r=i;break;}if(r==NSNotFound)break;[h removeObjectAtIndex:r];}j[@"history"]=h;KTWrite(j);[self reloadFromDisk];}
- (void)addText:(NSString*)t bundleIdentifier:(NSString*)b appName:(NSString*)n{[self addCapturedText:t bundleIdentifier:b appName:n recordedAt:NSDate.date];}
- (NSArray*)items{[self reloadFromDisk];return[self.mutableItems copy];}
- (NSArray*)favorites{[self reloadFromDisk];NSMutableArray*a=[NSMutableArray array];for(KTClipboardItem*i in self.mutableItems)if(i.favorite)[a addObject:i];return a;}
- (void)setFavorite:(BOOL)v forItem:(KTClipboardItem*)item{if(!item)return;NSMutableDictionary*j=KTJSON();NSMutableArray*h=[j[@"history"]mutableCopy];for(NSUInteger i=0;i<h.count;i++){NSMutableDictionary*d=[h[i]mutableCopy];if([d[@"text"]isEqualToString:item.text]){d[@"favorite"]=@(v);h[i]=d;break;}}j[@"history"]=h;KTWrite(j);[self reloadFromDisk];}
- (void)removeItem:(KTClipboardItem*)item{if(!item)return;NSMutableDictionary*j=KTJSON();NSMutableArray*h=[j[@"history"]mutableCopy];for(NSDictionary*d in[h copy])if([d[@"text"]isEqualToString:item.text])[h removeObject:d];j[@"history"]=h;KTWrite(j);[self reloadFromDisk];}
- (void)clearClipboardHistory{NSMutableDictionary*j=KTJSON();j[@"history"]=[j[@"favorites"]mutableCopy]?:[NSMutableArray array];KTWrite(j);[self reloadFromDisk];}
- (void)clearImages{if(UIPasteboard.generalPasteboard.hasImages)UIPasteboard.generalPasteboard.items=@[];}
- (void)pasteItem:(KTClipboardItem*)item intoInput:(id<UITextInput>)input{if(!item.text.length)return;UIPasteboard.generalPasteboard.string=item.text;if(input){UITextRange*r=input.selectedTextRange;if(r)[input replaceRange:r withText:item.text];}}
@end
