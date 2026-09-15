#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "KTClipboardManager.h"
#import "KTClipboardViewController.h"
#import "KTSettings.h"


#pragma mark - 常量

static NSInteger const KTKeyboardToolbarTag = 9999;

static CGFloat const KTToolbarSpacing = 32.0;

static CGFloat const KTToolbarBottomOffset = -23.0;


#pragma mark - 私有键盘类

@interface UIKeyboardImpl : NSObject

+ (instancetype)activeInstance;

- (void)dismissKeyboard;

@end


#pragma mark - 工具栏

static UIStackView *KTCreateKeyboardToolbar(id dockView)
{
    UIView *dock = (UIView *)dockView;

    if (!dock) {
        return nil;
    }


    /*
     防止重复创建
     */

    UIView *existing =
        [dock viewWithTag:KTKeyboardToolbarTag];

    if (existing) {
        return (UIStackView *)existing;
    }


    /*
     创建横向 StackView
     */

    UIStackView *stackView =
        [[UIStackView alloc] initWithFrame:CGRectZero];


    stackView.tag =
        KTKeyboardToolbarTag;


    stackView.axis =
        UILayoutConstraintAxisHorizontal;


    stackView.distribution =
        UIStackViewDistributionEqualSpacing;


    stackView.alignment =
        UIStackViewAlignmentCenter;


    stackView.spacing =
        KTToolbarSpacing;


    stackView.translatesAutoresizingMaskIntoConstraints =
        NO;


    /*
     添加到系统键盘 DockView
     */

    [dock addSubview:stackView];


    /*
     创建按钮
     */

    UIButton *clipboard =
        [UIButton buttonWithType:UIButtonTypeSystem];


    [clipboard setImage:
        [UIImage systemImageNamed:@"doc.on.clipboard"]
        forState:UIControlStateNormal];


    clipboard.accessibilityLabel =
        @"剪贴板";


    clipboard.accessibilityIdentifier =
        @"KeyboardToolsKayoko_Clipboard";


    [clipboard addTarget:dock
                  action:@selector(didTapClipboard:)
        forControlEvents:UIControlEventTouchUpInside];


    UIButton *selectAll =
        [UIButton buttonWithType:UIButtonTypeSystem];


    [selectAll setImage:
        [UIImage systemImageNamed:@"selection.pin.in.out"]
        forState:UIControlStateNormal];


    selectAll.accessibilityLabel =
        @"全选";


    selectAll.accessibilityIdentifier =
        @"KeyboardToolsKayoko_SelectAll";


    [selectAll addTarget:dock
                  action:@selector(didTapSelectAll:)
        forControlEvents:UIControlEventTouchUpInside];


    UIButton *paste =
        [UIButton buttonWithType:UIButtonTypeSystem];


    [paste setImage:
        [UIImage systemImageNamed:@"doc.on.clipboard"]
        forState:UIControlStateNormal];


    paste.accessibilityLabel =
        @"粘贴";


    paste.accessibilityIdentifier =
        @"KeyboardToolsKayoko_Paste";


    [paste addTarget:dock
              action:@selector(didTapPaste:)
    forControlEvents:UIControlEventTouchUpInside];


    UIButton *undo =
        [UIButton buttonWithType:UIButtonTypeSystem];


    [undo setImage:
        [UIImage systemImageNamed:@"arrow.uturn.backward"]
        forState:UIControlStateNormal];


    undo.accessibilityLabel =
        @"撤销";


    undo.accessibilityIdentifier =
        @"KeyboardToolsKayoko_Undo";


    [undo addTarget:dock
             action:@selector(didTapUndo:)
   forControlEvents:UIControlEventTouchUpInside];


    UIButton *dismiss =
        [UIButton buttonWithType:UIButtonTypeSystem];


    [dismiss setImage:
        [UIImage systemImageNamed:@"keyboard.chevron.compact.down"]
        forState:UIControlStateNormal];


    dismiss.accessibilityLabel =
        @"收起键盘";


    dismiss.accessibilityIdentifier =
        @"KeyboardToolsKayoko_Dismiss";


    [dismiss addTarget:dock
                action:@selector(didTapDismiss:)
      forControlEvents:UIControlEventTouchUpInside];


    /*
     严格五个按钮：

     剪贴板
     全选
     粘贴
     撤销
     收起键盘
     */

    [stackView addArrangedSubview:clipboard];
    [stackView addArrangedSubview:selectAll];
    [stackView addArrangedSubview:paste];
    [stackView addArrangedSubview:undo];
    [stackView addArrangedSubview:dismiss];


    /*
     设置按钮尺寸
     */

    NSArray *buttons = @[
        clipboard,
        selectAll,
        paste,
        undo,
        dismiss
    ];


    for (UIButton *button in buttons) {

        [button.widthAnchor
            constraintEqualToConstant:32.0].active = YES;

        [button.heightAnchor
            constraintEqualToConstant:32.0].active = YES;
    }


    /*
     核心布局：

     水平居中
     */

    [stackView.centerXAnchor
        constraintEqualToAnchor:dock.centerXAnchor]
        .active = YES;


    /*
     核心布局：

     底部距离 UIKeyboardDockView 底部 23
     */

    [stackView.bottomAnchor
        constraintEqualToAnchor:dock.bottomAnchor
        constant:KTToolbarBottomOffset]
        .active = YES;


    return stackView;
}


#pragma mark - 获取顶部控制器

