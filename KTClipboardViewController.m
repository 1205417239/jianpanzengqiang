#import "KTClipboardViewController.h"
#import "KTClipboardManager.h"
#import "KTSettings.h"
#import <UIKit/UIKit.h>

@interface KTClipboardCell : UITableViewCell
@property(nonatomic,strong) UILabel *numberLabel;
@property(nonatomic,strong) UILabel *contentLabel;
@property(nonatomic,strong) UILabel *sourceLabel;
@property(nonatomic,strong) UILabel *timeLabel;
@property(nonatomic,strong) UILabel *dateLabel;
@end

@implementation KTClipboardCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.whiteColor;
        self.contentView.layer.cornerRadius = 10.0;
        self.contentView.layer.masksToBounds = YES;

        _numberLabel = [UILabel new];
        _numberLabel.font = [UIFont monospacedDigitSystemFontOfSize:15.0 weight:UIFontWeightSemibold];
        _numberLabel.textAlignment = NSTextAlignmentCenter;
        _numberLabel.textColor = UIColor.secondaryLabelColor;
        [self.contentView addSubview:_numberLabel];

        _contentLabel = [UILabel new];
        _contentLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
        _contentLabel.textColor = UIColor.labelColor;
        _contentLabel.numberOfLines = 2;
        [self.contentView addSubview:_contentLabel];

        _sourceLabel = [UILabel new];
        _sourceLabel.font = [UIFont systemFontOfSize:12.0];
        _sourceLabel.textColor = UIColor.secondaryLabelColor;
        [self.contentView addSubview:_sourceLabel];

        _timeLabel = [UILabel new];
        _timeLabel.font = [UIFont monospacedDigitSystemFontOfSize:13.0 weight:UIFontWeightMedium];
        _timeLabel.textColor = UIColor.secondaryLabelColor;
        _timeLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_timeLabel];

        _dateLabel = [UILabel new];
        _dateLabel.font = [UIFont systemFontOfSize:11.0];
        _dateLabel.textColor = UIColor.tertiaryLabelColor;
        _dateLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_dateLabel];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = CGRectGetWidth(self.contentView.bounds);
    CGFloat h = CGRectGetHeight(self.contentView.bounds);
    self.numberLabel.frame = CGRectMake(8.0, 0.0, 28.0, h);
    self.timeLabel.frame = CGRectMake(w - 76.0, 18.0, 66.0, 20.0);
    self.dateLabel.frame = CGRectMake(w - 82.0, 41.0, 72.0, 18.0);
    CGFloat left = 44.0;
    CGFloat right = w - 92.0;
    self.contentLabel.frame = CGRectMake(left, 12.0, MAX(80.0, right - left), 42.0);
    self.sourceLabel.frame = CGRectMake(left, 56.0, MAX(80.0, right - left), 17.0);
}
@end

@interface KTClipboardViewController () <UITableViewDelegate, UITableViewDataSource>
@property(nonatomic,strong) id<UITextInput> input;
@property(nonatomic,strong) UIButton *menuButton;
@property(nonatomic,strong) UIButton *clipboardTab;
@property(nonatomic,strong) UIButton *favoriteTab;
@property(nonatomic,strong) UIView *tabIndicator;
@property(nonatomic,strong) UITableView *table;
@property(nonatomic,strong) NSArray *items;
@property(nonatomic,strong) UIView *grabber;
@property(nonatomic,strong) UIView *menuCard;
@property(nonatomic,assign) BOOL menuVisible;
@property(nonatomic,assign) NSInteger segmentIndex;
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
    self.panel.backgroundColor = [UIColor colorWithWhite:0.93 alpha:1.0];
    self.panel.layer.cornerRadius = 14.0;
    self.panel.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    self.panel.layer.masksToBounds = YES;
    [self.view addSubview:self.panel];

    self.grabber = [UIView new];
    self.grabber.backgroundColor = [UIColor colorWithWhite:0.60 alpha:1.0];
    self.grabber.layer.cornerRadius = 2.5;
    self.grabber.userInteractionEnabled = YES;
    [self.grabber addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]];
    [self.panel addSubview:self.grabber];

    self.menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.menuButton.tintColor = UIColor.labelColor;
    [self.menuButton setImage:[UIImage systemImageNamed:@"line.3.horizontal"] forState:UIControlStateNormal];
    self.menuButton.accessibilityLabel = @"菜单";
    [self.menuButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.menuButton];

    self.clipboardTab = [UIButton buttonWithType:UIButtonTypeSystem];
    self.favoriteTab = [UIButton buttonWithType:UIButtonTypeSystem];
    self.clipboardTab.selected = YES;
    self.favoriteTab.selected = NO;
    self.segmentIndex = 0;
    [self.clipboardTab setTitle:@"剪贴板" forState:UIControlStateNormal];
    [self.favoriteTab setTitle:@"收藏夹" forState:UIControlStateNormal];
    self.clipboardTab.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    self.favoriteTab.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
    [self.clipboardTab addTarget:self action:@selector(selectClipboard) forControlEvents:UIControlEventTouchUpInside];
    [self.favoriteTab addTarget:self action:@selector(selectFavorites) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.clipboardTab];
    [self.panel addSubview:self.favoriteTab];

    self.tabIndicator = [UIView new];
    self.tabIndicator.backgroundColor = UIColor.labelColor;
    self.tabIndicator.layer.cornerRadius = 1.5;
    [self.panel addSubview:self.tabIndicator];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.delegate = self;
    self.table.dataSource = self;
    self.table.backgroundColor = UIColor.clearColor;
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.showsVerticalScrollIndicator = YES;
    self.table.contentInset = UIEdgeInsetsMake(4.0, 0.0, 12.0, 0.0);
    self.table.scrollIndicatorInsets = UIEdgeInsetsMake(4.0, 2.0, 12.0, 2.0);
    [self.panel addSubview:self.table];

    [self buildMenuCard];
}

