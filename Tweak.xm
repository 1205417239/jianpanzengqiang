#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "KTClipboardManager.h"
#import "KTClipboardViewController.h"
#import "KTSettings.h"

static const void *KTControllerKey=&KTControllerKey;

@interface KTKeyboardController : NSObject
@property(nonatomic,weak) id<UITextInput> input;
@property(nonatomic,strong) UIToolbar *toolbar;
- (instancetype)initWithInput:(id<UITextInput>)input;
@end
@implementation KTKeyboardController
- (instancetype)initWithInput:(id<UITextInput>)input { if((self=[super init])) _input=input; return self; }
- (UIBarButtonItem *)button:(NSString *)title selector:(SEL)sel { UIBarButtonItem *b=[[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStylePlain target:self action:sel]; b.width=20; return b; }
- (void)clipboard { UIViewController *vc=[self host]; if(!vc)return; KTClipboardViewController *p=[[KTClipboardViewController alloc] initWithInput:self.input]; UINavigationController *n=[[UINavigationController alloc] initWithRootViewController:p]; n.modalPresentationStyle=UIModalPresentationPageSheet; [vc presentViewController:n animated:YES completion:nil]; }
- (UIViewController *)host { UIResponder *r=(UIResponder *)self.input; while(r){ if([r isKindOfClass:UIViewController.class]) return (UIViewController *)r; r=r.nextResponder; } return nil; }
- (void)selectAll { if([self.input respondsToSelector:@selector(selectAll:)]) [(id)self.input selectAll:nil]; }
- (void)paste { if([self.input respondsToSelector:@selector(paste:)]) [(id)self.input paste:nil]; }
- (void)undo { [self.input.undoManager undo]; }
- (void)dismiss { [(UIResponder *)self.input resignFirstResponder]; }
- (UIToolbar *)makeToolbar { if(_toolbar)return _toolbar; _toolbar=[[UIToolbar alloc] init]; [_toolbar sizeToFit]; UIBarButtonItem *a=[self button:@"剪贴板" selector:@selector(clipboard)]; UIBarButtonItem *b=[self button:@"全选" selector:@selector(selectAll)]; UIBarButtonItem *c=[self button:@"粘贴" selector:@selector(paste)]; UIBarButtonItem *d=[self button:@"撤销" selector:@selector(undo)]; UIBarButtonItem *e=[self button:@"收起键盘" selector:@selector(dismiss)]; UIBarButtonItem *s=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]; _toolbar.items=@[a,s,b,s,c,s,d,s,e]; return _toolbar; }
@end

static void KTAttach(id obj) {
    if (!KTEnabled()) return;
    if(![obj isKindOfClass:UITextField.class] && ![obj isKindOfClass:UITextView.class]) return;
    UIView *v=(UIView *)obj;
    if(obj_getAssociatedObject(v,KTControllerKey)) return;
    if(v.inputAccessoryView) return;
    KTKeyboardController *c=[[KTKeyboardController alloc] initWithInput:obj];
    obj_setAssociatedObject(v,KTControllerKey,c,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    v.inputAccessoryView=[c makeToolbar];
}

%hook UITextField
- (BOOL)becomeFirstResponder { BOOL r=%orig; if(r) dispatch_async(dispatch_get_main_queue(),^{ KTAttach(self); [self reloadInputViews]; }); return r; }
%end

%hook UITextView
- (BOOL)becomeFirstResponder { BOOL r=%orig; if(r) dispatch_async(dispatch_get_main_queue(),^{ KTAttach(self); [self reloadInputViews]; }); return r; }
%end

%ctor { @autoreleasepool { [[KTClipboardManager sharedManager] startMonitoring]; } }
