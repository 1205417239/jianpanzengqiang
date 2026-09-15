#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#import "KTClipboardViewController.h"

static NSInteger const KTTag = 58731;

static UIViewController *KTTopViewController(void) {
    UIApplication *app = UIApplication.sharedApplication;
    UIViewController *fallback = nil;

    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;

        UIWindowScene *windowScene = (UIWindowScene *)scene;
        BOOL active = scene.activationState == UISceneActivationStateForegroundActive;

        for (UIWindow *window in windowScene.windows) {
            if (window.hidden || !window.rootViewController) continue;

            UIViewController *vc = window.rootViewController;
            while (vc.presentedViewController)
                vc = vc.presentedViewController;

            if (active) return vc;
            if (!fallback) fallback = vc;
        }
    }

    return fallback;
}

static UIResponder *KTFindFirstResponder(UIView *view) {
    if (view.isFirstResponder)
        return view;

    for (UIView *subview in view.subviews) {
        UIResponder *responder = KTFindFirstResponder(subview);
        if (responder)
            return responder;
    }

    return nil;
}

static UIResponder *KTInput(void) {
    UIApplication *app = UIApplication.sharedApplication;

    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;

        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            UIResponder *responder = KTFindFirstResponder(window);
            if (responder &&
                [responder conformsToProtocol:@protocol(UITextInput)])
                return responder;
        }
    }

    return nil;
}

static void KTHaptic(void) {
    UIImpactFeedbackGenerator *generator =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];

    [generator prepare];
    [generator impactOccurred];
}

static void KTClipboardOpen(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *vc = KTTopViewController();
        if (!vc) return;

        UIResponder *input = KTInput();

        KTClipboardViewController *page =
            [[KTClipboardViewController alloc]
                initWithInput:(id<UITextInput>)input];

        UINavigationController *nav =
            [[UINavigationController alloc]
                initWithRootViewController:page];

        nav.modalPresentationStyle = UIModalPresentationPageSheet;

        [vc presentViewController:nav animated:YES completion:nil];
    });
}

static void KTAddButton(UIView *dock,
                        UIStackView *stack,
                        NSString *symbol,
                        NSString *title,
                        SEL action) {

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];

    button.accessibilityLabel = title;
    button.tintColor = UIColor.labelColor;

    UIImage *image = [UIImage systemImageNamed:symbol];

    if (image) {
        [button setImage:image forState:UIControlStateNormal];
    } else {
        [button setTitle:title forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:11.0];
    }

    [button addTarget:dock
               action:action
     forControlEvents:UIControlEventTouchUpInside];

    [stack addArrangedSubview:button];
}

static BOOL KTIsOurToolbar(UIView *dock) {
    return [dock viewWithTag:KTTag] != nil;
}

static void KTInstallToolbar(UIView *dock) {
    if (!dock) return;
    if (KTIsOurToolbar(dock)) return;

    if (dock.bounds.size.width <= 0.0 ||
        dock.bounds.size.height <= 0.0)
        return;

    UIStackView *stack = [[UIStackView alloc] init];

    stack.tag = KTTag;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionEqualSpacing;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 32.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    [dock addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:dock.centerXAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:dock.bottomAnchor
                                           constant:-23.0],
        [stack.widthAnchor constraintLessThanOrEqualToAnchor:dock.widthAnchor
                                                    constant:-20.0],
        [stack.heightAnchor constraintEqualToConstant:36.0]
    ]];

    KTAddButton(dock,
                stack,
                @"selection.pin.in.out",
                @"全选",
                @selector(kt_selectAll:));

    KTAddButton(dock,
                stack,
                @"doc.on.clipboard",
                @"粘贴",
                @selector(kt_paste:));

    KTAddButton(dock,
                stack,
                @"arrow.uturn.backward",
                @"撤销",
                @selector(kt_undo:));

    KTAddButton(dock,
                stack,
                @"keyboard.chevron.compact.down",
                @"收起",
                @selector(kt_dismiss:));

    KTAddButton(dock,
                stack,
                @"list.clipboard",
                @"剪贴板",
                @selector(kt_clipboard:));

    [dock setNeedsLayout];
    [dock layoutIfNeeded];
}

static void KTInstallAfterLayout(UIView *dock) {
    if (!dock) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!dock) return;

        if (dock.bounds.size.width <= 0.0 ||
            dock.bounds.size.height <= 0.0) {
            [dock setNeedsLayout];
            return;
        }

        KTInstallToolbar(dock);
    });
}

%hook UIKeyboardDockView

- (void)layoutSubviews {
    %orig;

    UIView *dock = (UIView *)self;

    if (!dock) return;

    KTInstallAfterLayout(dock);
}

%new
- (void)kt_selectAll:(UIButton *)sender {
    KTHaptic();

    [[UIApplication sharedApplication]
        sendAction:@selector(selectAll:)
        to:nil
        from:nil
        forEvent:nil];
}

%new
- (void)kt_paste:(UIButton *)sender {
    KTHaptic();

    [[UIApplication sharedApplication]
        sendAction:@selector(paste:)
        to:nil
        from:nil
        forEvent:nil];
}

%new
- (void)kt_undo:(UIButton *)sender {
    KTHaptic();

    [[UIApplication sharedApplication]
        sendAction:@selector(undo:)
        to:nil
        from:nil
        forEvent:nil];
}

%new
- (void)kt_dismiss:(UIButton *)sender {
    KTHaptic();

    Class implClass = NSClassFromString(@"UIKeyboardImpl");

    if (implClass &&
        [implClass respondsToSelector:@selector(activeInstance)]) {

        id impl = ((id (*)(id, SEL))
                   objc_msgSend)(implClass,
                                 @selector(activeInstance));

        if (impl &&
            [impl respondsToSelector:@selector(dismissKeyboard)]) {

            ((void (*)(id, SEL))
             objc_msgSend)(impl,
                           @selector(dismissKeyboard));

            return;
        }
    }

    [[UIApplication sharedApplication]
        sendAction:@selector(resignFirstResponder)
        to:nil
        from:nil
        forEvent:nil];
}

%new
- (void)kt_clipboard:(UIButton *)sender {
    KTHaptic();
    KTClipboardOpen();
}

%end

%ctor {
    @autoreleasepool {
        Class dockClass = NSClassFromString(@"UIKeyboardDockView");

        if (dockClass) {
            NSLog(@"[KeyboardToolsKayoko] UIKeyboardDockView loaded");
        }
    }
}
