#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <CoreFoundation/CoreFoundation.h>
#import "KTClipboardViewController.h"

static NSInteger const KTTag = 58731;
static UIWindow *KTClipboardWindow;
static KTClipboardViewController *KTClipboardController;
static UIResponder *KTClipboardInput;

@interface KTClipboardPassThroughWindow : UIWindow
@property(nonatomic,weak) UIView *interactiveView;
@end

@implementation KTClipboardPassThroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *view = self.interactiveView;
    if (!view || self.hidden || self.alpha <= 0.01) return nil;
    CGPoint local = [view convertPoint:point fromView:self];
    if (!CGRectContainsPoint(view.bounds, local)) return nil;
    return [super hitTest:point withEvent:event];
}
@end

static NSArray<UIWindow *> *KTWindows(void) {
    NSMutableArray *windows = [NSMutableArray array];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        if (ws.activationState == UISceneActivationStateUnattached) continue;
        [windows addObjectsFromArray:ws.windows];
    }
    return windows;
}

static UIResponder *KTFindFirstResponder(UIView *view) {
    if ([view isFirstResponder]) return view;
    for (UIView *subview in view.subviews) {
        UIResponder *r = KTFindFirstResponder(subview);
        if (r) return r;
    }
    return nil;
}

static UIResponder *KTInput(void) {
    UIResponder *saved = KTClipboardInput;
    if (saved && [saved conformsToProtocol:@protocol(UITextInput)]) return saved;
    NSArray<UIWindow *> *windows = KTWindows();
    UIWindow *keyWindow = nil;
    for (UIWindow *window in windows) {
        if (window.hidden || window.alpha <= 0.01 || window == KTClipboardWindow) continue;
        if (window.isKeyWindow) { keyWindow = window; break; }
    }
    if (keyWindow) {
        UIResponder *r = KTFindFirstResponder(keyWindow);
        if (r && [r conformsToProtocol:@protocol(UITextInput)]) return r;
    }
    for (UIWindow *window in windows) {
        if (window.hidden || window.alpha <= 0.01 || window == KTClipboardWindow) continue;
        if (window.windowLevel != UIWindowLevelNormal) continue;
        UIResponder *r = KTFindFirstResponder(window);
        if (r && [r conformsToProtocol:@protocol(UITextInput)]) return r;
    }
    for (UIWindow *window in windows) {
        if (window.hidden || window.alpha <= 0.01 || window == KTClipboardWindow) continue;
        UIResponder *r = KTFindFirstResponder(window);
        if (r && [r conformsToProtocol:@protocol(UITextInput)]) return r;
    }
    return nil;
}
static UIWindowScene *KTActiveScene(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        if (ws.activationState == UISceneActivationStateForegroundActive) return ws;
    }
    return nil;
}

static void KTHaptic(void) {
    UIImpactFeedbackGenerator *g = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [g prepare];
    [g impactOccurred];
}

static void KTClipboardClose(void) {
    UIWindow *window = KTClipboardWindow;
    KTClipboardWindow = nil;
    KTClipboardController = nil;
    KTClipboardInput = nil;
    if (!window) return;
    window.hidden = YES;
    window.rootViewController = nil;
}

static void KTClipboardOpen(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (KTClipboardWindow) return;
        UIResponder *input = KTInput();
        UIWindowScene *scene = KTActiveScene();
        if (!input || !scene) return;

        KTClipboardInput = input;
        [input resignFirstResponder];

        KTClipboardPassThroughWindow *window = [[KTClipboardPassThroughWindow alloc] initWithWindowScene:scene];
        window.frame = scene.coordinateSpace.bounds;
        window.backgroundColor = UIColor.clearColor;
        window.opaque = NO;
        window.windowLevel = UIWindowLevelAlert + 1000.0;

        KTClipboardViewController *controller = [[KTClipboardViewController alloc] initWithInput:(id<UITextInput>)input];
        controller.closeHandler = ^{ KTClipboardClose(); };
        window.rootViewController = controller;
        [controller loadViewIfNeeded];
        window.interactiveView = controller.panel;
        KTClipboardWindow = window;
        KTClipboardController = controller;
        window.hidden = NO;
        [window makeKeyAndVisible];
    });
}

static void KTAddButton(UIView *dock, UIStackView *stack, NSString *symbol, NSString *title, SEL action) {
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
    [button addTarget:dock action:action forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:button];
}

