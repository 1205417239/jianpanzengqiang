#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "KTClipboardManager.h"
#import "KTClipboardViewController.h"
#import "KTSettings.h"


#pragma mark - 前向声明

@interface KTKeyboardToolbarTarget : NSObject

@property(nonatomic, weak) UIResponder *input;

- (instancetype)initWithInput:(UIResponder *)input;

@end


#pragma mark - 工具栏目标

@implementation KTKeyboardToolbarTarget

- (instancetype)initWithInput:(UIResponder *)input
{
    self = [super init];

    if (self) {
        _input = input;
    }

    return self;
}


#pragma mark - 找控制器

- (UIViewController *)viewControllerForResponder:(UIResponder *)responder
{
    UIResponder *current = responder;

    while (current) {

        if ([current isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)current;
        }

        current = current.nextResponder;
    }

    return nil;
}


#pragma mark - 剪贴板

- (void)clipboardTapped:(UIButton *)sender
{
    UIResponder *input = self.input;

    if (!input) {
        return;
    }


    UIViewController *viewController =
        [self viewControllerForResponder:input];


    if (!viewController) {

        if ([input isKindOfClass:[UIView class]]) {

            UIView *view = (UIView *)input;

            UIWindow *window = view.window;

            if (window) {

                UIViewController *root =
                    window.rootViewController;

                while (root.presentedViewController) {
                    root = root.presentedViewController;
                }

                viewController = root;
            }
        }
    }


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


#pragma mark - 全选

- (void)selectAllTapped:(UIButton *)sender
{
    UIResponder *input = self.input;

    if (!input) {
        return;
    }


    if ([input respondsToSelector:@selector(selectAll:)]) {

        [(id)input selectAll:nil];
    }
}


#pragma mark - 粘贴

- (void)pasteTapped:(UIButton *)sender
{
    UIResponder *input = self.input;

    if (!input) {
        return;
    }


    if ([input respondsToSelector:@selector(paste:)]) {

        [(id)input paste:nil];
    }
}


#pragma mark - 撤销

- (void)undoTapped:(UIButton *)sender
{
    UIResponder *input = self.input;

    if (!input) {
        return;
    }


    NSUndoManager *undoManager =
        input.undoManager;


    if (undoManager &&
        [undoManager canUndo]) {

        [undoManager undo];
    }
}


#pragma mark - 收起键盘

- (void)dismissTapped:(UIButton *)sender
{
    UIResponder *input = self.input;

    if (!input) {
        return;
    }


    [input resignFirstResponder];
}

@end


#pragma mark - 工具栏

static const void *KTToolbarKey =
    &KTToolbarKey;


static const CGFloat KTToolbarHeight =
    44.0;


static UIToolbar *KTCreateToolbar(UIResponder *input)
{
    if (!input) {
        return nil;
    }


    KTKeyboardToolbarTarget *target =
        [[KTKeyboardToolbarTarget alloc]
            initWithInput:input];


    UIToolbar *toolbar =
        [[UIToolbar alloc]
            initWithFrame:
                CGRectMake(0.0,
                           0.0,
                           0.0,
                           KTToolbarHeight)];


    toolbar.translucent = YES;
    toolbar.barStyle = UIBarStyleDefault;


    /*
     五个固定功能：

     1. 剪贴板
     2. 全选
     3. 粘贴
     4. 撤销
     5. 收起键盘
     */


    UIButton *clipboard =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [clipboard setTitle:@"剪贴板"
               forState:UIControlStateNormal];

    clipboard.titleLabel.font =
        [UIFont systemFontOfSize:14.0];

    [clipboard addTarget:target
                  action:@selector(clipboardTapped:)
        forControlEvents:UIControlEventTouchUpInside];


    UIButton *selectAll =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [selectAll setTitle:@"全选"
               forState:UIControlStateNormal];

    selectAll.titleLabel.font =
        [UIFont systemFontOfSize:14.0];

    [selectAll addTarget:target
                  action:@selector(selectAllTapped:)
        forControlEvents:UIControlEventTouchUpInside];


    UIButton *paste =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [paste setTitle:@"粘贴"
            forState:UIControlStateNormal];

    paste.titleLabel.font =
        [UIFont systemFontOfSize:14.0];

    [paste addTarget:target
              action:@selector(pasteTapped:)
    forControlEvents:UIControlEventTouchUpInside];


    UIButton *undo =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [undo setTitle:@"撤销"
           forState:UIControlStateNormal];

    undo.titleLabel.font =
        [UIFont systemFontOfSize:14.0];

    [undo addTarget:target
             action:@selector(undoTapped:)
   forControlEvents:UIControlEventTouchUpInside];


    UIButton *dismiss =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [dismiss setTitle:@"收起键盘"
             forState:UIControlStateNormal];

    dismiss.titleLabel.font =
        [UIFont systemFontOfSize:14.0];

    [dismiss addTarget:target
                action:@selector(dismissTapped:)
      forControlEvents:UIControlEventTouchUpInside];


    NSArray *buttons = @[
        clipboard,
        selectAll,
        paste,
        undo,
        dismiss
    ];


    NSMutableArray *items =
        [NSMutableArray array];


    for (NSUInteger i = 0;
         i < buttons.count;
         i++) {

        UIButton *button = buttons[i];


        UIBarButtonItem *item =
            [[UIBarButtonItem alloc]
                initWithCustomView:button];


        [items addObject:item];


        /*
         五个按钮之间使用弹性空间。
         不增加任何额外按钮。
         */

        if (i < buttons.count - 1) {

            UIBarButtonItem *space =
                [[UIBarButtonItem alloc]
                    initWithBarButtonSystemItem:
                        UIBarButtonSystemItemFlexibleSpace
                    target:nil
                    action:nil];


            [items addObject:space];
        }
    }


    [toolbar setItems:items
             animated:NO];


    return toolbar;
}


#pragma mark - 获取 / 创建工具栏

static UIToolbar *KTToolbarForInput(UIResponder *input)
{
    if (!input) {
        return nil;
    }


    UIToolbar *toolbar =
        objc_getAssociatedObject(input,
                                 KTToolbarKey);


    if (toolbar) {
        return toolbar;
    }


    toolbar =
        KTCreateToolbar(input);


    if (!toolbar) {
        return nil;
    }


    objc_setAssociatedObject(input,
                             KTToolbarKey,
                             toolbar,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);


    return toolbar;
}


#pragma mark - UITextField

%hook UITextField


/*
 不再直接修改 inputAccessoryView。

 UIKit 需要读取 inputAccessoryView 时，
 如果当前输入框已经成为第一响应者，
 直接返回我们的工具栏。
 */

- (UIView *)inputAccessoryView
{
    UIView *original =
        %orig;


    if (!self.isFirstResponder) {
        return original;
    }


    UIToolbar *toolbar =
        KTToolbarForInput(self);


    if (toolbar) {
        return toolbar;
    }


    return original;
}


- (void)setInputAccessoryView:(UIView *)view
{
    /*
     如果第三方 App 自己重新设置 accessory，
     清除旧的缓存工具栏。
     */

    objc_setAssociatedObject(self,
                             KTToolbarKey,
                             nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);


    %orig(view);
}


%end


#pragma mark - UITextView

%hook UITextView


/*
 UITextView 同样直接通过 getter 提供工具栏。
 */

- (UIView *)inputAccessoryView
{
    UIView *original =
        %orig;


    if (!self.isFirstResponder) {
        return original;
    }


    UIToolbar *toolbar =
        KTToolbarForInput(self);


    if (toolbar) {
        return toolbar;
    }


    return original;
}


- (void)setInputAccessoryView:(UIView *)view
{
    /*
     App 如果重新设置 accessory，
     清除旧缓存。
     */

    objc_setAssociatedObject(self,
                             KTToolbarKey,
                             nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);


    %orig(view);
}


%end


#pragma mark - 启动

%ctor
{
    @autoreleasepool {

        /*
         剪贴板记录功能继续由
         KTClipboardManager 负责。

         本文件只负责键盘工具栏。
         */

        if (KTEnabled() &&
            KTRecordClipboard()) {

            [[KTClipboardManager sharedManager]
                startMonitoring];
        }
    }
}
