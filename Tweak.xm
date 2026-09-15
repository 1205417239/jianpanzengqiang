#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "KTClipboardManager.h"
#import "KTClipboardViewController.h"
#import "KTSettings.h"

static const void *KTControllerKey = &KTControllerKey;
static const void *KTContainerKey = &KTContainerKey;
static const void *KTOriginalAccessoryKey = &KTOriginalAccessoryKey;
static BOOL KTInstallingAccessory = NO;

@interface KTKeyboardController : NSObject
@property(nonatomic,weak) UIResponder<UITextInput> *input;
@property(nonatomic,strong) UIToolbar *toolbar;
- (instancetype)initWithInput:(id<UITextInput>)input;
- (UIToolbar *)makeToolbar;
- (void)refresh;
@end

@interface KTAccessoryContainerView : UIView
@property(nonatomic,strong) UIView *originalView;
@property(nonatomic,strong) UIToolbar *toolbar;
- (instancetype)initWithOriginalView:(UIView *)original toolbar:(UIToolbar *)toolbar;
@end

@implementation KTAccessoryContainerView

- (instancetype)initWithOriginalView:(UIView *)original
                              toolbar:(UIToolbar *)toolbar {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _originalView = original;
        _toolbar = toolbar;
        self.backgroundColor = [UIColor clearColor];
        if (original) [self addSubview:original];
        [self addSubview:toolbar];
    }
    return self;
}

- (CGSize)intrinsicContentSize {
    CGFloat width = UIScreen.mainScreen.bounds.size.width;
    CGFloat originalHeight = 0.0;
    if (self.originalView) {
        CGSize s = [self.originalView sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
        originalHeight = s.height;
        if (originalHeight <= 0) originalHeight = self.originalView.bounds.size.height;
        if (originalHeight <= 0) originalHeight = 44.0;
    }
    CGFloat toolbarHeight = [self.toolbar sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height;
    if (toolbarHeight <= 0) toolbarHeight = 44.0;
    return CGSizeMake(UIViewNoIntrinsicMetric, originalHeight + toolbarHeight);
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width = self.bounds.size.width;
    CGFloat toolbarHeight = [self.toolbar sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height;
    if (toolbarHeight <= 0) toolbarHeight = 44.0;

    CGFloat originalHeight = MAX(0.0, self.bounds.size.height - toolbarHeight);
    if (self.originalView) {
        self.originalView.frame = CGRectMake(0, 0, width, originalHeight);
    }
    self.toolbar.frame = CGRectMake(0, originalHeight, width, toolbarHeight);
}
@end

@implementation KTKeyboardController

- (instancetype)initWithInput:(id<UITextInput>)input {
    if ((self = [super init])) _input = input;
    return self;
}

- (UIBarButtonItem *)button:(NSString *)title selector:(SEL)sel {
    UIBarButtonItem *b = [[UIBarButtonItem alloc] initWithTitle:title
                                                          style:UIBarButtonItemStylePlain
                                                         target:self
                                                         action:sel];
    return b;
}

- (void)clipboard {
    UIViewController *vc = [self host];
    if (!vc) return;

    KTClipboardViewController *p = [[KTClipboardViewController alloc] initWithInput:self.input];
    UINavigationController *n = [[UINavigationController alloc] initWithRootViewController:p];
    n.modalPresentationStyle = UIModalPresentationPageSheet;
    [vc presentViewController:n animated:YES completion:nil];
}

- (UIViewController *)host {
    UIResponder *r = (UIResponder *)self.input;
    while (r) {
        if ([r isKindOfClass:UIViewController.class]) return (UIViewController *)r;
        r = r.nextResponder;
    }
    return nil;
}

- (void)selectAll {
    if ([self.input respondsToSelector:@selector(selectAll:)]) [(id)self.input selectAll:nil];
}

- (void)paste {
    if ([self.input respondsToSelector:@selector(paste:)]) [(id)self.input paste:nil];
}

- (void)undo {
    [self.input.undoManager undo];
}

- (void)dismiss {
    [(UIResponder *)self.input resignFirstResponder];
}

- (UIToolbar *)makeToolbar {
    if (_toolbar) return _toolbar;

    _toolbar = [[UIToolbar alloc] initWithFrame:CGRectZero];
    UIBarButtonItem *a = [self button:@"剪贴板" selector:@selector(clipboard)];
    UIBarButtonItem *b = [self button:@"全选" selector:@selector(selectAll)];
    UIBarButtonItem *c = [self button:@"粘贴" selector:@selector(paste)];
    UIBarButtonItem *d = [self button:@"撤销" selector:@selector(undo)];
    UIBarButtonItem *e = [self button:@"收起键盘" selector:@selector(dismiss)];

    UIBarButtonItem *s1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *s2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *s3 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *s4 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    _toolbar.items = @[a, s1, b, s2, c, s3, d, s4, e];
    return _toolbar;
}

- (void)refresh {
    [self.toolbar setNeedsLayout];
    [self.toolbar invalidateIntrinsicContentSize];
}
@end

static BOOL KTIsInputResponder(id obj) {
    if (!obj) return NO;
    if (![obj isKindOfClass:[UIResponder class]]) return NO;
    if (![obj conformsToProtocol:@protocol(UITextInput)]) return NO;
    return YES;
}

static KTKeyboardController *KTControllerForInput(id obj) {
    return objc_getAssociatedObject(obj, KTControllerKey);
}

static void KTInstallAccessory(id obj) {
    if (!KTEnabled()) return;
    if (!KTIsInputResponder(obj)) return;

    KTKeyboardController *controller = KTControllerForInput(obj);
    if (!controller) {
        controller = [[KTKeyboardController alloc] initWithInput:obj];
        objc_setAssociatedObject(obj, KTControllerKey, controller, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    UIView *current = [(UIResponder *)obj inputAccessoryView];
    KTAccessoryContainerView *existingContainer = objc_getAssociatedObject(obj, KTContainerKey);
    if (existingContainer && current == existingContainer) return;

    // Keep an app's own accessory view instead of replacing it.
    UIView *original = current;
    KTAccessoryContainerView *container = [[KTAccessoryContainerView alloc]
        initWithOriginalView:original toolbar:[controller makeToolbar]];

    objc_setAssociatedObject(obj, KTOriginalAccessoryKey, original, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(obj, KTContainerKey, container, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    KTInstallingAccessory = YES;
    [(UIResponder *)obj setInputAccessoryView:container];
    KTInstallingAccessory = NO;

    [container invalidateIntrinsicContentSize];
    [(UIResponder *)obj reloadInputViews];
}

%hook UIResponder

- (BOOL)becomeFirstResponder {
    BOOL result = %orig;
    if (result && KTIsInputResponder(self)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            KTInstallAccessory(self);
        });
    }
    return result;
}

- (void)setInputAccessoryView:(UIView *)view {
    if (KTInstallingAccessory || !KTIsInputResponder(self)) {
        %orig(view);
        return;
    }

    // Let the application update its own accessory. We will wrap it on the next run-loop turn.
    %orig(view);

    if (self.isFirstResponder) {
        dispatch_async(dispatch_get_main_queue(), ^{
            KTInstallAccessory(self);
        });
    }
}

%end

%ctor {
    @autoreleasepool {
        [[KTClipboardManager sharedManager] startMonitoring];
    }
}
