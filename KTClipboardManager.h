#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface KTClipboardItem : NSObject
@property(nonatomic, copy) NSString *text;
@property(nonatomic, copy) NSString *bundleIdentifier;
@property(nonatomic, copy) NSString *appName;
@property(nonatomic, strong) NSDate *recordedAt;
@property(nonatomic, assign) NSInteger changeCount;
@property(nonatomic, assign) BOOL favorite;
@end

@interface KTClipboardManager : NSObject
+ (instancetype)sharedManager;
- (void)startMonitoring;
- (NSArray<KTClipboardItem *> *)items;
- (NSArray<KTClipboardItem *> *)favorites;
- (void)addCurrentClipboard;
- (void)addText:(NSString *)text bundleIdentifier:(NSString *)bundleIdentifier appName:(NSString *)appName;
- (void)setFavorite:(BOOL)favorite forItem:(KTClipboardItem *)item;
- (void)removeItem:(KTClipboardItem *)item;
- (void)clearClipboardHistory;
- (void)clearImages;
- (void)pasteItem:(KTClipboardItem *)item intoInput:(id<UITextInput>)input;
@end
