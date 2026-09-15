#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <CoreFoundation/CoreFoundation.h>
#import "KTClipboardViewController.h"

static NSInteger const KTTag = 58731;

static NSArray<UIWindow *> *KTWindows(void) {
    UIApplication *app = UIApplication.sharedApplication;
    NSMutableArray<UIWindow *> *result = [NSMutableArray array];

    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;

        UIWindowScene *windowScene = (UIWindowScene *)scene;

        if (windowScene.activationState == UISceneActivationStateUnattached)
            continue;

        [result addObjectsFromArray:windowScene.windows];
    }

    return result;
}

static UIResponder *KTFindFirstResponder(UIView *view) {
    if ([view isFirstResponder])
        return view;

    for (UIView *subview in view.subviews) {
        UIResponder *responder = KTFindFirstResponder(subview);

        if (responder)
            return responder;
    }

    return nil;
}

static UIResponder *KTInput(void) {
    for (UIWindow *window in KTWindows()) {
        UIResponder *responder = KTFindFirstResponder(window);

        if (responder &&
            [responder conformsToProtocol:@protocol(UITextInput)]) {
            return responder;
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

static UIWindow *KTClipboardWindow;
static UIResponder *KTClipboardInput;

static void KTClipboardCloseAnimated(void) {
    UIWindow *window = KTClipboardWindow;
    UIResponder *input = KTClipboardInput;

    if (!window)
        return;

    KTClipboardWindow = nil;
    KTClipboardInput = nil;

    CGFloat distance = CGRectGetHeight(window.bounds) + 40.0;

    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        window.frame = CGRectOffset(window.frame, 0.0, distance);
    }
                     completion:^(BOOL finished) {
        window.hidden = YES;
        window.rootViewController = nil;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (input && [input respondsToSelector:@selector(becomeFirstResponder)])
                [(UIResponder *)input becomeFirstResponder];
        });
    }];
}

static void KTClipboardOpen(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (KTClipboardWindow)
            return;

        UIResponder *input = KTInput();
        if (!input)
            return;

        UIWindowScene *scene = nil;
        for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
            if (![candidate isKindOfClass:[UIWindowScene class]])
                continue;

            UIWindowScene *ws = (UIWindowScene *)candidate;
            if (ws.activationState == UISceneActivationStateForegroundActive) {
                scene = ws;
                break;
            }

            if (!scene && ws.activationState != UISceneActivationStateUnattached)
                scene = ws;
        }

        if (!scene)
            return;

        KTClipboardInput = input;

        if ([input isFirstResponder])
            [input resignFirstResponder];

        CGRect bounds = scene.coordinateSpace.bounds;
        CGFloat screenWidth = CGRectGetWidth(bounds);
        CGFloat screenHeight = CGRectGetHeight(bounds);

        CGFloat width = MIN(screenWidth - 24.0, 430.0);
        CGFloat height = screenHeight * 0.70;
        CGFloat x = (screenWidth - width) * 0.5;
        CGFloat bottomMargin = 12.0;
        CGFloat y = screenHeight - height - bottomMargin;

        UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
        window.frame = CGRectMake(x, screenHeight + 20.0, width, height);
        window.windowLevel = UIWindowLevelAlert + 100.0;
        window.backgroundColor = UIColor.clearColor;
        window.hidden = NO;

        KTClipboardViewController *page =
            [[KTClipboardViewController alloc]
                initWithInput:(id<UITextInput>)KTClipboardInput];

        __weak UIWindow *weakWindow = window;
        page.closeHandler = ^{
            UIWindow *strongWindow = weakWindow;
            if (strongWindow == KTClipboardWindow)
                KTClipboardCloseAnimated();
        };

        UINavigationController *nav =
            [[UINavigationController alloc]
                initWithRootViewController:page];

        nav.view.backgroundColor = UIColor.systemBackgroundColor;
        nav.view.layer.cornerRadius = 20.0;
        nav.view.layer.masksToBounds = YES;

        window.rootViewController = nav;
        KTClipboardWindow = window;

        [UIView animateWithDuration:0.24
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            window.frame = CGRectMake(x, y, width, height);
        }
                         completion:nil];
    });
}

static void KTAddButton(UIView *dock,
                        UIStackView *stack,
                        NSString *symbol,
                        NSString *title,
                        SEL action) {

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];

    button.tag = 20000 + stack.arrangedSubviews.count;

    UIImage *image = [UIImage systemImageNamed:symbol];

    if (image) {
        [button setImage:image forState:UIControlStateNormal];
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
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

    CGFloat width = MIN(240.0, dockWidth - 20.0);

    if (width < 160.0)
        width = dockWidth - 10.0;

    if (width <= 0.0)
        return;

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
        [stack.bottomAnchor constraintEqualToAnchor:dock.bottomAnchor constant:-23.0],
        [stack.widthAnchor constraintEqualToConstant:width],
        [stack.heightAnchor constraintEqualToConstant:36.0]
    ]];

    KTAddButton(
        dock,
        stack,
        @"list.clipboard",
        @"剪贴",
        @selector(kt_clipboard:)
    );

    KTAddButton(
        dock,
        stack,
        @"selection.pin.in.out",
        @"全选",
        @selector(kt_selectAll:)
    );

    KTAddButton(
        dock,
        stack,
        @"doc.on.clipboard",
        @"粘贴",
        @selector(kt_paste:)
    );

    KTAddButton(
        dock,
        stack,
        @"arrow.uturn.backward",
        @"撤销",
        @selector(kt_undo:)
    );

    KTAddButton(
        dock,
        stack,
        @"keyboard.chevron.compact.down",
        @"收起",
        @selector(kt_dismiss:)
    );
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

    Class keyboardImplClass = objc_getClass("UIKeyboardImpl");

    if (keyboardImplClass &&
        [keyboardImplClass respondsToSelector:@selector(activeInstance)]) {

        id keyboard =
            ((id (*)(id, SEL))objc_msgSend)(
                keyboardImplClass,
                @selector(activeInstance)
            );

        if (keyboard &&
            [keyboard respondsToSelector:@selector(dismissKeyboard)]) {

            ((void (*)(id, SEL))objc_msgSend)(
                keyboard,
                @selector(dismissKeyboard)
            );

            return;
        }
    }

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
