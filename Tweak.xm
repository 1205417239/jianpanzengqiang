#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "KTClipboardManager.h"
#import "KTClipboardViewController.h"
#import "KTSettings.h"

static CGFloat const KTToolbarHeight = 44.0;


#pragma mark - 容器

@interface KTAccessoryContainerView : UIView
@property(nonatomic,strong) UIView *originalAccessory;
@property(nonatomic,strong) UIView *keyboardToolbar;
- (instancetype)initWithOriginalAccessory:(UIView *)original
                                   toolbar:(UIView *)toolbar;
@end


@implementation KTAccessoryContainerView

- (instancetype)initWithOriginalAccessory:(UIView *)original
                                   toolbar:(UIView *)toolbar
{
    self = [super initWithFrame:CGRectZero];

    if (self) {
        _originalAccessory = original;
        _keyboardToolbar = toolbar;

        self.backgroundColor = UIColor.clearColor;

        if (original) {
            [self addSubview:original];
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

        self.originalAccessory.frame =
            CGRectMake(0,
                       0,
                       width,
                       height - toolbarHeight);

        self.keyboardToolbar.frame =
            CGRectMake(0,
                       height - toolbarHeight,
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


#pragma mark - 控制器

@interface KTKeyboardController : NSObject
+ (instancetype)sharedController;
- (void)installForInput:(UIView *)input;
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

- (UIView *)createToolbarForInput:(UIView *)input
{
    UIToolbar *toolbar =
        [[UIToolbar alloc] initWithFrame:CGRectZero];

    toolbar.translucent = YES;
    toolbar.barStyle = UIBarStyleDefault;

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

    for (NSInteger i = 0;
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


#pragma mark - 安装

- (void)installForInput:(UIView *)input
{
    if (!input) {
        return;
    }

    if (!input.window) {
        return;
    }

    if (![input isFirstResponder]) {
        return;
    }

    if (![input isKindOfClass:[UITextField class]] &&
        ![input isKindOfClass:[UITextView class]]) {
        return;
    }

    if ([input.inputAccessoryView
            isKindOfClass:[KTAccessoryContainerView class]]) {
        return;
    }

    UIView *originalAccessory =
        input.inputAccessoryView;

    UIView *toolbar =
        [self createToolbarForInput:input];

    KTAccessoryContainerView *container =
        [[KTAccessoryContainerView alloc]
            initWithOriginalAccessory:originalAccessory
            toolbar:toolbar];

    CGFloat height = KTToolbarHeight;

    if (originalAccessory) {
        CGFloat originalHeight =
            originalAccessory.frame.size.height;

        if (originalHeight > 0) {
            height += originalHeight;
        }
    }

    container.frame =
        CGRectMake(0,
                   0,
                   UIScreen.mainScreen.bounds.size.width,
                   height);

    /*
     inputAccessoryView 是 readonly。
     必须调用 setter。
     */
    [input setInputAccessoryView:container];

    dispatch_async(dispatch_get_main_queue(), ^{

        if ([input isFirstResponder]) {
            [input reloadInputViews];
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

    UIViewController *vc =
        [self currentViewController:responder];

    if (!vc) {
        return;
    }

    KTClipboardViewController *controller =
        [KTClipboardViewController new];

    controller.modalPresentationStyle =
        UIModalPresentationPageSheet;

    [vc presentViewController:controller
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

    if ([responder respondsToSelector:@selector(selectAll:)]) {
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

    if ([responder respondsToSelector:@selector(paste:)]) {
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

    NSUndoManager *manager =
        responder.undoManager;

    if (manager && [manager canUndo]) {
        [manager undo];
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


#pragma mark - 查找第一响应者

- (UIResponder *)currentFirstResponder
{
    NSSet *scenes =
        UIApplication.sharedApplication.connectedScenes;

    for (UIScene *scene in scenes) {

        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        if (windowScene.activationState !=
            UISceneActivationStateForegroundActive) {
            continue;
        }

        for (UIWindow *window in windowScene.windows) {

            if (!window.isKeyWindow) {
                continue;
            }

            UIResponder *responder =
                [self findFirstResponder:window];

            if (responder) {
                return responder;
            }
        }
    }

    return nil;
}


- (UIResponder *)findFirstResponder:(UIView *)view
{
    if ([view isFirstResponder]) {
        return view;
    }

    for (UIView *subview in view.subviews) {

        UIResponder *responder =
            [self findFirstResponder:subview];

        if (responder) {
            return responder;
        }
    }

    return nil;
}


#pragma mark - 查找控制器

- (UIViewController *)currentViewController:(UIResponder *)responder
{
    UIResponder *current = responder;

    while (current) {

        if ([current isKindOfClass:
                [UIViewController class]]) {

            return (UIViewController *)current;
        }

        current = current.nextResponder;
    }

    return nil;
}

@end


#pragma mark - 安装函数

static void KTInstallAccessoryForInput(UIView *input)
{
    if (!input) {
        return;
    }

    if (![input isFirstResponder]) {
        return;
    }

    if (!input.window) {
        return;
    }

    if (![input isKindOfClass:[UITextField class]] &&
        ![input isKindOfClass:[UITextView class]]) {
        return;
    }

    [[KTKeyboardController sharedController]
        installForInput:input];
}


#pragma mark - UITextField

%hook UITextField

- (BOOL)becomeFirstResponder
{
    BOOL result = %orig;

    if (result) {

        dispatch_async(dispatch_get_main_queue(), ^{

            KTInstallAccessoryForInput(self);
        });
    }

    return result;
}


- (void)layoutSubviews
{
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

- (BOOL)becomeFirstResponder
{
    BOOL result = %orig;

    if (result) {

        dispatch_async(dispatch_get_main_queue(), ^{

            KTInstallAccessoryForInput(self);
        });
    }

    return result;
}


- (void)layoutSubviews
{
    %orig;

    if (self.isFirstResponder) {

        dispatch_async(dispatch_get_main_queue(), ^{

            KTInstallAccessoryForInput(self);
        });
    }
}

%end


#pragma mark - UIResponder 备用

%hook UIResponder

- (BOOL)becomeFirstResponder
{
    BOOL result = %orig;

    if (result &&
        ([self isKindOfClass:[UITextField class]] ||
         [self isKindOfClass:[UITextView class]])) {

        dispatch_async(dispatch_get_main_queue(), ^{

            KTInstallAccessoryForInput((UIView *)self);
        });
    }

    return result;
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
