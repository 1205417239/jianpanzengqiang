#import <UIKit/UIKit.h>
#include <sqlite3.h>

@interface KTClipboardItem : NSObject
@property(nonatomic,copy) NSString *text;
@property(nonatomic,copy) NSString *bundleIdentifier;
@property(nonatomic,copy) NSString *appName;
@property(nonatomic,strong) NSDate *recordedAt;
@property(nonatomic,assign) BOOL favorite;
@property(nonatomic,assign) sqlite3_int64 databaseID;
- (NSDictionary *)dictionary;
+ (instancetype)itemWithDictionary:(NSDictionary *)d;
@end

@interface KTClipboardManager : NSObject
+ (instancetype)sharedManager;
- (void)startMonitoring;
- (void)addCurrentClipboard;
- (void)addText:(NSString *)text bundleIdentifier:(NSString *)bid appName:(NSString *)name;
- (NSArray *)items;
- (NSArray *)favorites;
- (void)setFavorite:(BOOL)favorite forItem:(KTClipboardItem *)item;
- (void)removeItem:(KTClipboardItem *)item;
- (void)clearClipboardHistory;
- (void)clearImages;
- (void)pasteItem:(KTClipboardItem *)item intoInput:(id<UITextInput>)input;
@end
