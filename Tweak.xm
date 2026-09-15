#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "KTClipboardManager.h"
#import "KTClipboardViewController.h"
#import "KTSettings.h"


#pragma mark - 常量

static NSInteger const KTToolbarHeight = 44.0;


#pragma mark - 工具栏控制器

@interface KTKeyboardController : NSObject

+ (instancetype)sharedController;

- (void)installForInput:(UIView *)input;
- (void)removeFromInput:(UIView *)input;

@end


#pragma mark - 工具栏容器

@interface KTAccessoryContainerView : UIView

@property(nonatomic,strong) UIView *originalAccessory;
@property(nonatomic,strong) UIView *keyboardToolbar;

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

    CGFloat toolbarHeight = KTToolbarHeight;

    if (self.originalAccessory) {
        CGFloat originalHeight =
            self.originalAccessory.intrinsicContentSize.height;

        if (originalHeight <= 0 || originalHeight == UIViewNoIntrinsicMetric) {
            originalHeight = 0;
        }

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

@implementation KTKeyboardController

+ (instancetype)sharedController {
    static KTKeyboardController *controller;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        controller = [KTKeyboardController new];
    });

    return controller;
}


#pragma mark 创建按钮

- (UIButton *)buttonWithTitle:(NSString *)title
                        action:(SEL)action {

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];

    button.backgroundColor = UIColor.clearColor;

    [button setTitle:title forState:UIControlStateNormal];

    button.titleLabel.font =
        [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular];

    [button setTitleColor:
        [UIColor colorWithWhite:0.15 alpha:1.0]
                  forState:UIControlStateNormal];

    [button addTarget:self
               action:action
     forControlEvents:UIControlEventTouchUpInside];

    button.accessibilityLabel = title;

    return button;
}


#pragma mark 创建工具栏

- (UIView *)createToolbarForInput:(UIView *)input {

    UIToolbar *toolbar =
        [[UIToolbar alloc] initWithFrame:CGRectZero];

    toolbar.translucent = YES;

    toolbar.barStyle = UIBarStyleDefault;

    toolbar.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;


    UIButton *clipboard =
        [self buttonWithTitle:@"剪贴板"
                       action:@selector(clipboardTapped:)];

    UIButton *selectAll =
        [self buttonWithTitle:@"全选"
                       action:@selector(selectAllTapped:)];

    UIButton *paste =
        [self buttonWithTitle:@"粘贴"
                       action:@selector(pasteTapped:)];

    UIButton *undo =
        [self buttonWithTitle:@"撤销"
                       action:@selector(undoTapped:)];

    UIButton *dismiss =
        [self buttonWithTitle:@"收起键盘"
                       action:@selector(dismissTapped:)];

    NSArray *buttons = @[
        clipboard,
        selectAll,
        paste,
        undo,
        dismiss
    ];


    NSMutableArray *items =
        [NSMutableArray array];

    for (UIButton *button in buttons) {

        UIBarButtonItem *item =
            [[UIBarButtonItem alloc]
                initWithCustomView:button];

        [items addObject:item];

        if (button != dismiss) {

            [items addObject:
                [[UIBarButtonItem alloc]
                    initWithBarButtonSystemItem:
                        UIBarButtonSystemItemFlexibleSpace
                    target:nil
                    action:nil]];
        }
    }


    [toolbar setItems:items animated:NO];

    return toolbar;
}


#pragma mark 安装

- (void)installForInput:(UIView *)input {

    if (!input) {
        return;
    }

    if (!input.window) {
        return;
    }

    if (![input isFirstResponder]) {
        return;
    }


    /*
     防止重复安装
     */

    if ([input.inputAccessoryView
            isKindOfClass:[KTAccessoryContainerView class]]) {
        return;
    }


    UIView *originalAccessory =
        input.inputAccessoryView;


    /*
     创建五按钮工具栏
     */

    UIView *toolbar =
        [self createToolbarForInput:input];


    /*
     保留原有 accessory，
     将我们的工具栏放在最下面。
     */

    KTAccessoryContainerView *container =
        [[KTAccessoryContainerView alloc]
            initWithOriginalAccessory:originalAccessory
            toolbar:toolbar];


    container.frame =
        CGRectMake(0,
                   0,
                   UIScreen.mainScreen.bounds.size.width,
                   originalAccessory ?
                       (originalAccessory.intrinsicContentSize.height +
                        KTToolbarHeight) :
                       KTToolbarHeight);


    /*
     设置 inputAccessoryView
     */

    input.inputAccessoryView = container;


    /*
     UIKit 有时候已经处于 first responder 状态，
     设置 accessory 后不会马上重新布局。
     */

    dispatch_async(dispatch_get_main_queue(), ^{

        if (![input isFirstResponder]) {
            return;
        }

        [input reloadInputViews];
    });
}


#pragma mark 剪贴板

- (void)clipboardTapped:(UIButton *)sender {

    UIResponder *responder =
        [self currentFirstResponder];

    if (!responder) {
        return;
    }


    UIViewController *vc =
        [self currentViewControllerFromResponder:responder];

    if (!vc) {
        return;
    }


    KTClipboardViewController *clipboard =
        [KTClipboardViewController new];

    clipboard.modalPresentationStyle =
        UIModalPresentationPageSheet;


    [vc presentViewController:clipboard
                     animated:YES
                   completion:nil];
}


