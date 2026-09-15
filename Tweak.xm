#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "KTClipboardViewController.h"

static NSInteger const KTTag = 9999;
static CGFloat const KTWidth = 240.0;
static CGFloat const KTHeight = 36.0;

@interface UIKeyboardImpl : NSObject
+ (instancetype)activeInstance;
- (void)dismissKeyboard;
@end

static UIView *KTFirstResponder(UIView *v)
{
    if (v.isFirstResponder) return v;
    for (UIView *s in v.subviews) {
        UIView *r = KTFirstResponder(s);
        if (r) return r;
    }
    return nil;
}

static id<UITextInput> KTCurrentInput(void)
{
    UIApplication *app = UIApplication.sharedApplication;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;

            UIWindowScene *ws = (UIWindowScene *)scene;
            if (ws.activationState != UISceneActivationStateForegroundActive &&
                ws.activationState != UISceneActivationStateForegroundInactive)
                continue;

            for (UIWindow *w in ws.windows) {
                if (w.hidden || w.alpha < 0.01) continue;
                UIView *r = KTFirstResponder(w);
                if ([r conformsToProtocol:@protocol(UITextInput)])
                    return (id<UITextInput>)r;
            }
        }
    }

    return nil;
}

static UIViewController *KTTopVC(UIViewController *vc)
{
    if (vc.presentedViewController)
        return KTTopVC(vc.presentedViewController);

    if ([vc isKindOfClass:UINavigationController.class])
        return KTTopVC(((UINavigationController *)vc).visibleViewController);

    if ([vc isKindOfClass:UITabBarController.class])
        return KTTopVC(((UITabBarController *)vc).selectedViewController);

    return vc;
}

static UIViewController *KTCurrentVC(void)
{
    UIApplication *app = UIApplication.sharedApplication;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;

            UIWindowScene *ws = (UIWindowScene *)scene;
            if (ws.activationState != UISceneActivationStateForegroundActive &&
                ws.activationState != UISceneActivationStateForegroundInactive)
                continue;

            for (UIWindow *w in ws.windows) {
                if (w.hidden || w.alpha < 0.01) continue;
                if (!w.rootViewController) continue;
                return KTTopVC(w.rootViewController);
            }
        }
    }

    return nil;
}

static void KTHaptic(void)
{
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *g =
            [[UIImpactFeedbackGenerator alloc]
                initWithStyle:UIImpactFeedbackStyleLight];
        [g prepare];
        [g impactOccurred];
    }
}

static void KTDismiss(id self, SEL _cmd, UIButton *sender)
{
    KTHaptic();

    Class c = objc_getClass("UIKeyboardImpl");
    if (!c) return;

    id k = [c activeInstance];
    if ([k respondsToSelector:@selector(dismissKeyboard)])
        [k dismissKeyboard];
}

static void KTSelectAll(id self, SEL _cmd, UIButton *sender)
{
    KTHaptic();
    [UIApplication.sharedApplication
        sendAction:@selector(selectAll:)
        to:nil from:nil forEvent:nil];
}

static void KTPaste(id self, SEL _cmd, UIButton *sender)
{
    KTHaptic();
    [UIApplication.sharedApplication
        sendAction:@selector(paste:)
        to:nil from:nil forEvent:nil];
}

static void KTUndo(id self, SEL _cmd, UIButton *sender)
{
    KTHaptic();
    [UIApplication.sharedApplication
        sendAction:@selector(undo:)
        to:nil from:nil forEvent:nil];
}

static void KTClipboard(id self, SEL _cmd, UIButton *sender)
{
    KTHaptic();

    id<UITextInput> input = KTCurrentInput();
    if (!input) return;

    UIViewController *vc = KTCurrentVC();
    if (!vc) return;

    KTClipboardViewController *clipboard =
        [[KTClipboardViewController alloc] initWithInput:input];

    clipboard.modalPresentationStyle =
        UIModalPresentationPageSheet;

    [vc presentViewController:clipboard
                     animated:YES
                   completion:nil];
}

static void KTInstall(Class c)
{
    if (!c) return;

    class_addMethod(c, @selector(didTapClipboard:),
                    (IMP)KTClipboard, "v@:@");

    class_addMethod(c, @selector(didTapSelectAll:),
                    (IMP)KTSelectAll, "v@:@");

    class_addMethod(c, @selector(didTapPaste:),
                    (IMP)KTPaste, "v@:@");

    class_addMethod(c, @selector(didTapUndo:),
                    (IMP)KTUndo, "v@:@");

    class_addMethod(c, @selector(didTapDismiss:),
                    (IMP)KTDismiss, "v@:@");
}

static UIStackView *KTCreateToolbar(UIView *dock)
{
    UIView *old = [dock viewWithTag:KTTag];
    if (old) return (UIStackView *)old;

    UIStackView *stack =
        [[UIStackView alloc] initWithFrame:CGRectZero];

    stack.tag = KTTag;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    [dock addSubview:stack];

    NSArray *names = @[
        @"doc.on.clipboard",
        @"selection.pin.in.out",
        @"doc.on.clipboard",
        @"arrow.uturn.backward",
        @"keyboard.chevron.compact.down"
    ];

    NSArray *labels = @[
        @"剪贴板",
        @"全选",
        @"粘贴",
        @"撤销",
        @"收起键盘"
    ];

    NSArray *actions = @[
        NSStringFromSelector(@selector(didTapClipboard:)),
        NSStringFromSelector(@selector(didTapSelectAll:)),
        NSStringFromSelector(@selector(didTapPaste:)),
        NSStringFromSelector(@selector(didTapUndo:)),
        NSStringFromSelector(@selector(didTapDismiss:))
    ];

    for (NSInteger i = 0; i < 5; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];

        if (@available(iOS 13.0, *)) {
            UIImage *image =
                [UIImage systemImageNamed:names[i]];
            [b setImage:image forState:UIControlStateNormal];
        }

        b.accessibilityLabel = labels[i];

        [b addTarget:dock
              action:NSSelectorFromString(actions[i])
    forControlEvents:UIControlEventTouchUpInside];

        [stack addArrangedSubview:b];

        [b.widthAnchor constraintEqualToConstant:KTWidth / 5.0].active = YES;
        [b.heightAnchor constraintEqualToConstant:KTHeight].active = YES;
    }

    [stack.widthAnchor constraintEqualToConstant:KTWidth].active = YES;
    [stack.heightAnchor constraintEqualToConstant:KTHeight].active = YES;

    [stack.centerXAnchor
        constraintEqualToAnchor:dock.centerXAnchor].active = YES;

    [stack.bottomAnchor
        constraintEqualToAnchor:dock.bottomAnchor
        constant:-23.0].active = YES;

    return stack;
}

%hook UIKeyboardDockView

- (void)layoutSubviews
{
    %orig;

    UIView *dock = (UIView *)self;
    if (!dock) return;

    if ([dock viewWithTag:KTTag]) return;

    KTCreateToolbar(dock);
}

%end

%ctor
{
    @autoreleasepool {
        KTInstall(objc_getClass("UIKeyboardDockView"));
    }
}
