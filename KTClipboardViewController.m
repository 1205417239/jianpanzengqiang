#import "KTClipboardViewController.h"
#import "KTClipboardManager.h"
#import "KTSettings.h"
#import <UIKit/UIKit.h>

@interface KTClipboardCell : UITableViewCell
@property(nonatomic,strong) UILabel *numberLabel;
@property(nonatomic,strong) UILabel *timeLabel;
@property(nonatomic,strong) UILabel *dateLabel;
@end

@implementation KTClipboardCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        _numberLabel = [UILabel new];
        _numberLabel.font = [UIFont monospacedDigitSystemFontOfSize:16.0 weight:UIFontWeightMedium];
        _numberLabel.textColor = UIColor.secondaryLabelColor;
        _numberLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:_numberLabel];

        _timeLabel = [UILabel new];
        _timeLabel.font = [UIFont monospacedDigitSystemFontOfSize:15.0 weight:UIFontWeightRegular];
        _timeLabel.textColor = UIColor.secondaryLabelColor;
        _timeLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_timeLabel];

        _dateLabel = [UILabel new];
        _dateLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightRegular];
        _dateLabel.textColor = UIColor.tertiaryLabelColor;
        _dateLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_dateLabel];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = CGRectGetHeight(self.contentView.bounds);
    self.numberLabel.frame = CGRectMake(10.0, 0.0, 34.0, h);
    CGFloat right = CGRectGetWidth(self.contentView.bounds) - 14.0;
    self.timeLabel.frame = CGRectMake(right - 62.0, 15.0, 62.0, 20.0);
    self.dateLabel.frame = CGRectMake(right - 76.0, 37.0, 76.0, 18.0);
    CGFloat textX = 52.0;
    CGFloat textRight = right - 88.0;
    self.textLabel.frame = CGRectMake(textX, 12.0, MAX(40.0, textRight - textX), h - 24.0);
    self.detailTextLabel.frame = CGRectMake(textX, 48.0, MAX(40.0, textRight - textX), 22.0);
}
@end

@interface KTClipboardViewController () <UITableViewDelegate, UITableViewDataSource>
@property(nonatomic,strong) id<UITextInput> input;
@property(nonatomic,strong) UISegmentedControl *segment;
@property(nonatomic,strong) UIButton *clipboardTab;
@property(nonatomic,strong) UIButton *favoriteTab;
@property(nonatomic,strong) UIView *tabIndicator;
@property(nonatomic,strong) UITableView *table;
@property(nonatomic,strong) NSArray *items;
@property(nonatomic,strong) UIView *grabber;
@property(nonatomic,strong) UIButton *menuButton;
@property(nonatomic,assign) CGFloat dragStartHeight;
@property(nonatomic,assign) BOOL dragging;
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
    self.panel.backgroundColor = [UIColor colorWithWhite:0.94 alpha:1.0];
    self.panel.layer.cornerRadius = 16.0;
    self.panel.layer.masksToBounds = YES;
    [self.view addSubview:self.panel];

    self.grabber = [UIView new];
    self.grabber.backgroundColor = UIColor.systemGray2Color;
    self.grabber.layer.cornerRadius = 3.0;
    [self.panel addSubview:self.grabber];
    self.grabber.userInteractionEnabled = YES;
    [self.grabber addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]];
    UIPanGestureRecognizer *panelPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    panelPan.cancelsTouchesInView = NO;
    [self.panel addGestureRecognizer:panelPan];

    self.clearHistoryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.clearHistoryButton setImage:[UIImage systemImageNamed:@"trash"] forState:UIControlStateNormal];
    self.clearHistoryButton.tintColor = UIColor.systemRedColor;
    self.clearHistoryButton.accessibilityLabel = @"清除剪贴板";
    self.clearHistoryButton.hidden = YES;
    self.clearHistoryButton.alpha = 0.0;
    self.clearHistoryButton.backgroundColor = UIColor.systemBackgroundColor;
    self.clearHistoryButton.layer.cornerRadius = 19.0;
    [self.clearHistoryButton addTarget:self action:@selector(clearHistory) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.clearHistoryButton];

    self.clearImagesButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.clearImagesButton setImage:[UIImage systemImageNamed:@"photo.on.rectangle"] forState:UIControlStateNormal];
    self.clearImagesButton.tintColor = UIColor.secondaryLabelColor;
    self.clearImagesButton.accessibilityLabel = @"清除图片";
    self.clearImagesButton.hidden = YES;
    self.clearImagesButton.alpha = 0.0;
    self.clearImagesButton.backgroundColor = UIColor.systemBackgroundColor;
    self.clearImagesButton.layer.cornerRadius = 19.0;
    [self.clearImagesButton addTarget:self action:@selector(clearImages) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.clearImagesButton];

    self.menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.menuButton setImage:[UIImage systemImageNamed:@"line.3.horizontal"] forState:UIControlStateNormal];
    self.menuButton.tintColor = UIColor.secondaryLabelColor;
    self.menuButton.accessibilityLabel = @"管理";
    [self.menuButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.menuButton];

    self.clipboardTab = [UIButton buttonWithType:UIButtonTypeSystem];
    self.favoriteTab = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.clipboardTab setTitle:@"剪贴板" forState:UIControlStateNormal];
    [self.favoriteTab setTitle:@"收藏夹" forState:UIControlStateNormal];
    for (UIButton *b in @[self.clipboardTab, self.favoriteTab]) {
        b.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
        b.layer.cornerRadius = 10.0;
        b.backgroundColor = UIColor.clearColor;
        [self.panel addSubview:b];
    }
    [self.clipboardTab setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    [self.favoriteTab setTitleColor:UIColor.secondaryLabelColor forState:UIControlStateNormal];
    [self.clipboardTab addTarget:self action:@selector(selectClipboardTab) forControlEvents:UIControlEventTouchUpInside];
    [self.favoriteTab addTarget:self action:@selector(selectFavoriteTab) forControlEvents:UIControlEventTouchUpInside];

    self.tabIndicator = [UIView new];
    self.tabIndicator.backgroundColor = UIColor.labelColor;
    self.tabIndicator.layer.cornerRadius = 1.5;
    [self.panel addSubview:self.tabIndicator];

    self.segment = [[UISegmentedControl alloc] initWithItems:@[@"剪贴板", @"收藏夹"]];
    self.segment.hidden = YES;
    self.segment.selectedSegmentIndex = 0;
    [self.segment addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    [self.panel addSubview:self.segment];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.delegate = self;
    self.table.dataSource = self;
    self.table.backgroundColor = UIColor.clearColor;
    self.table.separatorColor = [UIColor colorWithWhite:0.80 alpha:1.0];
    self.table.separatorInset = UIEdgeInsetsMake(0.0, 52.0, 0.0, 14.0);
    self.table.showsVerticalScrollIndicator = YES;
    self.table.alwaysBounceVertical = YES;
    self.table.contentInset = UIEdgeInsetsMake(4.0, 0.0, 12.0, 0.0);
    [self.panel addSubview:self.table];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self layoutPanel];
    [self reload];
    CGRect target = self.panel.frame;
    CGFloat h = CGRectGetHeight(self.view.bounds);
    self.panel.frame = CGRectMake(0.0, h, CGRectGetWidth(self.view.bounds), 420.0);
    [UIView animateWithDuration:0.22 animations:^{ self.panel.frame = target; }];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.panel.frame.size.height <= 0.0) [self layoutPanel];
}

