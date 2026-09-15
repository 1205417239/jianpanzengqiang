#import "KTClipboardViewController.h"
#import "KTClipboardManager.h"
#import "KTSettings.h"
#import <UIKit/UIKit.h>

@interface KTClipboardViewController () <UITableViewDelegate, UITableViewDataSource>
@property(nonatomic,strong) id<UITextInput> input;
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UISegmentedControl *segment;
@property(nonatomic,strong) UITableView *table;
@property(nonatomic,strong) NSArray *items;
@property(nonatomic,strong) UIView *grabber;
@property(nonatomic,assign) CGFloat dragStartHeight;
@end

@implementation KTClipboardViewController

- (instancetype)initWithInput:(id<UITextInput>)input {
    self = [super initWithNibName:nil bundle:nil];
    if (self) _input = input;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;

    self.panel = [UIView new];
    self.panel.backgroundColor = UIColor.systemBackgroundColor;
    self.panel.layer.cornerRadius = 20.0;
    self.panel.layer.masksToBounds = YES;
    [self.view addSubview:self.panel];

    self.grabber = [UIView new];
    self.grabber.backgroundColor = UIColor.secondaryLabelColor;
    self.grabber.layer.cornerRadius = 3.0;
    [self.panel addSubview:self.grabber];
    self.grabber.userInteractionEnabled = YES;
    [self.grabber addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]];

    UIView *top = [UIView new];
    [self.panel addSubview:top];

    UIButton *clearImage = [UIButton buttonWithType:UIButtonTypeSystem];
    [clearImage setTitle:@"清除图片" forState:UIControlStateNormal];
    clearImage.titleLabel.font = [UIFont systemFontOfSize:20.0];
    [clearImage setImage:[UIImage systemImageNamed:@"photo.on.rectangle"] forState:UIControlStateNormal];
    clearImage.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [clearImage addTarget:self action:@selector(clearImages) forControlEvents:UIControlEventTouchUpInside];
    [top addSubview:clearImage];

    UIButton *clear = [UIButton buttonWithType:UIButtonTypeSystem];
    [clear setTitle:@"清除剪贴板" forState:UIControlStateNormal];
    clear.titleLabel.font = [UIFont systemFontOfSize:20.0];
    [clear setImage:[UIImage systemImageNamed:@"trash"] forState:UIControlStateNormal];
    clear.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [clear setTitleColor:UIColor.systemRedColor forState:UIControlStateNormal];
    clear.tintColor = UIColor.systemRedColor;
    [clear addTarget:self action:@selector(clearHistory) forControlEvents:UIControlEventTouchUpInside];
    [top addSubview:clear];

    UIView *line = [UIView new];
    line.backgroundColor = UIColor.separatorColor;
    [top addSubview:line];

    self.segment = [[UISegmentedControl alloc] initWithItems:@[@"剪贴板", @"收藏夹"]];
    self.segment.selectedSegmentIndex = 0;
    [self.segment addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    [self.panel addSubview:self.segment];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.delegate = self;
    self.table.dataSource = self;
    self.table.separatorColor = UIColor.separatorColor;
    [self.panel addSubview:self.table];

    self.grabber.frame = CGRectMake(0.0, 7.0, 42.0, 6.0);
    self.grabber.center = CGPointMake(CGRectGetMidX(self.panel.bounds), 10.0);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self layoutPanel];
    [self reload];
    CGRect target = self.panel.frame;
    CGFloat h = CGRectGetHeight(self.view.bounds);
    self.panel.frame = CGRectMake(0.0, h, CGRectGetWidth(self.view.bounds), 468.0);
    [UIView animateWithDuration:0.22 animations:^{
        self.panel.frame = target;
    }];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.panel.frame.size.height <= 0.0) [self layoutPanel];
}

