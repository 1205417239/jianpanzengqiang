#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "KTClipboardManager.h"
#import "KTClipboardViewController.h"
#import "KTSettings.h"

#pragma mark - 配置

static NSInteger const KTKeyboardToolbarTag = 9999;

static CGFloat const KTToolbarWidth = 240.0;
static CGFloat const KTToolbarHeight = 36.0;
static CGFloat const KTToolbarBottomOffset = -23.0;

#pragma mark - 私有键盘类

@interface UIKeyboardImpl : NSObject
+ (instancetype)activeInstance;
- (void)dismissKeyboard;
@end

#pragma mark - 查找当前输入控件

static BOOL KTIsTextInput(id object)
{
    if (!object) {
        return NO;
    }

    return [object conformsToProtocol:@protocol(UITextInput)];
}

static UIView *KTFindFirstResponderInView(UIView *view)
{
    if (!view) {
        return nil;
    }

    if (view.isFirstResponder) {
        return view;
    }

    for (UIView *subview in view.subviews) {

        UIView *responder =
            KTFindFirstResponderInView(subview);

        if (responder) {
            return responder;
        }
    }

    return nil;
}

static NSArray<UIWindow *> *KTApplicationWindows(void)
{
    NSMutableArray<UIWindow *> *windows =
        [NSMutableArray array];

    UIApplication *application =
        UIApplication.sharedApplication;

    if (@available(iOS 13.0, *)) {

        for (UIScene *scene in application.connectedScenes) {

            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            UISceneActivationState state =
                scene.activationState;

            if (state != UISceneActivationStateForegroundActive &&
                state != UISceneActivationStateForegroundInactive) {
                continue;
            }

            UIWindowScene *windowScene =
                (UIWindowScene *)scene;

            [windows addObjectsFromArray:windowScene.windows];
        }
    }

    return windows;
}

static id<UITextInput> KTCurrentTextInput(void)
{
    NSArray<UIWindow *> *windows =
        KTApplicationWindows();

    /*
     * 第一轮：
     * 排除键盘窗口，寻找当前真正成为 first responder
     * 的 UITextInput。
     */
    for (UIWindow *window in windows) {

        if (window.hidden || window.alpha <= 0.01) {
            continue;
        }

        NSString *className =
            NSStringFromClass(window.class);

        if ([className rangeOfString:@"Keyboard"].location
            != NSNotFound) {
            continue;
        }

        UIView *responder =
            KTFindFirstResponderInView(window);

        if (KTIsTextInput(responder)) {
            return (id<UITextInput>)responder;
        }
    }

    /*
     * 第二轮兜底。
     */
    for (UIWindow *window in windows) {

        UIView *responder =
            KTFindFirstResponderInView(window);

        if (KTIsTextInput(responder)) {
            return (id<UITextInput>)responder;
        }
    }

    return nil;
}

#pragma mark - 顶层控制器

static UIViewController *KTTopViewController(UIViewController *controller)
{
    if (!controller) {
        return nil;
    }

    if (controller.presentedViewController) {
        return KTTopViewController(
            controller.presentedViewController
        );
    }

    if ([controller isKindOfClass:[UINavigationController class]]) {

        UINavigationController *navigation =
            (UINavigationController *)controller;

        return KTTopViewController(
            navigation.visibleViewController
        );
    }

    if ([controller isKindOfClass:[UITabBarController class]]) {

        UITabBarController *tab =
            (UITabBarController *)controller;

        return KTTopViewController(
            tab.selectedViewController
        );
    }

    return controller;
}

static UIViewController *KTApplicationViewController(void)
{
    NSArray<UIWindow *> *windows =
        KTApplicationWindows();

    /*
     * 优先寻找当前可见、非键盘窗口。
     */
    for (UIWindow *window in windows) {

        if (window.hidden || window.alpha <= 0.01) {
            continue;
        }

        NSString *className =
            NSStringFromClass(window.class);

        if ([className rangeOfString:@"Keyboard"].location
            != NSNotFound) {
            continue;
        }

        UIViewController *root =
            window.rootViewController;

        if (root) {
            return KTTopViewController(root);
        }
    }

    return nil;
}

#pragma mark - 触感

static void KTTriggerHapticFeedback(void)
{
    if (@available(iOS 10.0, *)) {

        UIImpactFeedbackGenerator *generator =
            [[UIImpactFeedbackGenerator alloc]
                initWithStyle:UIImpactFeedbackStyleLight];

        [generator prepare];
        [generator impactOccurred];
    }
}

#pragma mark - 剪贴板

