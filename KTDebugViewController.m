#import <UIKit/UIKit.h>
#import "KTDebugLogger.h"

@interface KTDebugViewController : UIViewController
@property(nonatomic,strong) UITextView *textView;
@end

@implementation KTDebugViewController
- (void)loadView {
    self.view=[UIView new];
    self.view.backgroundColor=UIColor.systemBackgroundColor;
    self.textView=[[UITextView alloc] initWithFrame:CGRectZero];
    self.textView.editable=NO;
    self.textView.selectable=YES;
    self.textView.font=[UIFont monospacedSystemFontOfSize:12.0 weight:UIFontWeightRegular];
    self.textView.textColor=UIColor.labelColor;
    self.textView.backgroundColor=UIColor.systemBackgroundColor;
    [self.view addSubview:self.textView];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title=@"调试日志";
    UIBarButtonItem *clear=[[UIBarButtonItem alloc] initWithTitle:@"清空" style:UIBarButtonItemStylePlain target:self action:@selector(clearLog)];
    UIBarButtonItem *refresh=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshLog)];
    self.navigationItem.rightBarButtonItems=@[clear,refresh];
    [self refreshLog];
}
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; self.textView.frame=self.view.bounds; }
- (void)refreshLog { self.textView.text=KTDebugLogText(); [self.textView setContentOffset:CGPointZero animated:NO]; }
- (void)clearLog {
    [@"" writeToFile:@"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.debug.log" atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self refreshLog];
}
@end
