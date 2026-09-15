#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <CoreFoundation/CoreFoundation.h>
#import "KTClipboardViewController.h"

static NSInteger const KTTag = 9999;
static NSInteger const KTMaxRetry = 8;

#pragma mark - Top VC / Input 查找

static UIViewController *KTTopVC(void) {
    UIApplication *app = UIApplication.sharedApplication;

    UIViewController *fallback = nil;

    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class])
            continue;

        BOOL isActive = (scene.activationState == UISceneActivationStateForegroundActive);

        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.hidden || !window.rootViewController)
                continue;

            UIViewController *vc = window.rootViewController;

            while (vc.presentedViewController)
                vc = vc.presentedViewController;

            if (isActive) {
                // 优先返回前台活跃场景里的顶层控制器
                return vc;
            }

            if (!fallback) {
                // 没有找到活跃场景时，先记下第一个可用的作为兜底
                fallback = vc;
            }
        }
    }

    if (fallback)
        return fallback;

    // 兜底：老式 API，适配没有正确匹配到 UIWindowScene 的情况（如 SpringBoard 某些窗口）
    UIWindow *keyWindow = nil;

    for (UIWindow *w in app.windows) {
        if (w.isKeyWindow) {
            keyWindow = w;
            break;
        }
    }

    if (!keyWindow)
        keyWindow = app.windows.firstObject;

    UIViewController *vc = keyWindow.rootViewController;

    while (vc.presentedViewController)
        vc = vc.presentedViewController;

    return vc;
}

static UIResponder *KTInput(void) {
    UIApplication *app = UIApplication.sharedApplication;

    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] ||
            scene.activationState != UISceneActivationStateForegroundActive)
            continue;

        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            UIResponder *responder = window;

            while (responder) {
                if ([responder isFirstResponder] &&
                    [responder conformsToProtocol:@protocol(UITextInput)]) {
                    return responder;
                }

                if ([responder isKindOfClass:UIView.class])
                    responder = ((UIView *)responder).superview;
                else
                    break;
            }
        }
    }

    // 兜底：走老式 windows 遍历（例如场景枚举没命中时）
    for (UIWindow *window in app.windows) {
        UIResponder *responder = window;

        while (responder) {
            if ([responder isFirstResponder] &&
                [responder conformsToProtocol:@protocol(UITextInput)]) {
                return responder;
            }

            if ([responder isKindOfClass:UIView.class])
                responder = ((UIView *)responder).superview;
            else
                break;
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
        UIResponder *input = KTInput();
        UIViewController *vc = KTTopVC();

        if (!vc) {
            // 找不到可以 present 的控制器，直接返回，避免崩溃
            return;
        }

        KTClipboardViewController *page =
            [[KTClipboardViewController alloc] initWithInput:(id<UITextInput>)input];

        UINavigationController *nav =
            [[UINavigationController alloc] initWithRootViewController:page];

        nav.modalPresentationStyle = UIModalPresentationPageSheet;

        [vc presentViewController:nav
                         animated:YES
                       completion:nil];
    });
}

#pragma mark - 工具栏创建

static void KTAddButton(UIView *dock,
                        UIStackView *stack,
                        NSString *symbol,
                        NSString *title,
                        SEL action) {

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];

    button.tag = 10000 + (NSInteger)stack.arrangedSubviews.count;

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

// 带重试次数上限的安装尝试：如果 dock 还没有 window / 宽度为 0，
// 就延后重试，而不是像原来那样只多试一次就放弃。
static void KTTryInstallToolbar(UIView *dock, NSInteger attempt) {
    if (!dock)
        return;

    if ([dock viewWithTag:KTTag])
        return;

    if (dock.window && dock.bounds.size.width > 0.0) {
        KTInstallToolbar(dock);
        return;
    }

    if (attempt >= KTMaxRetry) {
        // 超过重试上限，放弃这一次；下次 layoutSubviews 触发时会重新尝试
        return;
    }

    __weak UIView *weakDock = dock;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                    dispatch_get_main_queue(), ^{
        UIView *strongDock = weakDock;

        if (!strongDock)
            return;

        KTTryInstallToolbar(strongDock, attempt + 1);
    });
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
        KTTryInstallToolbar(dock, 0);
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