- (void)buildMenuCard {
    self.menuCard = [UIView new];
    self.menuCard.backgroundColor = UIColor.systemBackgroundColor;
    self.menuCard.layer.cornerRadius = 13.0;
    self.menuCard.layer.shadowColor = UIColor.blackColor.CGColor;
    self.menuCard.layer.shadowOpacity = 0.12;
    self.menuCard.layer.shadowRadius = 10.0;
    self.menuCard.layer.shadowOffset = CGSizeMake(0.0, 3.0);
    self.menuCard.hidden = YES;
    [self.panel addSubview:self.menuCard];

    UIButton *clearHistory = [UIButton buttonWithType:UIButtonTypeSystem];
    clearHistory.tag = 1;
    clearHistory.tintColor = UIColor.systemRedColor;
    [clearHistory setImage:[UIImage systemImageNamed:@"trash"] forState:UIControlStateNormal];
    clearHistory.accessibilityLabel = @"清除剪贴板";
    [clearHistory addTarget:self action:@selector(menuAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.menuCard addSubview:clearHistory];

    UIButton *clearImages = [UIButton buttonWithType:UIButtonTypeSystem];
    clearImages.tag = 2;
    clearImages.tintColor = UIColor.systemBlueColor;
    [clearImages setImage:[UIImage systemImageNamed:@"photo.on.rectangle"] forState:UIControlStateNormal];
    clearImages.accessibilityLabel = @"清除照片";
    [clearImages addTarget:self action:@selector(menuAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.menuCard addSubview:clearImages];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self layoutPanel];
    [self reload];
    CGFloat h = CGRectGetHeight(self.view.bounds);
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGRect target = CGRectMake(0.0, h - 400.0, w, 400.0);
    self.panel.frame = CGRectMake(0.0, h, w, 400.0);
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

    const CGFloat panelHeight = 400.0;
    self.panel.frame = CGRectMake(0.0, height - panelHeight, width, panelHeight);
    self.grabber.frame = CGRectMake((width - 38.0) / 2.0, 7.0, 38.0, 5.0);
    self.menuButton.frame = CGRectMake(14.0, 20.0, 38.0, 38.0);

    CGFloat tabsWidth = MIN(220.0, width - 100.0);
    CGFloat tabsX = (width - tabsWidth) / 2.0;
    self.clipboardTab.frame = CGRectMake(tabsX, 20.0, tabsWidth / 2.0, 38.0);
    self.favoriteTab.frame = CGRectMake(tabsX + tabsWidth / 2.0, 20.0, tabsWidth / 2.0, 38.0);
    self.tabIndicator.frame = CGRectMake(tabsX + (self.segmentIndex * tabsWidth / 2.0) + 28.0, 55.0, tabsWidth / 2.0 - 56.0, 3.0);

    self.table.frame = CGRectMake(8.0, 66.0, width - 16.0, panelHeight - 66.0);
    self.menuCard.frame = CGRectMake(14.0, 60.0, 132.0, 54.0);
    NSArray *buttons = self.menuCard.subviews;
    if (buttons.count >= 2) {
        buttons[0].frame = CGRectMake(8.0, 7.0, 50.0, 40.0);
        buttons[1].frame = CGRectMake(74.0, 7.0, 50.0, 40.0);
    }
}

- (void)updateTabAppearanceAnimated:(BOOL)animated {
    BOOL favorites = self.favoriteTab.selected;
    self.clipboardTab.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:favorites ? UIFontWeightRegular : UIFontWeightSemibold];
    self.favoriteTab.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:favorites ? UIFontWeightSemibold : UIFontWeightRegular];
    CGFloat width = CGRectGetWidth(self.panel.bounds);
    CGFloat tabsWidth = MIN(220.0, width - 100.0);
    CGFloat tabsX = (width - tabsWidth) / 2.0;
    CGRect target = CGRectMake(tabsX + (favorites ? tabsWidth / 2.0 : 0.0) + 28.0, 55.0, tabsWidth / 2.0 - 56.0, 3.0);
    if (animated) {
        [UIView animateWithDuration:0.18 animations:^{ self.tabIndicator.frame = target; }];
    } else self.tabIndicator.frame = target;
}

