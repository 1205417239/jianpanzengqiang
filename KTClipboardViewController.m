#import "KTClipboardViewController.h"
#import "KTClipboardManager.h"

@interface KTClipboardCell : UITableViewCell
@end
@implementation KTClipboardCell @end

@interface KTClipboardViewController () <UITableViewDelegate,UITableViewDataSource>
@property(nonatomic,weak) id<UITextInput> input;
@property(nonatomic,strong) UISegmentedControl *segment;
@property(nonatomic,strong) UITableView *table;
@property(nonatomic,strong) NSArray *items;
@property(nonatomic,assign) BOOL favoritesMode;
@end

@implementation KTClipboardViewController
- (instancetype)initWithInput:(id<UITextInput>)input { if ((self=[super init])) _input=input; return self; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=UIColor.systemBackgroundColor;
    UIView *top=[UIView new]; top.translatesAutoresizingMaskIntoConstraints=NO; [self.view addSubview:top];
    UIButton *clearImage=[UIButton buttonWithType:UIButtonTypeSystem]; [clearImage setTitle:@"清除图片" forState:UIControlStateNormal]; clearImage.titleLabel.font=[UIFont systemFontOfSize:22]; [clearImage setImage:[UIImage systemImageNamed:@"photo.on.rectangle"] forState:UIControlStateNormal]; clearImage.semanticContentAttribute=UISemanticContentAttributeForceRightToLeft; clearImage.tintColor=UIColor.labelColor; [clearImage addTarget:self action:@selector(clearImages) forControlEvents:UIControlEventTouchUpInside]; clearImage.translatesAutoresizingMaskIntoConstraints=NO; [top addSubview:clearImage];
    UIButton *clear=[UIButton buttonWithType:UIButtonTypeSystem]; [clear setTitle:@"清除剪贴板" forState:UIControlStateNormal]; clear.titleLabel.font=[UIFont systemFontOfSize:22]; [clear setImage:[UIImage systemImageNamed:@"trash"] forState:UIControlStateNormal]; clear.semanticContentAttribute=UISemanticContentAttributeForceRightToLeft; clear.tintColor=UIColor.systemRedColor; [clear setTitleColor:UIColor.systemRedColor forState:UIControlStateNormal]; [clear addTarget:self action:@selector(clearHistory) forControlEvents:UIControlEventTouchUpInside]; clear.translatesAutoresizingMaskIntoConstraints=NO; [top addSubview:clear];
    UIView *line=[UIView new]; line.backgroundColor=UIColor.separatorColor; line.translatesAutoresizingMaskIntoConstraints=NO; [top addSubview:line];
    self.segment=[[UISegmentedControl alloc] initWithItems:@[@"剪贴板",@"收藏夹"]]; self.segment.selectedSegmentIndex=0; [self.segment addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged]; self.segment.translatesAutoresizingMaskIntoConstraints=NO; [self.view addSubview:self.segment];
    self.table=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain]; self.table.delegate=self; self.table.dataSource=self; self.table.separatorColor=UIColor.separatorColor; self.table.translatesAutoresizingMaskIntoConstraints=NO; [self.view addSubview:self.table];
    UIButton *menu=[UIButton buttonWithType:UIButtonTypeSystem]; [menu setImage:[UIImage systemImageNamed:@"line.3.horizontal"] forState:UIControlStateNormal]; menu.tintColor=UIColor.labelColor; menu.translatesAutoresizingMaskIntoConstraints=NO; [self.view addSubview:menu];
    [NSLayoutConstraint activateConstraints:@[
        [top.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],[top.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[top.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],[top.heightAnchor constraintEqualToConstant:112],
        [clearImage.leadingAnchor constraintEqualToAnchor:top.leadingAnchor constant:28],[clearImage.trailingAnchor constraintEqualToAnchor:top.trailingAnchor constant:-28],[clearImage.topAnchor constraintEqualToAnchor:top.topAnchor constant:10],[clearImage.heightAnchor constraintEqualToConstant:48],
        [line.leadingAnchor constraintEqualToAnchor:top.leadingAnchor],[line.trailingAnchor constraintEqualToAnchor:top.trailingAnchor],[line.topAnchor constraintEqualToAnchor:clearImage.bottomAnchor],[line.heightAnchor constraintEqualToConstant:.5],
        [clear.leadingAnchor constraintEqualToAnchor:top.leadingAnchor constant:28],[clear.trailingAnchor constraintEqualToAnchor:top.trailingAnchor constant:-28],[clear.topAnchor constraintEqualToAnchor:line.bottomAnchor],[clear.heightAnchor constraintEqualToConstant:48],
        [menu.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:28],[menu.topAnchor constraintEqualToAnchor:top.bottomAnchor constant:16],[menu.widthAnchor constraintEqualToConstant:56],[menu.heightAnchor constraintEqualToConstant:48],
        [self.segment.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],[self.segment.topAnchor constraintEqualToAnchor:top.bottomAnchor constant:12],[self.segment.widthAnchor constraintEqualToConstant:310],[self.segment.heightAnchor constraintEqualToConstant:52],
        [self.table.topAnchor constraintEqualToAnchor:self.segment.bottomAnchor constant:18],[self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],[self.table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    [self reload];
}
- (void)reload { self.items=self.favoritesMode ? [KTClipboardManager.sharedManager favorites] : [KTClipboardManager.sharedManager items]; [self.table reloadData]; }
- (void)segmentChanged:(UISegmentedControl *)s { self.favoritesMode=(s.selectedSegmentIndex==1); [self reload]; }
- (void)clearImages { [KTClipboardManager.sharedManager clearImages]; }
- (void)clearHistory { [KTClipboardManager.sharedManager clearClipboardHistory]; [self reload]; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.items.count; }
- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)p { return 92; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {
    KTClipboardItem *item=self.items[p.row];
    KTClipboardCell *c=[t dequeueReusableCellWithIdentifier:@"clip"]; if(!c) c=[[KTClipboardCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"clip"];
    BOOL showSource = YES; NSNumber *sv=[[NSUserDefaults standardUserDefaults] objectForKey:@"ShowSource"]; if(sv) showSource=sv.boolValue; c.textLabel.text=showSource?(item.appName.length?item.appName:@"未知应用"):item.text; c.textLabel.font=[UIFont systemFontOfSize:21 weight:UIFontWeightRegular]; c.detailTextLabel.text=showSource?item.text:@""; c.detailTextLabel.font=[UIFont systemFontOfSize:17]; c.detailTextLabel.numberOfLines=1; c.accessoryType=item.favorite?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;
    UIImage *icon=nil; if(item.bundleIdentifier.length) { icon=[[UIApplication sharedApplication] _applicationIconImageForBundleIdentifier:item.bundleIdentifier format:0 scale:UIScreen.mainScreen.scale]; }
    c.imageView.image=icon ?: [UIImage systemImageNamed:@"doc.on.clipboard"]; return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p { KTClipboardItem *i=self.items[p.row]; [KTClipboardManager.sharedManager pasteItem:i intoInput:self.input]; [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)tableView:(UITableView *)t commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)p { if(style==UITableViewCellEditingStyleDelete){ [KTClipboardManager.sharedManager removeItem:self.items[p.row]]; [self reload]; } }
@end
