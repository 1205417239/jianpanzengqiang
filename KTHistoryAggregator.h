#import <Foundation/Foundation.h>
#import "KTClipboardManager.h"

@interface KTHistoryAggregator : NSObject
+ (void)mergeItems:(NSArray<KTClipboardItem *> *)items;
+ (NSArray<KTClipboardItem *> *)items;
+ (NSArray<KTClipboardItem *> *)favorites;
@end
