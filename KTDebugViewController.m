#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import "KTDebugLogger.h"

@interface KTDebugViewController : PSListController
@property(nonatomic,strong) UITextView *logView;
@end

@implementation KTDebugViewController
- (NSArray *)specifiers { return @[]; }
- (void)loadView {
    UITableView *table=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
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
    self.view=table;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title=@"调试日志";
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"清空" style:UIBarButtonItemStylePlain target:self action:@selector(clearLog)];
}
- (void)clearLog { KTDebugLogClear(); self.logView.text=@"暂无调试记录"; }
@end