static void KTDockDidTapClipboard(id self,
                                  SEL _cmd,
                                  UIButton *sender)
{
    KTTriggerHapticFeedback();

    id<UITextInput> currentInput =
        KTCurrentTextInput();

    if (!currentInput) {
        return;
    }

    UIViewController *viewController =
        KTApplicationViewController();

    if (!viewController) {
        return;
    }

    KTClipboardViewController *controller =
        [[KTClipboardViewController alloc]
            initWithInput:currentInput];

    controller.modalPresentationStyle =
        UIModalPresentationPageSheet;

    [viewController
        presentViewController:controller
        animated:YES
        completion:nil];
}

#pragma mark - 全选

static void KTDockDidTapSelectAll(id self,
                                  SEL _cmd,
                                  UIButton *sender)
{
    KTTriggerHapticFeedback();

    [UIApplication.sharedApplication
        sendAction:@selector(selectAll:)
        to:nil
        from:nil
        forEvent:nil];
}

#pragma mark - 粘贴

static void KTDockDidTapPaste(id self,
                              SEL _cmd,
                              UIButton *sender)
{
    KTTriggerHapticFeedback();

    [UIApplication.sharedApplication
        sendAction:@selector(paste:)
        to:nil
        from:nil
        forEvent:nil];
}

#pragma mark - 撤销

static void KTDockDidTapUndo(id self,
                             SEL _cmd,
                             UIButton *sender)
{
    KTTriggerHapticFeedback();

    [UIApplication.sharedApplication
        sendAction:@selector(undo:)
        to:nil
        from:nil
        forEvent:nil];
}

#pragma mark - 收起键盘

static void KTDockDidTapDismiss(id self,
                                SEL _cmd,
                                UIButton *sender)
{
    KTTriggerHapticFeedback();

    Class keyboardImplClass =
        objc_getClass("UIKeyboardImpl");

    if (!keyboardImplClass) {
        return;
    }

    id keyboardImpl =
        [keyboardImplClass activeInstance];

    if (!keyboardImpl) {
        return;
    }

    if ([keyboardImpl respondsToSelector:@selector(dismissKeyboard)]) {
        [keyboardImpl dismissKeyboard];
    }
}

#pragma mark - MyDock 触感兼容

static void KTDockTriggerHapticFeedback(id self,
                                        SEL _cmd)
{
    KTTriggerHapticFeedback();
}

#pragma mark - 动态安装方法

static void KTInstallDockMethods(Class dockClass)
{
    if (!dockClass) {
        return;
    }

    class_addMethod(
        dockClass,
        @selector(triggerHapticFeedback),
        (IMP)KTDockTriggerHapticFeedback,
        "v@:"
    );

    class_addMethod(
        dockClass,
        @selector(didTapClipboard:),
        (IMP)KTDockDidTapClipboard,
        "v@:@"
    );

    class_addMethod(
        dockClass,
        @selector(didTapSelectAll:),
        (IMP)KTDockDidTapSelectAll,
        "v@:@"
    );

    class_addMethod(
        dockClass,
        @selector(didTapPaste:),
        (IMP)KTDockDidTapPaste,
        "v@:@"
    );

    class_addMethod(
        dockClass,
        @selector(didTapUndo:),
        (IMP)KTDockDidTapUndo,
        "v@:@"
    );

    class_addMethod(
        dockClass,
        @selector(didTapDismiss:),
        (IMP)KTDockDidTapDismiss,
        "v@:@"
    );
}

#pragma mark - 创建五键工具栏

