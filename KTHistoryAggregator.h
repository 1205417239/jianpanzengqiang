#import <Foundation/Foundation.h>
#import "KTClipboardManager.h"

@interface KTHistoryAggregator : NSObject
+ (void)recordItem:(KTClipboardItem *)item;
+ (NSArray<KTClipboardItem *> *)items;
+ (NSArray<KTClipboardItem *> *)favorites;
+ (void)setFavorite:(BOOL)favorite forItem:(KTClipboardItem *)item;
+ (void)removeItem:(KTClipboardItem *)item;
+ (void)clearHistoryKeepingFavorites;
@end
