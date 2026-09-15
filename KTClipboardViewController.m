#import "KTClipboardViewController.h"
#import "KTClipboardManager.h"
#import "KTSettings.h"
#import <UIKit/UIKit.h>

@interface UIApplication (KTPrivateIcon)
- (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier
                                               format:(NSInteger)format
                                                scale:(CGFloat)scale;
@end

@interface KTClipboardViewController () <UITableViewDelegate, UITableViewDataSource>

@property(nonatomic, strong) id<UITextInput> input;
@property(nonatomic, strong) UISegmentedControl *segment;
@property(nonatomic, strong) UITableView *tableView;

@end

@implementation KTClipboardViewController

- (instancetype)initWithInput:(id<UITextInput>)input {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _input = input;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"剪贴板";

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"清除图片"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(clearImages)];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"清除剪贴板"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(clearHistory)];

    self.segment =
        [[UISegmentedControl alloc] initWithItems:@[@"剪贴板", @"收藏夹"]];

    self.segment.selectedSegmentIndex = 0;
    [self.segment addTarget:self
                     action:@selector(segmentChanged:)
           forControlEvents:UIControlEventValueChanged];

    self.navigationItem.titleView = self.segment;

    self.tableView = self.tableView;

    self.tableView.delegate = self;
    self.tableView.dataSource = self;

    [self.tableView registerClass:UITableViewCell.class
           forCellReuseIdentifier:@"KTClipboardCell"];

    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark - 数据

- (NSArray<KTClipboardItem *> *)currentItems {
    KTClipboardManager *manager = [KTClipboardManager sharedManager];

    if (self.segment.selectedSegmentIndex == 1) {
        return [manager favorites];
    }

    return [manager items];
}

#pragma mark - 操作

- (void)segmentChanged:(UISegmentedControl *)sender {
    [self.tableView reloadData];
}

- (void)clearImages {
    [[KTClipboardManager sharedManager] clearImages];
    [self.tableView reloadData];
}

- (void)clearHistory {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"清除剪贴板"
                                             message:@"确定要清除剪贴板历史记录吗？"
                                      preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *cancel =
        [UIAlertAction actionWithTitle:@"取消"
                                 style:UIAlertActionStyleCancel
                               handler:nil];

    UIAlertAction *confirm =
        [UIAlertAction actionWithTitle:@"清除"
                                 style:UIAlertActionStyleDestructive
                               handler:^(UIAlertAction *action) {
        [[KTClipboardManager sharedManager] clearClipboardHistory];
        [self.tableView reloadData];
    }];

    [alert addAction:cancel];
    [alert addAction:confirm];

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return [self currentItems].count;
}

- (CGFloat)tableView:(UITableView *)tableView
heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 64.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"KTClipboardCell"
                                        forIndexPath:indexPath];

    NSArray<KTClipboardItem *> *items = [self currentItems];

    if (indexPath.row >= items.count) {
        return cell;
    }

    KTClipboardItem *item = items[indexPath.row];

    cell.textLabel.numberOfLines = 2;
    cell.textLabel.font =
        [UIFont systemFontOfSize:15.0];

    cell.detailTextLabel.text = nil;
    cell.imageView.image = nil;

    if (KTShowSource() && item.appName.length > 0) {
        cell.textLabel.text =
            [NSString stringWithFormat:@"%@\n%@",
             item.appName,
             item.text ?: @""];
    } else {
        cell.textLabel.text = item.text ?: @"";
    }

    if (item.bundleIdentifier.length > 0) {
        UIApplication *application =
            [UIApplication sharedApplication];

        UIImage *icon =
            [application _applicationIconImageForBundleIdentifier:
                item.bundleIdentifier
                                                           format:0
                                                            scale:UIScreen.mainScreen.scale];

        if (icon) {
            cell.imageView.image = icon;
        }
    }

    if (item.favorite) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

#pragma mark - 点击

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    NSArray<KTClipboardItem *> *items = [self currentItems];

    if (indexPath.row >= items.count) {
        return;
    }

    KTClipboardItem *item = items[indexPath.row];

    if (item.text.length > 0 && self.input) {
        [[KTClipboardManager sharedManager]
            pasteItem:item
            intoInput:self.input];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 收藏

- (void)tableView:(UITableView *)tableView
didEndDisplayingCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath {
    /* 防止复用状态残留 */
}

#pragma mark - 删除

- (BOOL)tableView:(UITableView *)tableView
canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {

    if (editingStyle != UITableViewCellEditingStyleDelete) {
        return;
    }

    NSArray<KTClipboardItem *> *items = [self currentItems];

    if (indexPath.row >= items.count) {
        return;
    }

    KTClipboardItem *item = items[indexPath.row];

    [[KTClipboardManager sharedManager] removeItem:item];

    [tableView reloadData];
}

#pragma mark - 点击收藏

- (void)tableView:(UITableView *)tableView
didHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
}

@end