- (void)layoutPanel {
    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);
    if (width <= 0.0 || height <= 0.0) return;
    CGFloat panelHeight = 468.0;
    self.panel.frame = CGRectMake(0.0, height - panelHeight, width, panelHeight);

    self.grabber.frame = CGRectMake((width - 42.0) / 2.0, 7.0, 42.0, 6.0);

    CGFloat topY = 0.0;
    CGFloat topH = 96.0;
    UIView *top = self.panel.subviews.count > 1 ? self.panel.subviews[1] : nil;
    if (top) {
        top.frame = CGRectMake(0.0, topY, width, topH);
        NSArray *buttons = [top.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UIView *obj, NSDictionary *bindings) { return [obj isKindOfClass:UIButton.class]; }]];
        UIButton *clearImage = buttons.count > 0 ? buttons[0] : nil;
        UIButton *clear = buttons.count > 1 ? buttons[1] : nil;
        UIView *line = nil;
        for (UIView *v in top.subviews) if (![v isKindOfClass:UIButton.class]) line = v;
        if (clearImage) clearImage.frame = CGRectMake(28.0, 8.0, width - 56.0, 42.0);
        if (line) line.frame = CGRectMake(0.0, 50.0, width, 0.5);
        if (clear) clear.frame = CGRectMake(28.0, 50.5, width - 56.0, 42.0);
    }

    self.segment.frame = CGRectMake((width - 260.0) / 2.0, 106.0, 260.0, 40.0);
    self.table.frame = CGRectMake(0.0, 158.0, width, MAX(0.0, panelHeight - 158.0));
}

- (void)reload {
    self.items = self.segment.selectedSegmentIndex == 1 ? KTClipboardManager.sharedManager.favorites : KTClipboardManager.sharedManager.items;
    [self.table reloadData];
}

- (void)segmentChanged:(UISegmentedControl *)sender { [self reload]; }
- (void)clearImages { [KTClipboardManager.sharedManager clearImages]; }
- (void)clearHistory { [KTClipboardManager.sharedManager clearClipboardHistory]; [self reload]; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.items.count; }
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath { return 92.0; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= self.items.count) return [UITableViewCell new];
    KTClipboardItem *item = self.items[indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"clip"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"clip"];
    cell.textLabel.font = [UIFont systemFontOfSize:20.0];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:16.0];
    cell.detailTextLabel.numberOfLines = 1;
    if (KTShowSource()) {
        cell.textLabel.text = item.appName.length ? item.appName : @"未知应用";
        cell.detailTextLabel.text = item.text ?: @"";
    } else {
        cell.textLabel.text = item.text ?: @"";
        cell.detailTextLabel.text = @"";
    }
    cell.accessoryType = item.favorite ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.imageView.image = [UIImage systemImageNamed:@"doc.on.clipboard"];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= self.items.count) return;
    KTClipboardItem *item = self.items[indexPath.row];
    if (item.text.length && self.input) [KTClipboardManager.sharedManager pasteItem:item intoInput:self.input];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self closePage];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete || indexPath.row >= self.items.count) return;
    [KTClipboardManager.sharedManager removeItem:self.items[indexPath.row]];
    [self reload];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIWindow *window = self.view.window;
    if (!window) return;
    CGFloat screenWidth = CGRectGetWidth(self.view.bounds);
    CGFloat screenHeight = CGRectGetHeight(self.view.bounds);
    const CGFloat minHeight = 468.0;
    const CGFloat maxHeight = 800.0;
    CGPoint translation = [pan translationInView:self.view];
    CGPoint velocity = [pan velocityInView:self.view];

    if (pan.state == UIGestureRecognizerStateBegan) {
        self.dragStartHeight = CGRectGetHeight(self.panel.frame);
        return;
    }

    if (pan.state == UIGestureRecognizerStateChanged) {
        CGFloat height = MAX(minHeight, MIN(maxHeight, self.dragStartHeight - translation.y));
        self.panel.frame = CGRectMake(0.0, screenHeight - height, screenWidth, height);
        self.table.frame = CGRectMake(0.0, 158.0, screenWidth, MAX(0.0, height - 158.0));
        return;
    }

    if (pan.state != UIGestureRecognizerStateEnded && pan.state != UIGestureRecognizerStateCancelled) return;
    if (translation.y > 90.0 || velocity.y > 900.0) {
        [self closePage];
        return;
    }

    CGFloat currentHeight = CGRectGetHeight(self.panel.frame);
    CGFloat targetHeight = (translation.y < -70.0 || velocity.y < -700.0 || currentHeight > minHeight + 20.0) ? maxHeight : minHeight;
    CGRect target = CGRectMake(0.0, screenHeight - targetHeight, screenWidth, targetHeight);
    [UIView animateWithDuration:0.20 animations:^{
        self.panel.frame = target;
        self.table.frame = CGRectMake(0.0, 158.0, screenWidth, targetHeight - 158.0);
    }];
}

- (void)closePage {
    if (self.closeHandler) self.closeHandler();
}

@end