static UIViewController *KTTopViewController(
    UIViewController *rootViewController)
{
    if (!rootViewController) {
        return nil;
    }


    UIViewController *current =
        rootViewController;


    while (current.presentedViewController) {

        current =
            current.presentedViewController;
    }


    if ([current isKindOfClass:
            [UINavigationController class]]) {

        UINavigationController *navigation =
            (UINavigationController *)current;


        UIViewController *visible =
            navigation.visibleViewController;


        if (visible) {
            return KTTopViewController(visible);
        }
    }


    if ([current isKindOfClass:
            [UITabBarController class]]) {

        UITabBarController *tab =
            (UITabBarController *)current;


        UIViewController *selected =
            tab.selectedViewController;


        if (selected) {
            return KTTopViewController(selected);
        }
    }


    return current;
}


static UIViewController *KTFindApplicationViewController(void)
{
    UIApplication *application =
        UIApplication.sharedApplication;


    /*
     优先查找前台激活场景
     */

    for (UIScene *scene
         in application.connectedScenes) {

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


        /*
         不使用键盘自己的窗口。
         */

        for (UIWindow *window
             in windowScene.windows) {

            NSString *className =
                NSStringFromClass(window.class);


            if ([className
                    containsString:@"Keyboard"]) {

                continue;
            }


            if (!window.hidden &&
                window.rootViewController) {

                UIViewController *controller =
                    KTTopViewController(
                        window.rootViewController);


                if (controller) {
                    return controller;
                }
            }
        }
    }


    return nil;
}


#pragma mark - 触感

static void KTTriggerHapticFeedback(void)
{
    UIImpactFeedbackGenerator *generator =
        [[UIImpactFeedbackGenerator alloc]
            initWithStyle:UIImpactFeedbackStyleLight];


    [generator prepare];

    [generator impactOccurred];
}


#pragma mark - 动态方法

static void KTDockTriggerHapticFeedback(
    id self,
    SEL _cmd)
{
    KTTriggerHapticFeedback();
}


static void KTDockDidTapClipboard(
    id self,
    SEL _cmd,
    UIButton *sender)
{
    KTTriggerHapticFeedback();


    /*
     剪贴板页面使用现有
     KTClipboardViewController。
     */

    UIViewController *viewController =
        KTFindApplicationViewController();


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


static void KTDockDidTapSelectAll(
    id self,
    SEL _cmd,
    UIButton *sender)
{
    KTTriggerHapticFeedback();


    /*
     使用系统响应链：

     selectAll:
     */

    [UIApplication.sharedApplication
        sendAction:@selector(selectAll:)
        to:nil
        from:nil
        forEvent:nil];
}


static void KTDockDidTapPaste(
    id self,
    SEL _cmd,
    UIButton *sender)
{
    KTTriggerHapticFeedback();


    /*
     使用系统响应链：

     paste:
     */

    [UIApplication.sharedApplication
        sendAction:@selector(paste:)
        to:nil
        from:nil
        forEvent:nil];
}


static void KTDockDidTapUndo(
    id self,
    SEL _cmd,
    UIButton *sender)
{
    KTTriggerHapticFeedback();


    /*
     使用系统响应链：

     undo:
     */

    [UIApplication.sharedApplication
        sendAction:@selector(undo:)
        to:nil
        from:nil
        forEvent:nil];
}


static void KTDockDidTapDismiss(
    id self,
    SEL _cmd,
    UIButton *sender)
{
    KTTriggerHapticFeedback();


    /*
     私有键盘：

     UIKeyboardImpl
         ↓
     activeInstance
         ↓
     dismissKeyboard
     */

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


    if ([keyboardImpl
            respondsToSelector:
                @selector(dismissKeyboard)]) {

        [keyboardImpl dismissKeyboard];
    }
}


#pragma mark - 动态注册方法

static void KTInstallDockMethods(Class dockClass)
{
    if (!dockClass) {
        return;
    }


    /*
     triggerHapticFeedback
     */

    class_addMethod(
        dockClass,
        @selector(triggerHapticFeedback),
        (IMP)KTDockTriggerHapticFeedback,
        "v@:"
    );


    /*
     didTapClipboard:
     */

    class_addMethod(
        dockClass,
        @selector(didTapClipboard:),
        (IMP)KTDockDidTapClipboard,
        "v@:@"
    );


    /*
     didTapSelectAll:
     */

    class_addMethod(
        dockClass,
        @selector(didTapSelectAll:),
        (IMP)KTDockDidTapSelectAll,
        "v@:@"
    );


    /*
     didTapPaste:
     */

    class_addMethod(
        dockClass,
        @selector(didTapPaste:),
        (IMP)KTDockDidTapPaste,
        "v@:@"
    );


    /*
     didTapUndo:
     */

    class_addMethod(
        dockClass,
        @selector(didTapUndo:),
        (IMP)KTDockDidTapUndo,
        "v@:@"
    );


    /*
     didTapDismiss:
     */

    class_addMethod(
        dockClass,
        @selector(didTapDismiss:),
        (IMP)KTDockDidTapDismiss,
        "v@:@"
    );
}


#pragma mark - UIKeyboardDockView

%hook UIKeyboardDockView


- (void)layoutSubviews
{
    /*
     第一件事：

     先执行系统原始布局。
     */

    %orig;


    /*
     第二件事：

     检查工具栏是否已经存在。

     UIKeyboardDockView 是 Logos 的前向声明，
     所以这里显式转换成 UIView。
     */

    UIView *dockView =
        (UIView *)self;


    UIView *existing =
        [dockView viewWithTag:KTKeyboardToolbarTag];


    if (existing) {
        return;
    }


    /*
     第三件事：

     创建工具栏。
     */

    KTCreateKeyboardToolbar(dockView);
}


%end


#pragma mark - 启动

%ctor
{
    @autoreleasepool {

        /*
         获取系统私有键盘 DockView。
         */

        Class dockClass =
            objc_getClass("UIKeyboardDockView");


        if (dockClass) {

            /*
             动态添加按钮处理方法。
             */

            KTInstallDockMethods(dockClass);
        }
    }
}