static void KTInstallToolbar(UIView *dock) {
    if (!dock || [dock viewWithTag:KTTag]) return;
    CGFloat dockWidth = CGRectGetWidth(dock.bounds);
    if (dockWidth <= 0.0) return;
    CGFloat width = MIN(240.0, dockWidth - 20.0);
    if (width < 160.0) width = dockWidth - 10.0;
    if (width <= 0.0) return;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.tag = KTTag;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [dock addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:dock.centerXAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:dock.bottomAnchor constant:-23.0],
        [stack.widthAnchor constraintEqualToConstant:width],
        [stack.heightAnchor constraintEqualToConstant:36.0]
    ]];

    KTAddButton(dock, stack, @"list.clipboard", @"剪贴", @selector(kt_clipboard:));
    KTAddButton(dock, stack, @"selection.pin.in.out", @"全选", @selector(kt_selectAll:));
    KTAddButton(dock, stack, @"doc.on.clipboard", @"粘贴", @selector(kt_paste:));
    KTAddButton(dock, stack, @"arrow.uturn.backward", @"撤销", @selector(kt_undo:));
    KTAddButton(dock, stack, @"keyboard.chevron.compact.down", @"收起", @selector(kt_dismiss:));
}


%hook UIPasteboard

static void KTRecordPasteboardWrite(UIPasteboard *pb) {
    if (pb != UIPasteboard.generalPasteboard) return;
    if (!pb.string.length && !pb.image) return;
    NSString *bid = NSBundle.mainBundle.bundleIdentifier ?: @"";
    NSString *name = NSBundle.mainBundle.localizedInfoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleName"] ?: bid;
    [KTClipboardManager.sharedManager recordCurrentClipboardFromBundleIdentifier:bid appName:name];
}

- (void)setString:(NSString *)string { %orig; if (string.length) KTRecordPasteboardWrite(self); }
- (void)setString:(NSString *)string options:(NSDictionary *)options { %orig; if (string.length) KTRecordPasteboardWrite(self); }
- (void)setItems:(NSArray<NSDictionary<NSString *,id> *> *)items { %orig; if (items.count) KTRecordPasteboardWrite(self); }
- (void)setItems:(NSArray<NSDictionary<NSString *,id> *> *)items options:(NSDictionary *)options { %orig; if (items.count) KTRecordPasteboardWrite(self); }
- (void)setValue:(id)value forPasteboardType:(NSString *)pasteboardType { %orig; if (value) KTRecordPasteboardWrite(self); }
- (void)setData:(NSData *)data forPasteboardType:(NSString *)pasteboardType { %orig; if (data.length) KTRecordPasteboardWrite(self); }

%end

%hook UIResponder

- (BOOL)becomeFirstResponder {
    BOOL result = %orig;
    if (result && [self conformsToProtocol:@protocol(UITextInput)]) {
        KTClipboardInput = self;
    }
    return result;
}

%end

%hook UIKeyboardDockView

- (void)layoutSubviews {
    %orig;
    UIView *dock = (UIView *)self;
    if (!dock || [dock viewWithTag:KTTag]) return;
    dispatch_async(dispatch_get_main_queue(), ^{
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
    [[UIApplication sharedApplication] sendAction:@selector(selectAll:) to:nil from:nil forEvent:nil];
}

%new
- (void)kt_paste:(UIButton *)sender {
    KTHaptic();
    [[UIApplication sharedApplication] sendAction:@selector(paste:) to:nil from:nil forEvent:nil];
}

%new
- (void)kt_undo:(UIButton *)sender {
    KTHaptic();
    [[UIApplication sharedApplication] sendAction:@selector(undo:) to:nil from:nil forEvent:nil];
}

%new
- (void)kt_dismiss:(UIButton *)sender {
    KTHaptic();
    Class cls = objc_getClass("UIKeyboardImpl");
    if (cls && [cls respondsToSelector:@selector(activeInstance)]) {
        id keyboard = ((id (*)(id, SEL))objc_msgSend)(cls, @selector(activeInstance));
        if (keyboard && [keyboard respondsToSelector:@selector(dismissKeyboard)]) {
            ((void (*)(id, SEL))objc_msgSend)(keyboard, @selector(dismissKeyboard));
            return;
        }
    }
    [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];
}

%end

%ctor {
    @autoreleasepool {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, NULL,
            CFSTR("com.keyboardtoolskayoko.reload"), NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
    }
}
