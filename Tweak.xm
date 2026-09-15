#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "KTClipboardManager.h"
#import "KTClipboardViewController.h"
#import "KTSettings.h"

static const void *KTControllerKey = &KTControllerKey;
static const void *KTContainerKey = &KTContainerKey;
static const void *KTOriginalAccessoryKey = &KTOriginalAccessoryKey;

static BOOL KTInstallingAccessory = NO;

@interface UIResponder (KTInputAccessory)
@property(nonatomic, strong) UIView *inputAccessoryView;
- (void)setInputAccessoryView:(UIView *)view;
- (void)reloadInputViews;
@end

@interface KTKeyboardController : NSObject

@property(nonatomic, weak) id<UITextInput> input;
@property(nonatomic, strong) UIToolbar *toolbar;

- (instancetype)initWithInput:(id<UITextInput>)input;
- (UIToolbar *)makeToolbar;
- (void)refresh;

@end

@interface KTAccessoryContainerView : UIView

@property(nonatomic, strong) UIView *originalView;
@property(nonatomic, strong) UIToolbar *toolbar;

- (instancetype)initWithOriginalView:(UIView *)original
                              toolbar:(UIToolbar *)toolbar;

@end

@implementation KTAccessoryContainerView

- (instancetype)initWithOriginalView:(UIView *)original
                              toolbar:(UIToolbar *)toolbar {
    self = [super initWithFrame:CGRectZero];

    if (self) {
        _originalView = original;
        _toolbar = toolbar;

        self.backgroundColor = [UIColor clearColor];

        if (original) {
            [self addSubview:original];
        }

        [self addSubview:toolbar];
    }

    return self;
}

