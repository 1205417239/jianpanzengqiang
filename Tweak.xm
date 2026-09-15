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

static UIViewController *KTTopVC(void) {
    UIViewController *fallback = nil;

    for (UIWindow *window in KTWindows()) {
        if (window.hidden || !window.rootViewController)
            continue;

        UIViewController *vc = window.rootViewController;

        while (vc.presentedViewController)
            vc = vc.presentedViewController;

        if (window.isKeyWindow)
            return vc;

        if (!fallback)
            fallback = vc;
    }

    return fallback;
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

        if (@available(iOS 16.0, *)) {
            UISheetPresentationController *sheet = nav.sheetPresentationController;

            UISheetPresentationControllerDetent *kayokoDetent =
                [UISheetPresentationControllerDetent
                    customDetentWithIdentifier:@"kayoko"
                    resolver:^(id<UISheetPresentationControllerDetentResolutionContext> context) {
                        CGFloat height = 468.0;
                        CGFloat maxHeight = context.maximumDetentValue;
                        if (height > maxHeight)
                            height = maxHeight;
                        return height;
                    }];

            sheet.detents = @[kayokoDetent, UISheetPresentationControllerDetent.largeDetent];
            sheet.selectedDetentIdentifier = @"kayoko";
            sheet.prefersGrabberVisible = YES;
            sheet.prefersScrollingExpandsWhenScrolledToEdge = YES;
        } else if (@available(iOS 15.0, *)) {
            UISheetPresentationController *sheet = nav.sheetPresentationController;
            sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent,
                              UISheetPresentationControllerDetent.largeDetent];
            sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
            sheet.prefersGrabberVisible = YES;
        }

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

    UIStackView *stack = (UIStackView *)[dock viewWithTag:KTTag];

    if (!stack) {
        stack = [[UIStackView alloc] init];
        stack.tag = KTTag;
        stack.axis = UILayoutConstraintAxisHorizontal;
        stack.distribution = UIStackViewDistributionFillEqually;
        stack.alignment = UIStackViewAlignmentCenter;
        stack.spacing = 0.0;
        stack.translatesAutoresizingMaskIntoConstraints = YES;

        [dock addSubview:stack];

        KTAddButton(dock, stack, @"list.clipboard", @"剪贴", @selector(kt_clipboard:));
        KTAddButton(dock, stack, @"selection.pin.in.out", @"全选", @selector(kt_selectAll:));
        KTAddButton(dock, stack, @"doc.on.clipboard", @"粘贴", @selector(kt_paste:));
        KTAddButton(dock, stack, @"arrow.uturn.backward", @"撤销", @selector(kt_undo:));
        KTAddButton(dock, stack, @"keyboard.chevron.compact.down", @"收起", @selector(kt_dismiss:));
    }

    CGFloat dockWidth = CGRectGetWidth(dock.bounds);
    CGFloat dockHeight = CGRectGetHeight(dock.bounds);

    if (dockWidth <= 0.0 || dockHeight <= 0.0)
        return;

    CGFloat width = MIN(240.0, dockWidth - 20.0);
    if (width < 200.0)
        width = MAX(0.0, dockWidth - 10.0);

    CGFloat height = MIN(36.0, dockHeight);
    CGFloat y = MAX(0.0, dockHeight - height - 23.0);

    stack.frame = CGRectMake(
        floor((dockWidth - width) * 0.5),
        floor(y),
        floor(width),
        floor(height)
    );
}

%hook UIKeyboardDockView

- (void)layoutSubviews {
    %orig;

    UIView *dock = (UIView *)self;

    if (!dock)
        return;

    KTInstallToolbar(dock);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!dock)
            return;

        KTInstallToolbar(dock);

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (dock)
                KTInstallToolbar(dock);
        });
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

    UIResponder *input = KTInput();

    if (input) {
        [[UIApplication sharedApplication]
            sendAction:@selector(undo:)
                  to:input
                from:nil
            forEvent:nil];
    } else {
        [[UIApplication sharedApplication]
            sendAction:@selector(undo:)
                  to:nil
                from:nil
            forEvent:nil];
    }
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