- (void)layoutPanel {
    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);
    if (width <= 0.0 || height <= 0.0) return;
    CGFloat panelHeight = 420.0;
    self.panel.frame = CGRectMake(0.0, height - panelHeight, width, panelHeight);

    self.grabber.frame = CGRectMake((width - 38.0) / 2.0, 7.0, 38.0, 5.0);
    self.clearHistoryButton.frame = CGRectMake(12.0, 20.0, 38.0, 38.0);
    self.clearImagesButton.frame = CGRectMake(56.0, 20.0, 38.0, 38.0);
    self.menuButton.frame = CGRectMake(12.0, 62.0, 38.0, 38.0);

    CGFloat tabWidth = 78.0;
    CGFloat gap = 0.0;
    CGFloat tabsX = (width - tabWidth * 2.0 - gap) / 2.0;
    CGFloat tabsY = 18.0;
    self.clipboardTab.frame = CGRectMake(tabsX, tabsY, tabWidth, 40.0);
    self.favoriteTab.frame = CGRectMake(tabsX + tabWidth + gap, tabsY, tabWidth, 40.0);
    self.tabIndicator.frame = CGRectMake(tabsX + 22.0, 56.0, tabWidth - 44.0, 3.0);

    self.table.frame = CGRectMake(0.0, 68.0, width, panelHeight - 68.0);
}

- (void)clearHistory { [KTClipboardManager.sharedManager clearClipboardHistory]; [self reload]; }
- (void)clearImages { [KTClipboardManager.sharedManager clearImages]; }

- (void)toggleMenu {
    BOOL show = self.clearHistoryButton.hidden;
    if (show) {
        self.clearHistoryButton.hidden = NO;
        self.clearImagesButton.hidden = NO;
        [UIView animateWithDuration:0.16 animations:^{
            self.clearHistoryButton.alpha = 1.0;
            self.clearImagesButton.alpha = 1.0;
        }];
    } else {
        [UIView animateWithDuration:0.14 animations:^{
            self.clearHistoryButton.alpha = 0.0;
            self.clearImagesButton.alpha = 0.0;
        } completion:^(BOOL finished) {
            self.clearHistoryButton.hidden = YES;
            self.clearImagesButton.hidden = YES;
        }];
    }
}