- (CGSize)intrinsicContentSize {
    CGFloat width = UIScreen.mainScreen.bounds.size.width;

    CGFloat originalHeight = 0.0;

    if (self.originalView) {
        CGSize size = [self.originalView
            sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];

        originalHeight = size.height;

        if (originalHeight <= 0) {
            originalHeight = self.originalView.bounds.size.height;
        }

        if (originalHeight <= 0) {
            originalHeight = 44.0;
        }
    }

    CGFloat toolbarHeight = [self.toolbar
        sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height;

    if (toolbarHeight <= 0) {
        toolbarHeight = 44.0;
    }

    return CGSizeMake(
        UIViewNoIntrinsicMetric,
        originalHeight + toolbarHeight
    );
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width = self.bounds.size.width;

    CGFloat toolbarHeight = [self.toolbar
        sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height;

    if (toolbarHeight <= 0) {
        toolbarHeight = 44.0;
    }

    CGFloat originalHeight =
        MAX(0.0, self.bounds.size.height - toolbarHeight);

    if (self.originalView) {
        self.originalView.frame = CGRectMake(
            0,
            0,
            width,
            originalHeight
        );
    }

    self.toolbar.frame = CGRectMake(
        0,
        originalHeight,
        width,
        toolbarHeight
    );
}

@end


@implementation KTKeyboardController

- (instancetype)initWithInput:(id<UITextInput>)input {
    self = [super init];

    if (self) {
        _input = input;
    }

    return self;
}

- (UIBarButtonItem *)button:(NSString *)title
                   selector:(SEL)selector {

    return [[UIBarButtonItem alloc]
        initWithTitle:title
        style:UIBarButtonItemStylePlain
        target:self
        action:selector];
}

- (UIViewController *)host {
    UIResponder *responder = (UIResponder *)self.input;

    while (responder) {
        if ([responder isKindOfClass:UIViewController.class]) {
            return (UIViewController *)responder;
        }

        responder = responder.nextResponder;
    }

    return nil;
}

- (void)clipboard {
    UIViewController *viewController = [self host];

    if (!viewController) {
        return;
    }

    KTClipboardViewController *page =
        [[KTClipboardViewController alloc]
            initWithInput:self.input];

    UINavigationController *navigationController =
        [[UINavigationController alloc]
            initWithRootViewController:page];

    navigationController.modalPresentationStyle =
        UIModalPresentationPageSheet;

    [viewController
        presentViewController:navigationController
        animated:YES
        completion:nil];
}

- (void)selectAll {
    if ([self.input respondsToSelector:@selector(selectAll:)]) {
        [(id)self.input selectAll:nil];
    }
}

- (void)paste {
    if ([self.input respondsToSelector:@selector(paste:)]) {
        [(id)self.input paste:nil];
    }
}

- (void)undo {
    UIResponder *responder = (UIResponder *)self.input;

    if ([responder respondsToSelector:@selector(undoManager)]) {
        NSUndoManager *manager = responder.undoManager;

        if (manager && manager.canUndo) {
            [manager undo];
        }
    }
}

- (void)dismiss {
    [(UIResponder *)self.input resignFirstResponder];
}

- (UIToolbar *)makeToolbar {
    if (_toolbar) {
        return _toolbar;
    }

    _toolbar = [[UIToolbar alloc] initWithFrame:CGRectZero];

    UIBarButtonItem *clipboard =
        [self button:@"剪贴板"
            selector:@selector(clipboard)];

    UIBarButtonItem *selectAll =
        [self button:@"全选"
            selector:@selector(selectAll)];

    UIBarButtonItem *paste =
        [self button:@"粘贴"
            selector:@selector(paste)];

    UIBarButtonItem *undo =
        [self button:@"撤销"
            selector:@selector(undo)];

    UIBarButtonItem *dismiss =
        [self button:@"收起键盘"
            selector:@selector(dismiss)];

    UIBarButtonItem *space1 =
        [[UIBarButtonItem alloc]
            initWithBarButtonSystemItem:
                UIBarButtonSystemItemFlexibleSpace
            target:nil
            action:nil];

    UIBarButtonItem *space2 =
        [[UIBarButtonItem alloc]
            initWithBarButtonSystemItem:
                UIBarButtonSystemItemFlexibleSpace
            target:nil
            action:nil];

    UIBarButtonItem *space3 =
        [[UIBarButtonItem alloc]
            initWithBarButtonSystemItem:
                UIBarButtonSystemItemFlexibleSpace
            target:nil
            action:nil];

    UIBarButtonItem *space4 =
        [[UIBarButtonItem alloc]
            initWithBarButtonSystemItem:
                UIBarButtonSystemItemFlexibleSpace
            target:nil
            action:nil];

    _toolbar.items = @[
        clipboard,
        space1,
        selectAll,
        space2,
        paste,
        space3,
        undo,
        space4,
        dismiss
    ];

    return _toolbar;
}

- (void)refresh {
    [self.toolbar setNeedsLayout];
    [self.toolbar invalidateIntrinsicContentSize];
}

@end


static BOOL KTIsInputResponder(id object) {

    if (!object) {
        return NO;
    }

    if (![object isKindOfClass:[UIResponder class]]) {
        return NO;
    }

    if (![object conformsToProtocol:@protocol(UITextInput)]) {
        return NO;
    }

    return YES;
}


static KTKeyboardController *KTControllerForInput(id object) {
    return objc_getAssociatedObject(
        object,
        KTControllerKey
    );
}


static void KTInstallAccessory(id object) {

    if (!KTEnabled()) {
        return;
    }

    if (!KTIsInputResponder(object)) {
        return;
    }

    id<UITextInput> input = (id<UITextInput>)object;

    KTKeyboardController *controller =
        KTControllerForInput(object);

    if (!controller) {

        controller =
            [[KTKeyboardController alloc]
                initWithInput:input];

        objc_setAssociatedObject(
            object,
            KTControllerKey,
            controller,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );
    }

    UIView *current =
        [(UIResponder *)object inputAccessoryView];

    KTAccessoryContainerView *existingContainer =
        objc_getAssociatedObject(
            object,
            KTContainerKey
        );

    if (existingContainer && current == existingContainer) {
        return;
    }

    UIView *original = current;

    KTAccessoryContainerView *container =
        [[KTAccessoryContainerView alloc]
            initWithOriginalView:original
            toolbar:[controller makeToolbar]];

    objc_setAssociatedObject(
        object,
        KTOriginalAccessoryKey,
        original,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );

    objc_setAssociatedObject(
        object,
        KTContainerKey,
        container,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );

    KTInstallingAccessory = YES;

    [(UIResponder *)object
        setInputAccessoryView:container];

    KTInstallingAccessory = NO;

    [container invalidateIntrinsicContentSize];

    [(UIResponder *)object reloadInputViews];
}


%hook UIResponder

- (BOOL)becomeFirstResponder {

    BOOL result = %orig;

    if (result && KTIsInputResponder(self)) {

        __weak UIResponder *weakSelf = self;

        dispatch_async(
            dispatch_get_main_queue(),
            ^{

                UIResponder *strongSelf = weakSelf;

                if (!strongSelf) {
                    return;
                }

                KTInstallAccessory(strongSelf);
            }
        );
    }

    return result;
}


- (void)setInputAccessoryView:(UIView *)view {

    if (KTInstallingAccessory ||
        !KTIsInputResponder(self)) {

        %orig(view);
        return;
    }

    %orig(view);

    if (self.isFirstResponder) {

        __weak UIResponder *weakSelf = self;

        dispatch_async(
            dispatch_get_main_queue(),
            ^{

                UIResponder *strongSelf = weakSelf;

                if (!strongSelf) {
                    return;
                }

                KTInstallAccessory(strongSelf);
            }
        );
    }
}

%end


%ctor {

    @autoreleasepool {

        [[KTClipboardManager sharedManager]
            startMonitoring];
    }
}
