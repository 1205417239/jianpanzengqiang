#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "KTClipboardManager.h"
#import "KTClipboardViewController.h"
#import "KTSettings.h"


#pragma mark - 常量

static CGFloat const KTToolbarHeight = 44.0;


#pragma mark - 工具栏容器

@interface KTAccessoryContainerView : UIView

@property(nonatomic,strong) UIView *originalAccessory;
@property(nonatomic,strong) UIView *keyboardToolbar;

- (instancetype)initWithOriginalAccessory:(UIView *)original
                                   toolbar:(UIView *)toolbar;

@end


@implementation KTAccessoryContainerView

- (instancetype)initWithOriginalAccessory:(UIView *)original
                                   toolbar:(UIView *)toolbar {
    self = [super initWithFrame:CGRectZero];

    if (self) {
        _originalAccessory = original;
        _keyboardToolbar = toolbar;

        self.backgroundColor = UIColor.clearColor;

        if (_originalAccessory) {
            [self addSubview:_originalAccessory];
        }

        if (_keyboardToolbar) {
            [self addSubview:_keyboardToolbar];
        }
    }

    return self;
}


- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;

    if (self.originalAccessory) {

        CGFloat originalHeight =
            self.originalAccessory.frame.size.height;

        if (originalHeight <= 0) {
            originalHeight = 0;
        }

        CGFloat toolbarHeight =
            MIN(KTToolbarHeight, height);

        self.originalAccessory.frame =
            CGRectMake(0,
                       0,
                       width,
                       MAX(0, height - toolbarHeight));

        self.keyboardToolbar.frame =
            CGRectMake(0,
                       MAX(0, height - toolbarHeight),
                       width,
                       toolbarHeight);

    } else {

        self.keyboardToolbar.frame =
            CGRectMake(0,
                       0,
                       width,
                       height);
    }
}

@end


#pragma mark - 键盘控制器

@interface KTKeyboardController : NSObject

+ (instancetype)sharedController;

- (void)installForInput:(UIView *)input;

@end


@implementation KTKeyboardController


+ (instancetype)sharedController {

    static KTKeyboardController *controller;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        controller = [KTKeyboardController new];
    });

    return controller;
}


#pragma mark - 创建按钮

- (UIButton *)buttonWithTitle:(NSString *)title
                        action:(SEL)action {

    UIButton *button =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [button setTitle:title
            forState:UIControlStateNormal];

    button.titleLabel.font =
        [UIFont systemFontOfSize:14.0];

    [button setTitleColor:
        [UIColor colorWithWhite:0.15 alpha:1.0]
                  forState:UIControlStateNormal];

    [button addTarget:self
               action:action
     forControlEvents:UIControlEventTouchUpInside];

    button.accessibilityLabel = title;

    return button;
}


#pragma mark - 创建工具栏

- (UIView *)createToolbarForInput:(UIView *)input {

    UIToolbar *
