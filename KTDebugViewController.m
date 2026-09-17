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
    self.view=table;
    UITextView *v=[[UITextView alloc] initWithFrame:table.bounds];
    v.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    v.editable=NO;
    v.selectable=YES;
    v.font=[UIFont monospacedSystemFontOfSize:12.0 weight:UIFontWeightRegular];
    v.backgroundColor=UIColor.systemBackgroundColor;
    v.textColor=UIColor.labelColor;
    v.textContainerInset=UIEdgeInsetsMake(12,12,12,12);
    [table addSubview:v];
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
    self.logView.selectedRange=NSMakeRange(0,0);
    [self.logView setContentOffset:CGPointZero animated:NO];
}
- (void)clearLog {
    KTDebugLogClear();
    self.logView.text=@"暂无插件运行记录";
    [self.logView setContentOffset:CGPointZero animated:NO];
}
@end
