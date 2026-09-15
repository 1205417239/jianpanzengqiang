#import "KTClipboardViewController.h"
#import "KTClipboardManager.h"
#import "KTSettings.h"
#import <UIKit/UIKit.h>

@interface KTClipboardViewController () <UITableViewDelegate, UITableViewDataSource>

@property(nonatomic,weak) id<UITextInput> input;
@property(nonatomic,strong) UISegmentedControl *segment;
@property(nonatomic,strong) UITableView *table;
@property(nonatomic,strong) NSArray *items;
@property(nonatomic,strong) UIView *manageBar;
@property(nonatomic,strong) NSLayoutConstraint *manageHeight;
@property(nonatomic,assign) BOOL favoritesMode;
@property(nonatomic,assign) BOOL managing;

@end

@implementation KTClipboardViewController

- (instancetype)initWithInput:(id<UITextInput>)input {
    self = [super initWithNibName:nil bundle:nil];
    if (self) _input = input;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"剪贴板";
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    UIBarButtonItem *manage =
        [[UIBarButtonItem alloc]
            initWithTitle:@"管理"
                    style:UIBarButtonItemStylePlain
                   target:self
                   action:@selector(toggleManage)];

    self.navigationItem.rightBarButtonItem = manage;

    self.manageBar = [UIView new];
    self.manageBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.manageBar.clipsToBounds = YES;
    [self.view addSubview:self.manageBar];

    UIButton *clearImage =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [clearImage setTitle:@"清除图片"
                forState:UIControlStateNormal];

    [clearImage setImage:
        [UIImage systemImageNamed:@"photo.on.rectangle"]
              forState:UIControlStateNormal];

    clearImage.titleLabel.font = [UIFont systemFontOfSize:18.0];
    clearImage.semanticContentAttribute =
        UISemanticContentAttributeForceRightToLeft;
    clearImage.translatesAutoresizingMaskIntoConstraints = NO;

    [clearImage addTarget:self
                   action:@selector(clearImages)
         forControlEvents:UIControlEventTouchUpInside];

    [self.manageBar addSubview:clearImage];

    UIButton *clear =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [clear setTitle:@"清除剪贴板"
           forState:UIControlStateNormal];

    [clear setImage:
        [UIImage systemImageNamed:@"trash"]
          forState:UIControlStateNormal];

    [clear setTitleColor:UIColor.systemRedColor
                forState:UIControlStateNormal];

    clear.tintColor = UIColor.systemRedColor;
    clear.titleLabel.font = [UIFont systemFontOfSize:18.0];
    clear.semanticContentAttribute =
        UISemanticContentAttributeForceRightToLeft;
    clear.translatesAutoresizingMaskIntoConstraints = NO;

    [clear addTarget:self
              action:@selector(clearHistory)
    forControlEvents:UIControlEventTouchUpInside];

    [self.manageBar addSubview:clear];

    self.manageHeight =
        [self.manageBar.heightAnchor constraintEqualToConstant:0.0];
    self.manageHeight.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [self.manageBar.topAnchor
            constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.manageBar.leadingAnchor
            constraintEqualToAnchor:self.view.leadingAnchor],
        [self.manageBar.trailingAnchor
            constraintEqualToAnchor:self.view.trailingAnchor],

        [clearImage.leadingAnchor
            constraintEqualToAnchor:self.manageBar.leadingAnchor
            constant:24.0],
        [clearImage.trailingAnchor
            constraintEqualToAnchor:self.manageBar.centerXAnchor
            constant:-8.0],
        [clearImage.topAnchor
            constraintEqualToAnchor:self.manageBar.topAnchor],
        [clearImage.bottomAnchor
            constraintEqualToAnchor:self.manageBar.bottomAnchor],

        [clear.leadingAnchor
            constraintEqualToAnchor:self.manageBar.centerXAnchor
            constant:8.0],
        [clear.trailingAnchor
            constraintEqualToAnchor:self.manageBar.trailingAnchor
            constant:-24.0],
        [clear.topAnchor
            constraintEqualToAnchor:self.manageBar.topAnchor],
        [clear.bottomAnchor
            constraintEqualToAnchor:self.manageBar.bottomAnchor]
    ]];

    self.segment =
        [[UISegmentedControl alloc]
            initWithItems:@[@"剪贴板", @"收藏夹"]];

    self.segment.selectedSegmentIndex = 0;
    self.segment.translatesAutoresizingMaskIntoConstraints = NO;

    [self.segment addTarget:self
                     action:@selector(segmentChanged:)
           forControlEvents:UIControlEventValueChanged];

    [self.view addSubview:self.segment];

    self.table =
        [[UITableView alloc]
            initWithFrame:CGRectZero
                   style:UITableViewStylePlain];

    self.table.delegate = self;
    self.table.dataSource = self;
    self.table.separatorColor = UIColor.separatorColor;
    self.table.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:self.table];

    [NSLayoutConstraint activateConstraints:@[
        [self.segment.topAnchor
            constraintEqualToAnchor:self.manageBar.bottomAnchor
            constant:10.0],
        [self.segment.centerXAnchor
            constraintEqualToAnchor:self.view.centerXAnchor],
        [self.segment.widthAnchor
            constraintEqualToConstant:260.0],
        [self.segment.heightAnchor
            constraintEqualToConstant:40.0],

        [self.table.topAnchor
            constraintEqualToAnchor:self.segment.bottomAnchor
            constant:12.0],
        [self.table.leadingAnchor
            constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor
            constraintEqualToAnchor:self.view.trailingAnchor],
        [self.table.bottomAnchor
            constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [self reload];
}

- (void)toggleManage {
    self.managing = !self.managing;
    self.manageHeight.constant = self.managing ? 52.0 : 0.0;
    self.navigationItem.rightBarButtonItem.title =
        self.managing ? @"完成" : @"管理";

    [UIView animateWithDuration:0.2
                     animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)reload {
    if (self.favoritesMode)
        self.items = [KTClipboardManager.sharedManager favorites];
    else
        self.items = [KTClipboardManager.sharedManager items];

    [self.table reloadData];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    self.favoritesMode = sender.selectedSegmentIndex == 1;
    [self reload];
}

- (void)clearImages {
    [KTClipboardManager.sharedManager clearImages];
}

- (void)clearHistory {
    [KTClipboardManager.sharedManager clearClipboardHistory];
    [self reload];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (CGFloat)tableView:(UITableView *)tableView
heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 92.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.row >= self.items.count)
        return [UITableViewCell new];

    KTClipboardItem *item = self.items[indexPath.row];

    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"clip"];

    if (!cell) {
        cell =
            [[UITableViewCell alloc]
                initWithStyle:UITableViewCellStyleSubtitle
             reuseIdentifier:@"clip"];
    }

    cell.textLabel.font = [UIFont systemFontOfSize:20.0];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:16.0];
    cell.detailTextLabel.numberOfLines = 1;

    if (KTShowSource()) {
        cell.textLabel.text =
            item.appName.length ? item.appName : @"未知应用";
        cell.detailTextLabel.text = item.text ?: @"";
    } else {
        cell.textLabel.text = item.text ?: @"";
        cell.detailTextLabel.text = @"";
    }

    cell.accessoryType =
        item.favorite
            ? UITableViewCellAccessoryCheckmark
            : UITableViewCellAccessoryNone;

    cell.imageView.image =
        [UIImage systemImageNamed:@"doc.on.clipboard"];

    return cell;
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.row >= self.items.count)
        return;

    KTClipboardItem *item = self.items[indexPath.row];

    if (item.text.length > 0 && self.input) {
        [KTClipboardManager.sharedManager
            pasteItem:item
            intoInput:self.input];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {

    if (editingStyle != UITableViewCellEditingStyleDelete)
        return;

    if (indexPath.row >= self.items.count)
        return;

    [KTClipboardManager.sharedManager removeItem:self.items[indexPath.row]];
    [self reload];
}

@end
