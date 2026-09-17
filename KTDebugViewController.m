#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import "KTDebugLogger.h"

@interface KTDebugViewController : PSListController
@property(nonatomic,strong) UITextView *logView;
@end

@implementation KTDebugViewController
- (NSArray *)specifiers { return @[]; }
- (void)loadView {
    [super loadView];
    UITableView *table=(UITableView *)self.view;
    UITextView *v=[[UITextView alloc] initWithFrame:CGRectZero];
    v.editable=NO;
    v.selectable=YES;
    v.font=[UIFont monospacedSystemFontOfSize:12.0 weight:UIFontWeightRegular];
    v.text=KTDebugLogText();
    v.backgroundColor=UIColor.systemBackgroundColor;
    v.textColor=UIColor.labelColor;
    v.translatesAutoresizingMaskIntoConstraints=NO;
    [table addSubview:v];
    [NSLayoutConstraint activateConstraints:@[
        [v.topAnchor constraintEqualToAnchor:table.topAnchor],
        [v.leadingAnchor constraintEqualToAnchor:table.leadingAnchor],
        [v.trailingAnchor constraintEqualToAnchor:table.trailingAnchor],
        [v.bottomAnchor constraintEqualToAnchor:table.bottomAnchor]
    ]];
    self.logView=v;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title=@"插件运行日志";
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"清空" style:UIBarButtonItemStylePlain target:self action:@selector(clearLog)];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.logView.text=KTDebugLogText();
    [self.logView scrollRangeToVisible:NSMakeRange(self.logView.text.length,0)];
}
- (void)clearLog {
    KTDebugLogClear();
    self.logView.text=@"暂无插件运行记录";
}
@end
