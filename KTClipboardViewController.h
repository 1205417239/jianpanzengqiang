#import <UIKit/UIKit.h>
@interface KTClipboardViewController : UIViewController
- (instancetype)initWithInput:(id<UITextInput>)input;
@property(nonatomic,copy) void (^closeHandler)(void);
@property(nonatomic,strong) UIView *panel;
@end