static UIStackView *KTCreateKeyboardToolbar(id dockObject)
{
    UIView *dockView =
        (UIView *)dockObject;

    if (!dockView) {
        return nil;
    }

    UIView *existing =
        [dockView viewWithTag:KTKeyboardToolbarTag];

    if (existing) {
        return (UIStackView *)existing;
    }

    UIStackView *stackView =
        [[UIStackView alloc] initWithFrame:CGRectZero];

    stackView.tag =
        KTKeyboardToolbarTag;

    stackView.axis =
        UILayoutConstraintAxisHorizontal;

    stackView.distribution =
        UIStackViewDistributionFillEqually;

    stackView.alignment =
        UIStackViewAlignmentCenter;

    stackView.spacing = 0.0;

    stackView.translatesAutoresizingMaskIntoConstraints =
        NO;

    [dockView addSubview:stackView];

    #pragma mark 剪贴板

    UIButton *clipboard =
        [UIButton buttonWithType:UIButtonTypeSystem];

    if (@available(iOS 13.0, *)) {

        UIImage *image =
            [UIImage systemImageNamed:@"doc.on.clipboard"];

        [clipboard setImage:image
                  forState:UIControlStateNormal];
    }

    clipboard.accessibilityLabel =
        @"剪贴板";

    clipboard.accessibilityIdentifier =
        @"KeyboardToolsKayoko_Clipboard";

    [clipboard addTarget:dockView
                  action:@selector(didTapClipboard:)
        forControlEvents:UIControlEventTouchUpInside];

    #pragma mark 全选

    UIButton *selectAll =
        [UIButton buttonWithType:UIButtonTypeSystem];

    if (@available(iOS 13.0, *)) {

        UIImage *image =
            [UIImage systemImageNamed:@"selection.pin.in.out"];

        [selectAll setImage:image
                   forState:UIControlStateNormal];
    }

    selectAll.accessibilityLabel =
        @"全选";

    selectAll.accessibilityIdentifier =
        @"KeyboardToolsKayoko_SelectAll";

    [selectAll addTarget:dockView
                  action:@selector(didTapSelectAll:)
        forControlEvents:UIControlEventTouchUpInside];

    #pragma mark 粘贴

    UIButton *paste =
        [UIButton buttonWithType:UIButtonTypeSystem];

    if (@available(iOS 13.0, *)) {

        UIImage *image =
            [UIImage systemImageNamed:@"doc.on.clipboard"];

        [paste setImage:image
               forState:UIControlStateNormal];
    }

    paste.accessibilityLabel =
        @"粘贴";

    paste.accessibilityIdentifier =
        @"KeyboardToolsKayoko_Paste";

    [paste addTarget:dockView
              action:@selector(didTapPaste:)
    forControlEvents:UIControlEventTouchUpInside];

    #pragma mark 撤销

    UIButton *undo =
        [UIButton buttonWithType:UIButtonTypeSystem];

    if (@available(iOS 13.0, *)) {

        UIImage *image =
            [UIImage systemImageNamed:@"arrow.uturn.backward"];

        [undo setImage:image
              forState:UIControlStateNormal];
    }

    undo.accessibilityLabel =
        @"撤销";

    undo.accessibilityIdentifier =
        @"KeyboardToolsKayoko_Undo";

    [undo addTarget:dockView
             action:@selector(didTapUndo:)
   forControlEvents:UIControlEventTouchUpInside];

    #pragma mark 收起键盘

    UIButton *dismiss =
        [UIButton buttonWithType:UIButtonTypeSystem];

    if (@available(iOS 13.0, *)) {

        UIImage *image =
            [UIImage systemImageNamed:
                @"keyboard.chevron.compact.down"];

        [dismiss setImage:image
                 forState:UIControlStateNormal];
    }

    dismiss.accessibilityLabel =
        @"收起键盘";

    dismiss.accessibilityIdentifier =
        @"KeyboardToolsKayoko_Dismiss";

    [dismiss addTarget:dockView
                action:@selector(didTapDismiss:)
      forControlEvents:UIControlEventTouchUpInside];

    #pragma mark 加入五个按钮

    NSArray *buttons = @[
        clipboard,
        selectAll,
        paste,
        undo,
        dismiss
    ];

    for (UIButton *button in buttons) {

        [stackView addArrangedSubview:button];

        [button.widthAnchor
            constraintEqualToConstant:
                KTToolbarWidth / 5.0]
            .active = YES;

        [button.heightAnchor
            constraintEqualToConstant:
                KTToolbarHeight]
            .active = YES;
    }

    #pragma mark 整体约束

    [stackView.widthAnchor
        constraintEqualToConstant:KTToolbarWidth]
        .active = YES;

    [stackView.heightAnchor
        constraintEqualToConstant:KTToolbarHeight]
        .active = YES;

    [stackView.centerXAnchor
        constraintEqualToAnchor:dockView.centerXAnchor]
        .active = YES;

    [stackView.bottomAnchor
        constraintEqualToAnchor:dockView.bottomAnchor
        constant:KTToolbarBottomOffset]
        .active = YES;

    return stackView;
}

#pragma mark - UIKeyboardDockView

%hook UIKeyboardDockView

- (void)layoutSubviews
{
    /*
     * 先执行系统布局。
     */
    %orig;

    UIView *dockView =
        (UIView *)self;

    if (!dockView) {
        return;
    }

    /*
     * 防止重复创建。
     */
    UIView *existing =
        [dockView viewWithTag:KTKeyboardToolbarTag];

    if (existing) {
        return;
    }

    KTCreateKeyboardToolbar(dockView);
}

%end

#pragma mark - 初始化

%ctor
{
    @autoreleasepool {

        Class dockClass =
            objc_getClass("UIKeyboardDockView");

        if (dockClass) {
            KTInstallDockMethods(dockClass);
        }
    }
}