- (void)selectClipboard {
    self.clipboardTab.selected = YES;
    self.favoriteTab.selected = NO;
    self.segmentIndex = 0;
    [self updateTabAppearanceAnimated:YES];
    [self reload];
}

- (void)selectFavorites {
    self.clipboardTab.selected = NO;
    self.favoriteTab.selected = YES;
    self.segmentIndex = 1;
    [self updateTabAppearanceAnimated:YES];
    [self reload];
}

- (void)reload {
    self.items = self.favoriteTab.selected ? KTClipboardManager.sharedManager.favorites : KTClipboardManager.sharedManager.items;
    [self.table reloadData];
}

- (void)toggleMenu {
    self.menuVisible = !self.menuVisible;
    self.menuCard.hidden = NO;
    self.menuCard.alpha = self.menuVisible ? 0.0 : 1.0;
    [UIView animateWithDuration:0.16 animations:^{ self.menuCard.alpha = self.menuVisible ? 1.0 : 0.0; } completion:^(BOOL finished) {
        if (!self.menuVisible) self.menuCard.hidden = YES;
    }];
}

- (void)menuAction:(UIButton *)sender {
    if (sender.tag == 1) {
        [KTClipboardManager.sharedManager clearClipboardHistory];
        [self reload];
    } else if (sender.tag == 2) {
        [KTClipboardManager.sharedManager clearImages];
    }
    self.menuVisible = NO;
    self.menuCard.hidden = YES;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.items.count; }
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath { return 80.0; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= self.items.count) return [UITableViewCell new];
    KTClipboardItem *item = self.items[indexPath.row];
    KTClipboardCell *cell = [tableView dequeueReusableCellWithIdentifier:@"clip2"];
    if (!cell) cell = [[KTClipboardCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"clip2"];

    cell.numberLabel.text = [NSString stringWithFormat:@"%ld", (long)indexPath.row + 1];
    cell.contentLabel.text = item.text ?: @"";
    cell.sourceLabel.text = KTShowSource() ? (item.appName.length ? item.appName : @"未知应用") : @"";
    NSDate *date = item.recordedAt ?: NSDate.date;
    NSDateFormatter *timeFormatter = [NSDateFormatter new];
    timeFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    timeFormatter.dateFormat = @"HH:mm";
    cell.timeLabel.text = [timeFormatter stringFromDate:date];
    NSDateFormatter *dayFormatter = [NSDateFormatter new];
    dayFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    dayFormatter.dateFormat = @"M月d日";
    NSDate *now = NSDate.date;
    NSCalendar *calendar = [NSCalendar currentCalendar];
    BOOL today = [calendar isDate:date inSameDayAsDate:now];
    cell.dateLabel.text = today ? @"" : [dayFormatter stringFromDate:date];
    cell.backgroundColor = UIColor.clearColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= self.items.count) return;
    KTClipboardItem *item = self.items[indexPath.row];
    if (item.text.length && self.input) [KTClipboardManager.sharedManager pasteItem:item intoInput:self.input];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self closePage];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= self.items.count) return nil;
    KTClipboardItem *item = self.items[indexPath.row];

    UIContextualAction *delete = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"" handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [KTClipboardManager.sharedManager removeItem:item];
        [self reload];
        completionHandler(YES);
    }];
    delete.image = [UIImage systemImageNamed:@"trash"];

    UIContextualAction *favorite = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"" handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [KTClipboardManager.sharedManager setFavorite:!item.favorite forItem:item];
        [self reload];
        completionHandler(YES);
    }];
    favorite.backgroundColor = UIColor.systemBlueColor;
    favorite.image = [UIImage systemImageNamed:item.favorite ? @"star.slash" : @"star"];
    return [UISwipeActionsConfiguration configurationWithActions:@[delete, favorite]];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (pan.state != UIGestureRecognizerStateEnded) return;
    CGPoint translation = [pan translationInView:self.view];
    CGPoint velocity = [pan velocityInView:self.view];
    if (translation.y > 18.0 || velocity.y > 500.0) [self closePage];
}

- (void)closePage {
    if (self.closeHandler) self.closeHandler();
}

@end