- (void)reload {
    self.items = self.segment.selectedSegmentIndex == 1 ? KTClipboardManager.sharedManager.favorites : KTClipboardManager.sharedManager.items;
    [self.table reloadData];
}

- (void)selectClipboardTab {
    if (self.segment.selectedSegmentIndex == 0) return;
    self.segment.selectedSegmentIndex = 0;
    [self animateTab:YES];
    [self reload];
}

- (void)selectFavoriteTab {
    if (self.segment.selectedSegmentIndex == 1) return;
    self.segment.selectedSegmentIndex = 1;
    [self animateTab:NO];
    [self reload];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    [self animateTab:sender.selectedSegmentIndex == 0];
    [self reload];
}

- (void)animateTab:(BOOL)clipboard {
    CGFloat x = clipboard ? CGRectGetMinX(self.clipboardTab.frame) + 22.0 : CGRectGetMinX(self.favoriteTab.frame) + 22.0;
    [self.clipboardTab setTitleColor:clipboard ? UIColor.labelColor : UIColor.secondaryLabelColor forState:UIControlStateNormal];
    [self.favoriteTab setTitleColor:clipboard ? UIColor.secondaryLabelColor : UIColor.labelColor forState:UIControlStateNormal];
    [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.tabIndicator.frame = CGRectMake(x, 56.0, CGRectGetWidth(self.clipboardTab.frame) - 44.0, 3.0);
    } completion:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.items.count; }
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath { return 82.0; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= self.items.count) return [UITableViewCell new];
    KTClipboardItem *item = self.items[indexPath.row];
    KTClipboardCell *cell = [tableView dequeueReusableCellWithIdentifier:@"clip" ];
    if (!cell) cell = [[KTClipboardCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"clip"];
    cell.textLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:14.0];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.numberOfLines = 1;
    cell.numberLabel.text = [NSString stringWithFormat:@"%ld", (long)indexPath.row + 1];
    if (KTShowSource()) {
        cell.textLabel.text = item.appName.length ? item.appName : @"未知应用";
        cell.detailTextLabel.text = item.text ?: @"";
    } else {
        cell.textLabel.text = item.text ?: @"";
        cell.detailTextLabel.text = @"";
    }
    cell.timeLabel.text = @"";
    cell.dateLabel.text = @"";
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.imageView.image = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= self.items.count) return;
    KTClipboardItem *item = self.items[indexPath.row];
    if (item.text.length && self.input) [KTClipboardManager.sharedManager pasteItem:item intoInput:self.input];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self closePage];
}

- (NSArray<UIContextualAction *> *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= self.items.count) return @[];
    KTClipboardItem *item = self.items[indexPath.row];
    UIContextualAction *favorite = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"" handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        BOOL value = !item.favorite;
        [KTClipboardManager.sharedManager setFavorite:value forItem:item];
        completionHandler(YES);
        [self reload];
    }];
    favorite.image = [UIImage systemImageNamed:item.favorite ? @"star.slash" : @"star"];
    favorite.backgroundColor = UIColor.systemOrangeColor;

    UIContextualAction *delete = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"" handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [KTClipboardManager.sharedManager removeItem:item];
        completionHandler(YES);
        [self reload];
    }];
    delete.image = [UIImage systemImageNamed:@"trash"];
    return @[delete, favorite];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGFloat screenWidth = CGRectGetWidth(self.view.bounds);
    CGFloat screenHeight = CGRectGetHeight(self.view.bounds);
    const CGFloat baseHeight = 420.0;
    CGPoint translation = [pan translationInView:self.view];
    CGPoint velocity = [pan velocityInView:self.view];

    if (pan.state == UIGestureRecognizerStateBegan) {
        self.dragStartHeight = CGRectGetHeight(self.panel.frame);
        self.dragging = YES;
        return;
    }

    if (pan.state == UIGestureRecognizerStateChanged) {
        CGFloat height = self.dragStartHeight - translation.y;
        height = MAX(0.0, MIN(baseHeight, height));
        self.panel.frame = CGRectMake(0.0, screenHeight - height, screenWidth, height);
        self.table.frame = CGRectMake(0.0, 68.0, screenWidth, MAX(0.0, height - 68.0));
        return;
    }

    if (pan.state != UIGestureRecognizerStateEnded && pan.state != UIGestureRecognizerStateCancelled) return;
    self.dragging = NO;

    if (translation.y > 100.0 || velocity.y > 700.0) {
        [self closePage];
        return;
    }

    CGRect target = CGRectMake(0.0, screenHeight - baseHeight, screenWidth, baseHeight);
    [UIView animateWithDuration:0.32 delay:0.0 usingSpringWithDamping:0.88 initialSpringVelocity:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.panel.frame = target;
        self.table.frame = CGRectMake(0.0, 68.0, screenWidth, baseHeight - 68.0);
    } completion:nil];
}

- (void)closePage {
    if (self.closeHandler) self.closeHandler();
}

@end
