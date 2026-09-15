#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <CoreFoundation/CoreFoundation.h>
#import "KTClipboardViewController.h"

static NSInteger const KTTag = 9999;

static NSArray<UIWindow *> *KTWindows(void) {
    UIApplication *app = UIApplication.sharedApplication;
    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];

    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;

        UIWindowScene *windowScene = (UIWindowScene *)scene;

        if (windowScene.activationState == UISceneActivationStateUnattached)
            continue;

        [windows addObjectsFromArray:windowScene.windows];
    }

    return windows;
}

static UIViewController *KTTopVC(void) {
    for (UIWindow *window in KTWindows()) {
        if (window.hidden || !window.rootViewController)
            continue;

        UIViewController *vc = window.rootViewController;

        while (vc.presentedViewController)
            vc = vc.presentedViewController;

        return vc;
    }

    return nil;
}

static UIResponder *KTInput(void) {
    for (UIWindow *window in KTWindows()) {
        UIResponder *responder = window;

        while (responder) {
            if ([responder isFirstResponder] &&
                [responder conformsToProtocol:@protocol(UITextInput)]) {
                return responder;
            }

            if ([responder isKindOfClass:[UIView class]])
                responder = [(UIView *)responder superview];
            else
                break;
        }
    }

    return nil;
}

static void KTHaptic(void) {
    UIImpactFeedbackGenerator *generator =
        [[UIImpactFeedbackGenerator alloc]
            initWithStyle:UIImpactFeedbackStyleLight];

    [generator prepare];
    [generator impactOccurred];
}

static void KTClipboardOpen(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIResponder *input = KTInput();
        UIViewController *vc = KTTopVC();

        if (!vc)
            return;

        KTClipboardViewController *page =
            [[KTClipboardViewController alloc]
                initWithInput:(id<UITextInput>)input];

        UINavigationController *nav =
            [[UINavigationController alloc]
                initWithRootViewController:page];

        nav.modalPresentationStyle = UIModalPresentationPageSheet;

        [vc presentViewController:nav
                         animated:YES
                       completion:nil];
    });
}

static void KTAddButton(UIView *dock,
                        UIStackView *stack,
                        NSString *symbol,
                        NSString *title,
                        SEL action) {

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];

    button.tag = 10000 + stack.arrangedSubviews.count;

    UIImage *image = [UIImage systemImageNamed:symbol];

    if (image) {
        [button setImage:image forState:UIControlStateNormal];
    } else {
        [button setTitle:title forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:11.0];
    }

    button.accessibilityLabel = title;
    button.tintColor = UIColor.labelColor;

    [button addTarget:dock
               action:action
     forControlEvents:UIControlEventTouchUpInside];

    [stack addArrangedSubview:button];
}

static void KTInstallToolbar(UIView *dock) {
    if (!dock)
        return;

    if ([dock viewWithTag:KTTag])
        return;

    CGFloat dockWidth = CGRectGetWidth(dock.bounds);

    if (dockWidth <= 0.0)
        return;

    CGFloat width = dockWidth - 20.0;

    if (width > 240.0)
        width = 240.0;

    if (width < 160.0)
        width = 160.0;

    UIStackView *stack = [[UIStackView alloc] init];

    stack.tag = KTTag;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 0.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    [dock addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:dock.centerXAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:dock.bottomAnchor constant:-2.0],
        [stack.widthAnchor constraintEqualToConstant:width],
        [stack.heightAnchor constraintEqualToConstant:36.0]
    ]];

    KTAddButton(dock,
                stack,
                @"list.clipboard",
                @"剪贴",
                @selector(kt_clipboard:));

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
}

%hook UIKeyboardDockView

- (void)layoutSubviews {
    %orig;

    UIView *dock = (UIView *)self;

    if (!dock)
        return;

    if ([dock viewWithTag:KTTag])
        return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!dock)
            return;

        if ([dock viewWithTag:KTTag])
            return;

        if (!dock.window || dock.bounds.size.width <= 0.0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!dock)
                    return;

                if ([dock viewWithTag:KTTag])
                    return;

                KTInstallToolbar(dock);
            });

            return;
        }

        KTInstallToolbar(dock);
    });
}

%new
- (void)kt_clipboard:(UIButton *)sender {
    KTHaptic();
    KTClipboardOpen();
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

    [[UIApplication sharedApplication]
        sendAction:@selector(resignFirstResponder)
              to:nil
            from:nil
        forEvent:nil];
}

%end

%ctor {
    @autoreleasepool {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            NULL,
            CFSTR("com.keyboardtoolskayoko.reload"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
    }
}
