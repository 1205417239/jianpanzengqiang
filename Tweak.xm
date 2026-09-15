#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "KTClipboardManager.h"
#import "KTClipboardViewController.h"
#import "KTSettings.h"


static CGFloat const KTToolbarHeight = 44.0;


#pragma mark - 工具栏容器

@interface KTAccessoryContainerView : UIView

@property(nonatomic, strong) UIView *originalAccessory;
@property(nonatomic, strong) UIView *keyboardToolbar;

- (instancetype)initWithOriginalAccessory:(UIView *)originalAccessory
                                   toolbar:(UIView *)toolbar;

@end


@implementation KTAccessoryContainerView

- (instancetype)initWithOriginalAccessory:(UIView *)originalAccessory
                                   toolbar:(UIView *)toolbar
{
    self = [super initWithFrame:CGRectZero];

    if (self) {
        _originalAccessory = originalAccessory;
        _keyboardToolbar = toolbar;

        self.backgroundColor = UIColor.clearColor;

        if (originalAccessory) {
            [self addSubview:originalAccessory];
        }

        if (toolbar) {
            [self addSubview:toolbar];
        }
    }

    return self;
}


- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;

    if (self.originalAccessory) {

        CGFloat toolbarHeight = KTToolbarHeight;

        if (height < toolbarHeight) {
            toolbarHeight = height;
        }

        CGFloat originalHeight =
            MAX(0.0, height - toolbarHeight);

        self.originalAccessory.frame =
            CGRectMake(0.0,
                       0.0,
                       width,
                       originalHeight);

        self.keyboardToolbar.frame =
            CGRectMake(0.0,
                       originalHeight,
                       width,
                       toolbarHeight);

    } else {

        self.keyboardToolbar.frame =
            CGRectMake(0.0,
                       0.0,
                       width,
                       height);
    }
}

@end


#pragma mark - 键盘控制器

@interface KTKeyboardController : NSObject

+ (instancetype)sharedController;

- (void)installForTextField:(UITextField *)textField;
- (void)installForTextView:(UITextView *)textView;

@end


@implementation KTKeyboardController


+ (instancetype)sharedController
{
    static KTKeyboardController *controller;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        controller = [KTKeyboardController new];
    });

    return controller;
}


#pragma mark - 创建按钮

