#import <UIKit/UIKit.h>
#import "KTDebugLogger.h"

@interface KTDebugViewController : UIViewController
@end

@implementation KTDebugViewController
- (void)loadView {
    UITextView *v = [[UITextView alloc] initWithFrame:CGRectZero];
    v.editable = NO;
    v.selectable = YES;
    v.font = [UIFont monospacedSystemFontOfSize:12.0 weight:UIFontWeightRegular];
    v.text = KTDebugLogText();
    v.backgroundColor = UIColor.systemBackgroundColor;
    self.view = v;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"调试日志";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"清空" style:UIBarButtonItemStylePlain target:self action:@selector(clearLog)];
}
- (void)clearLog {
    KTDebugLogClear();
    ((UITextView *)self.view).text = @"暂无调试记录";
}
@end