#pragma mark 全选

- (void)selectAllTapped:(UIButton *)sender {

    UIResponder *responder =
        [self currentFirstResponder];

    if (!responder) {
        return;
    }


    if ([responder respondsToSelector:@selector(selectAll:)]) {

        [(id)responder selectAll:nil];
    }
}


#pragma mark 粘贴

- (void)pasteTapped:(UIButton *)sender {

    UIResponder *responder =
        [self currentFirstResponder];

    if (!responder) {
        return;
    }


    if ([responder respondsToSelector:@selector(paste:)]) {

        [(id)responder paste:nil];
    }
}


#pragma mark 撤销

- (void)undoTapped:(UIButton *)sender {

    UIResponder *responder =
        [self currentFirstResponder];

    if (!responder) {
        return;
    }


    if ([responder respondsToSelector:@selector(undo:)]) {

        [(id)responder undo:nil];
    }
}


#pragma mark 收起键盘

- (void)dismissTapped:(UIButton *)sender {

    UIResponder *responder =
        [self currentFirstResponder];

    if (!responder) {
        return;
    }


    [responder resignFirstResponder];
}


#pragma mark 查找当前输入控件

- (UIResponder *)currentFirstResponder {

    UIWindow *window = nil;


    for (UIWindowScene *scene
         in UIApplication.sharedApplication.connectedScenes) {

        if (scene.activationState ==
            UISceneActivationStateForegroundActive) {

            for (UIWindow *candidate
                 in scene.windows) {

                if (candidate.isKeyWindow) {
                    window = candidate;
                    break;
                }
            }

            if (window) {
                break;
            }
        }
    }


    if (!window) {
        window =
            UIApplication.sharedApplication.keyWindow;
    }


    __block UIResponder *found = nil;


    void (^search)(UIView *) =
        ^(UIView *view) {

        if ([view isFirstResponder]) {

            found = view;
            return;
        }


        for (UIView *subview in view.subviews) {

            if (found) {
                return;
            }

            search(subview);
        }
    };


    if (window) {
        search(window);
    }


    return found;
}


#pragma mark 获取控制器

- (UIViewController *)currentViewControllerFromResponder:(UIResponder *)responder {

    UIResponder *current = responder;

    while (current) {

        if ([current isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)current;
        }

        current = current.nextResponder;
    }


    return nil;
}


#pragma mark 移除

- (void)removeFromInput:(UIView *)input {

    if (!input) {
        return;
    }


    if ([input.inputAccessoryView
            isKindOfClass:[KTAccessoryContainerView class]]) {

        KTAccessoryContainerView *container =
            (KTAccessoryContainerView *)input.inputAccessoryView;

        input.inputAccessoryView =
            container.originalAccessory;

        [input reloadInputViews];
    }
}

@end


#pragma mark - 安装辅助函数

static void KTInstallAccessoryForInput(UIView *input) {

    if (!input) {
        return;
    }

    if (![input isFirstResponder]) {
        return;
    }


    if (!input.window) {
        return;
    }


    /*
     UITextField / UITextView 是第一阶段重点支持对象。
     */

    if (![input isKindOfClass:[UITextField class]] &&
        ![input isKindOfClass:[UITextView class]]) {

        /*
         其他 UITextInput 暂时不强行处理，
         避免影响系统内部输入控件。
         */

        return;
    }


    [[KTKeyboardController sharedController]
        installForInput:input];
}


#pragma mark - UITextField

%hook UITextField

- (BOOL)becomeFirstResponder {

    BOOL result =
        %orig;


    if (result) {

        dispatch_async(dispatch_get_main_queue(), ^{

            KTInstallAccessoryForInput(self);
        });
    }


    return result;
}


- (void)layoutSubviews {

    %orig;


    if (self.isFirstResponder) {

        dispatch_async(dispatch_get_main_queue(), ^{

            KTInstallAccessoryForInput(self);
        });
    }
}


%end


#pragma mark - UITextView

%hook UITextView

- (BOOL)becomeFirstResponder {

    BOOL result =
        %orig;


    if (result) {

        dispatch_async(dispatch_get_main_queue(), ^{

            KTInstallAccessoryForInput(self);
        });
    }


    return result;
}


- (void)layoutSubviews {

    %orig;


    if (self.isFirstResponder) {

        dispatch_async(dispatch_get_main_queue(), ^{

            KTInstallAccessoryForInput(self);
        });
    }
}


%end


#pragma mark - UIResponder 备用支持

%hook UIResponder

- (BOOL)becomeFirstResponder {

    BOOL result =
        %orig;


    if (result) {

        UIResponder *responder = self;

        if ([responder isKindOfClass:[UITextField class]] ||
            [responder isKindOfClass:[UITextView class]]) {

            dispatch_async(dispatch_get_main_queue(), ^{

                KTInstallAccessoryForInput(
                    (UIView *)responder
                );
            });
        }
    }


    return result;
}

%end


#pragma mark - 启动

%ctor {

    @autoreleasepool {

        [[KTClipboardManager sharedManager]
            startMonitoring];
    }
}
