#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "KTClipboardManager.h"
#import "KTClipboardViewController.h"
#import "KTSettings.h"

#pragma mark - 配置

static NSInteger const KTKeyboardToolbarTag = 9999;

/*
 * 五个按钮固定顺序：
 * 剪贴板 → 全选 → 粘贴 → 撤销 → 收起键盘
 *
 * 整体固定宽度，五个按钮等宽。
 * 不使用按钮内容决定间距。
 */
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
        UIView *responder = KTFindFirstResponderInView(subview);

        if (responder) {
            return responder;
        }
    }

    return nil;
}

static id<UITextInput> KTCurrentTextInput(void)
{
    UIApplication *application = UIApplication.sharedApplication;

    /*
     * 优先检查正常应用窗口。
     *
     * 不直接依赖 keyWindow，因为 iOS 13+ 多窗口环境下
     * keyWindow 不一定就是当前输入所在窗口。
     */
    for (UIWindow *window in application.windows) {

        if (window.hidden || window.alpha <= 0.01) {
            continue;
        }

        NSString *className = NSStringFromClass(window.class);

        /*
         * 键盘窗口本身不是我们要找的输入框。
         */
        if ([className rangeOfString:@"Keyboard"].location != NSNotFound) {
            continue;
        }

        UIView *responder = KTFindFirstResponderInView(window);

        if (KTIsTextInput(responder)) {
            return (id<UITextInput>)responder;
        }
    }

    /*
     * 兜底：直接扫描应用所有窗口。
     */
    for (UIWindow *window in application.windows) {

        UIView *responder = KTFindFirstResponderInView(window);

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
        return KTTopViewController(controller.presentedViewController);
    }

    if ([controller isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigation =
            (UINavigationController *)controller;

        return KTTopViewController(navigation.visibleViewController);
    }

    if ([controller isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tab =
            (UITabBarController *)controller;

        return KTTopViewController(tab.selectedViewController);
    }

    return controller;
}

static UIViewController *KTApplicationViewController(void)
{
    UIApplication *application = UIApplication.sharedApplication;

    for (UIWindow *window in application.windows) {

        if (window.hidden || window.alpha <= 0.01) {
            continue;
        }

        NSString *className = NSStringFromClass(window.class);

        if ([className rangeOfString:@"Keyboard"].location != NSNotFound) {
            continue;
        }

        UIViewController *root = window.rootViewController;

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

#pragma mark - 剪贴板按钮

static void KTDockDidTapClipboard(id self, SEL _cmd, UIButton *sender)
{
    KTTriggerHapticFeedback();

    id<UITextInput> currentInput = KTCurrentTextInput();

    /*
     * 必须绑定当前输入控件。
     *
     * 不再使用：
     * [KTClipboardViewController new]
     */
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

#pragma mark - 兼容 MyDock 的触感方法

static void KTDockTriggerHapticFeedback(id self,
                                        SEL _cmd)
{
    KTTriggerHapticFeedback();
}

#pragma mark - 给 UIKeyboardDockView 动态添加方法

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
    UIView *dockView = (UIView *)dockObject;

    if (!dockView) {
        return nil;
    }

    UIView *existing =
        [dockView viewWithTag:KTKeyboardToolbarTag];

    if (existing) {
        return (UIStackView *)existing;
    }

    /*
     * 整体容器。
     *
     * 关键点：
     * 1. 固定整体宽度
     * 2. 五个按钮等宽
     * 3. 水平居中
     * 4. 不让 icon 大小决定按钮之间的距离
     */
    UIStackView *stackView =
        [[UIStackView alloc] initWithFrame:CGRectZero];

    stackView.tag = KTKeyboardToolbarTag;

    stackView.axis =
        UILayoutConstraintAxisHorizontal;

    stackView.distribution =
        UIStackViewDistributionFillEqually;

    stackView.alignment =
        UIStackViewAlignmentCenter;

    stackView.spacing = 0.0;

    stackView.translatesAutoresizingMaskIntoConstraints = NO;

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

    clipboard.accessibilityLabel = @"剪贴板";
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

    selectAll.accessibilityLabel = @"全选";
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

    paste.accessibilityLabel = @"粘贴";
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

    undo.accessibilityLabel = @"撤销";
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
            [UIImage systemImageNamed:@"keyboard.chevron.compact.down"];

        [dismiss setImage:image
                 forState:UIControlStateNormal];
    }

    dismiss.accessibilityLabel = @"收起键盘";
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
            constraintEqualToConstant:KTToolbarWidth / 5.0]
            .active = YES;

        [button.heightAnchor
            constraintEqualToConstant:KTToolbarHeight]
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
     * 先让系统完成自己的布局。
     */
    %orig;

    UIView *dockView = (UIView *)self;

    if (!dockView) {
        return;
    }

    /*
     * 防止每次 layoutSubviews 都重复创建。
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