- (UIButton *)buttonWithTitle:(NSString *)title
                        action:(SEL)action
{
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

- (UIView *)createToolbar
{
    UIToolbar *toolbar =
        [[UIToolbar alloc] initWithFrame:CGRectZero];

    toolbar.translucent = YES;
    toolbar.barStyle = UIBarStyleDefault;


    /*
     五个固定功能：

     剪贴板
     全选
     粘贴
     撤销
     收起键盘
     */

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


    for (NSUInteger i = 0;
         i < buttons.count;
         i++) {

        UIButton *button = buttons[i];

        UIBarButtonItem *item =
            [[UIBarButtonItem alloc]
                initWithCustomView:button];

        [items addObject:item];


        if (i < buttons.count - 1) {

            UIBarButtonItem *space =
                [[UIBarButtonItem alloc]
                    initWithBarButtonSystemItem:
                        UIBarButtonSystemItemFlexibleSpace
                    target:nil
                    action:nil];

            [items addObject:space];
        }
    }


    [toolbar setItems:items animated:NO];

    return toolbar;
}


#pragma mark - UITextField 安装

- (void)installForTextField:(UITextField *)textField
{
    if (!textField) {
        return;
    }

    if (!textField.window) {
        return;
    }

    if (!textField.isFirstResponder) {
        return;
    }


    /*
     防止重复安装
     */

    if ([textField.inputAccessoryView
            isKindOfClass:
                [KTAccessoryContainerView class]]) {

        return;
    }


    UIView *originalAccessory =
        textField.inputAccessoryView;


    UIView *toolbar =
        [self createToolbar];


    KTAccessoryContainerView *container =
        [[KTAccessoryContainerView alloc]
            initWithOriginalAccessory:originalAccessory
            toolbar:toolbar];


    CGFloat originalHeight = 0.0;


    if (originalAccessory) {

        originalHeight =
            originalAccessory.frame.size.height;

        if (originalHeight < 0.0) {
            originalHeight = 0.0;
        }
    }


    container.frame =
        CGRectMake(0.0,
                   0.0,
                   UIScreen.mainScreen.bounds.size.width,
                   originalHeight + KTToolbarHeight);


    /*
     UITextField 的 inputAccessoryView
     可以通过 setter 设置。
     */

    textField.inputAccessoryView = container;


    dispatch_async(dispatch_get_main_queue(), ^{

        if (textField.isFirstResponder) {
            [textField reloadInputViews];
        }
    });
}


#pragma mark - UITextView 安装

- (void)installForTextView:(UITextView *)textView
{
    if (!textView) {
        return;
    }

    if (!textView.window) {
        return;
    }

    if (!textView.isFirstResponder) {
        return;
    }


    /*
     防止重复安装
     */

    if ([textView.inputAccessoryView
            isKindOfClass:
                [KTAccessoryContainerView class]]) {

        return;
    }


    UIView *originalAccessory =
        textView.inputAccessoryView;


    UIView *toolbar =
        [self createToolbar];


    KTAccessoryContainerView *container =
        [[KTAccessoryContainerView alloc]
            initWithOriginalAccessory:originalAccessory
            toolbar:toolbar];


    CGFloat originalHeight = 0.0;


    if (originalAccessory) {

        originalHeight =
            originalAccessory.frame.size.height;

        if (originalHeight < 0.0) {
            originalHeight = 0.0;
        }
    }


    container.frame =
        CGRectMake(0.0,
                   0.0,
                   UIScreen.mainScreen.bounds.size.width,
                   originalHeight + KTToolbarHeight);


    /*
     UITextView 的 inputAccessoryView
     可以通过 setter 设置。
     */

    textView.inputAccessoryView = container;


    dispatch_async(dispatch_get_main_queue(), ^{

        if (textView.isFirstResponder) {
            [textView reloadInputViews];
        }
    });
}


#pragma mark - 剪贴板

- (void)clipboardTapped:(UIButton *)sender
{
    UIResponder *responder =
        [self currentFirstResponder];


    if (!responder) {
        return;
    }


    UIViewController *viewController =
        [self currentViewController:responder];


    if (!viewController) {
        return;
    }


    KTClipboardViewController *controller =
        [KTClipboardViewController new];


    controller.modalPresentationStyle =
        UIModalPresentationPageSheet;


    [viewController
        presentViewController:controller
        animated:YES
        completion:nil];
}


#pragma mark - 全选

- (void)selectAllTapped:(UIButton *)sender
{
    UIResponder *responder =
        [self currentFirstResponder];


    if (!responder) {
        return;
    }


    if ([responder
            respondsToSelector:@selector(selectAll:)]) {

        [(id)responder selectAll:nil];
    }
}


#pragma mark - 粘贴

- (void)pasteTapped:(UIButton *)sender
{
    UIResponder *responder =
        [self currentFirstResponder];


    if (!responder) {
        return;
    }


    if ([responder
            respondsToSelector:@selector(paste:)]) {

        [(id)responder paste:nil];
    }
}


#pragma mark - 撤销

- (void)undoTapped:(UIButton *)sender
{
    UIResponder *responder =
        [self currentFirstResponder];


    if (!responder) {
        return;
    }


    NSUndoManager *undoManager =
        responder.undoManager;


    if (undoManager &&
        [undoManager canUndo]) {

        [undoManager undo];
    }
}


#pragma mark - 收起键盘

- (void)dismissTapped:(UIButton *)sender
{
    UIResponder *responder =
        [self currentFirstResponder];


    if (!responder) {
        return;
    }


    [responder resignFirstResponder];
}


#pragma mark - 当前第一响应者

- (UIResponder *)currentFirstResponder
{
    NSSet *connectedScenes =
        UIApplication.sharedApplication.connectedScenes;


    for (UIScene *scene in connectedScenes) {

        if (![scene
                isKindOfClass:[UIWindowScene class]]) {

            continue;
        }


        UIWindowScene *windowScene =
            (UIWindowScene *)scene;


        if (windowScene.activationState !=
            UISceneActivationStateForegroundActive) {

            continue;
        }


        for (UIWindow *window
             in windowScene.windows) {

            if (!window.isKeyWindow) {
                continue;
            }


            UIResponder *responder =
                [self findFirstResponderInView:window];


            if (responder) {
                return responder;
            }
        }
    }


    return nil;
}


- (UIResponder *)findFirstResponderInView:(UIView *)view
{
    if ([view isFirstResponder]) {
        return view;
    }


    for (UIView *subview in view.subviews) {

        UIResponder *responder =
            [self findFirstResponderInView:subview];


        if (responder) {
            return responder;
        }
    }


    return nil;
}


#pragma mark - 当前控制器

- (UIViewController *)currentViewController:
    (UIResponder *)responder
{
    UIResponder *current =
        responder;


    while (current) {

        if ([current
                isKindOfClass:
                    [UIViewController class]]) {

            return (UIViewController *)current;
        }


        current =
            current.nextResponder;
    }


    return nil;
}

@end


#pragma mark - UITextField Hook

%hook UITextField


- (BOOL)becomeFirstResponder
{
    BOOL result =
        %orig;


    if (result) {

        dispatch_async(
            dispatch_get_main_queue(),
            ^{

                [[KTKeyboardController sharedController]
                    installForTextField:self];
            });
    }


    return result;
}


- (void)layoutSubviews
{
    %orig;


    if (self.isFirstResponder) {

        dispatch_async(
            dispatch_get_main_queue(),
            ^{

                [[KTKeyboardController sharedController]
                    installForTextField:self];
            });
    }
}


%end


#pragma mark - UITextView Hook

%hook UITextView


- (BOOL)becomeFirstResponder
{
    BOOL result =
        %orig;


    if (result) {

        dispatch_async(
            dispatch_get_main_queue(),
            ^{

                [[KTKeyboardController sharedController]
                    installForTextView:self];
            });
    }


    return result;
}


- (void)layoutSubviews
{
    %orig;


    if (self.isFirstResponder) {

        dispatch_async(
            dispatch_get_main_queue(),
            ^{

                [[KTKeyboardController sharedController]
                    installForTextView:self];
            });
    }
}


%end


#pragma mark - 启动

%ctor
{
    @autoreleasepool {

        [[KTClipboardManager sharedManager]
            startMonitoring];
    }
}
