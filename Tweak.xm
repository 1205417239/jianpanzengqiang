#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "KTClipboardViewController.h"

static NSInteger const KTTag=9999;
static CGFloat const KTWidth=240.0;
static CGFloat const KTHeight=36.0;

@interface UIKeyboardImpl : NSObject
+ (instancetype)activeInstance;
- (void)dismissKeyboard;
@end

static UIView *KTFR(UIView *v){
    if(v.isFirstResponder)return v;
    for(UIView *s in v.subviews){
        UIView *r=KTFR(s);
        if(r)return r;
    }
    return nil;
}

static id<UITextInput> KTInput(void){
    UIApplication *a=UIApplication.sharedApplication;
    if(@available(iOS 13.0,*)){
        for(UIScene *s in a.connectedScenes){
            if(![s isKindOfClass:UIWindowScene.class])continue;
            UIWindowScene *ws=(UIWindowScene *)s;
            if(ws.activationState!=UISceneActivationStateForegroundActive &&
               ws.activationState!=UISceneActivationStateForegroundInactive)continue;
            for(UIWindow *w in ws.windows){
                if(w.hidden||w.alpha<.01)continue;
                UIView *r=KTFR(w);
                if([r conformsToProtocol:@protocol(UITextInput)])
                    return (id<UITextInput>)r;
            }
        }
    }
    return nil;
}

static UIViewController *KTTop(UIViewController *v){
    if(v.presentedViewController)return KTTop(v.presentedViewController);
    if([v isKindOfClass:UINavigationController.class])
        return KTTop(((UINavigationController *)v).visibleViewController);
    if([v isKindOfClass:UITabBarController.class])
        return KTTop(((UITabBarController *)v).selectedViewController);
    return v;
}

static UIViewController *KTVC(void){
    UIApplication *a=UIApplication.sharedApplication;
    if(@available(iOS 13.0,*)){
        for(UIScene *s in a.connectedScenes){
            if(![s isKindOfClass:UIWindowScene.class])continue;
            UIWindowScene *ws=(UIWindowScene *)s;
            if(ws.activationState!=UISceneActivationStateForegroundActive &&
               ws.activationState!=UISceneActivationStateForegroundInactive)continue;
            for(UIWindow *w in ws.windows){
                if(w.hidden||w.alpha<.01||!w.rootViewController)continue;
                NSString *n=NSStringFromClass(w.class);
                if([n rangeOfString:@"Keyboard"].location!=NSNotFound)continue;
                return KTTop(w.rootViewController);
            }
        }
    }
    return nil;
}

static void Haptic(void){
    if(@available(iOS 10.0,*)){
        UIImpactFeedbackGenerator *g=
        [[UIImpactFeedbackGenerator alloc]initWithStyle:UIImpactFeedbackStyleLight];
        [g impactOccurred];
    }
}

static void Clipboard(id self,SEL _cmd,UIButton *b){
    Haptic();
    id<UITextInput> input=KTInput();
    UIViewController *vc=KTVC();
    if(!input||!vc)return;

    KTClipboardViewController *c=
    [[KTClipboardViewController alloc]initWithInput:input];
    c.modalPresentationStyle=UIModalPresentationPageSheet;
    [vc presentViewController:c animated:YES completion:nil];
}

static void SelectAll(id s,SEL c,UIButton *b){
    Haptic();
    [UIApplication.sharedApplication sendAction:@selector(selectAll:)
        to:nil from:nil forEvent:nil];
}

static void Paste(id s,SEL c,UIButton *b){
    Haptic();
    [UIApplication.sharedApplication sendAction:@selector(paste:)
        to:nil from:nil forEvent:nil];
}

static void Undo(id s,SEL c,UIButton *b){
    Haptic();
    [UIApplication.sharedApplication sendAction:@selector(undo:)
        to:nil from:nil forEvent:nil];
}

static void Dismiss(id s,SEL c,UIButton *b){
    Haptic();
    Class k=objc_getClass("UIKeyboardImpl");
    id x=k?[k activeInstance]:nil;
    if([x respondsToSelector:@selector(dismissKeyboard)])
        [x dismissKeyboard];
}

static void Install(Class c){
    if(!c)return;
    class_addMethod(c,@selector(didTapClipboard:),(IMP)Clipboard,"v@:@");
    class_addMethod(c,@selector(didTapSelectAll:),(IMP)SelectAll,"v@:@");
    class_addMethod(c,@selector(didTapPaste:),(IMP)Paste,"v@:@");
    class_addMethod(c,@selector(didTapUndo:),(IMP)Undo,"v@:@");
    class_addMethod(c,@selector(didTapDismiss:),(IMP)Dismiss,"v@:@");
}

static void AddButton(UIStackView *s,UIView *dock,NSString *icon,
                      NSString *label,SEL action){
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
    if(@available(iOS 13.0,*))
        [b setImage:[UIImage systemImageNamed:icon]
           forState:UIControlStateNormal];
    b.accessibilityLabel=label;
    [b addTarget:dock action:action
 forControlEvents:UIControlEventTouchUpInside];
    [s addArrangedSubview:b];
    [b.widthAnchor constraintEqualToConstant:48].active=YES;
    [b.heightAnchor constraintEqualToConstant:KTHeight].active=YES;
}

%hook UIKeyboardDockView

- (void)layoutSubviews{
    %orig;

    UIView *dock=(UIView *)self;
    if(!dock||[dock viewWithTag:KTTag])return;

    UIStackView *s=[[UIStackView alloc]initWithFrame:CGRectZero];
    s.tag=KTTag;
    s.axis=UILayoutConstraintAxisHorizontal;
    s.distribution=UIStackViewDistributionFillEqually;
    s.alignment=UIStackViewAlignmentCenter;
    s.translatesAutoresizingMaskIntoConstraints=NO;
    [dock addSubview:s];

    AddButton(s,dock,@"doc.on.clipboard",@"剪贴板",
              @selector(didTapClipboard:));
    AddButton(s,dock,@"selection.pin.in.out",@"全选",
              @selector(didTapSelectAll:));
    AddButton(s,dock,@"doc.on.clipboard",@"粘贴",
              @selector(didTapPaste:));
    AddButton(s,dock,@"arrow.uturn.backward",@"撤销",
              @selector(didTapUndo:));
    AddButton(s,dock,@"keyboard.chevron.compact.down",@"收起键盘",
              @selector(didTapDismiss:));

    [s.widthAnchor constraintEqualToConstant:KTWidth].active=YES;
    [s.heightAnchor constraintEqualToConstant:KTHeight].active=YES;
    [s.centerXAnchor constraintEqualToAnchor:dock.centerXAnchor].active=YES;
    [s.bottomAnchor constraintEqualToAnchor:dock.bottomAnchor
                                    constant:-23].active=YES;
}

%end

%ctor{
    @autoreleasepool{
        Install(objc_getClass("UIKeyboardDockView"));
    }
}
