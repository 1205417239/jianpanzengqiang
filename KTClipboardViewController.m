#import "KTClipboardViewController.h"
#import "KTClipboardManager.h"
#import "KTSettings.h"
#import <UIKit/UIKit.h>

@interface KTClipboardViewController () <UITableViewDelegate, UITableViewDataSource>

@property(nonatomic,strong) id<UITextInput> input;
@property(nonatomic,strong) UISegmentedControl *segment;
@property(nonatomic,strong) UITableView *table;
@property(nonatomic,strong) NSArray *items;
@property(nonatomic,assign) BOOL favoritesMode;
@property(nonatomic,strong) UIView *grabber;
@property(nonatomic,assign) CGPoint panStartCenter;

@end

@implementation KTClipboardViewController

- (instancetype)initWithInput:(id<UITextInput>)input {
    self = [super initWithNibName:nil bundle:nil];

    if (self) {
        _input = input;
    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"剪贴板";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.view.layer.cornerRadius = 20.0;
    self.view.layer.masksToBounds = YES;

    self.grabber = [UIView new];
    self.grabber.backgroundColor = UIColor.secondaryLabelColor;
    self.grabber.layer.cornerRadius = 3.0;
    self.grabber.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.grabber];

    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.view addGestureRecognizer:pan];

    UIView *top = [UIView new];
    top.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:top];

    UIButton *clearImage =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [clearImage setTitle:@"清除图片"
                forState:UIControlStateNormal];

    clearImage.titleLabel.font =
        [UIFont systemFontOfSize:20.0];

    [clearImage setImage:
        [UIImage systemImageNamed:@"photo.on.rectangle"]
              forState:UIControlStateNormal];

    clearImage.semanticContentAttribute =
        UISemanticContentAttributeForceRightToLeft;

    [clearImage addTarget:self
                   action:@selector(clearImages)
         forControlEvents:UIControlEventTouchUpInside];

    clearImage.translatesAutoresizingMaskIntoConstraints = NO;
    [top addSubview:clearImage];

    UIButton *clear =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [clear setTitle:@"清除剪贴板"
           forState:UIControlStateNormal];

    clear.titleLabel.font =
        [UIFont systemFontOfSize:20.0];

    [clear setImage:
        [UIImage systemImageNamed:@"trash"]
          forState:UIControlStateNormal];

    clear.semanticContentAttribute =
        UISemanticContentAttributeForceRightToLeft;

    [clear setTitleColor:UIColor.systemRedColor
                forState:UIControlStateNormal];

    clear.tintColor = UIColor.systemRedColor;

    [clear addTarget:self
              action:@selector(clearHistory)
    forControlEvents:UIControlEventTouchUpInside];

    clear.translatesAutoresizingMaskIntoConstraints = NO;
    [top addSubview:clear];

    UIView *line = [UIView new];

    line.backgroundColor = UIColor.separatorColor;
    line.translatesAutoresizingMaskIntoConstraints = NO;

    [top addSubview:line];

    self.segment =
        [[UISegmentedControl alloc]
            initWithItems:@[@"剪贴板", @"收藏夹"]];

    self.segment.selectedSegmentIndex = 0;

    [self.segment addTarget:self
                     action:@selector(segmentChanged:)
           forControlEvents:UIControlEventValueChanged];

    self.segment.translatesAutoresizingMaskIntoConstraints = NO;

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
        [self.grabber.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:7.0],
        [self.grabber.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.grabber.widthAnchor constraintEqualToConstant:42.0],
        [self.grabber.heightAnchor constraintEqualToConstant:6.0],

        [top.topAnchor
            constraintEqualToAnchor:
                self.view.safeAreaLayoutGuide.topAnchor],

        [top.leadingAnchor
            constraintEqualToAnchor:self.view.leadingAnchor],

        [top.trailingAnchor
            constraintEqualToAnchor:self.view.trailingAnchor],

        [top.heightAnchor
            constraintEqualToConstant:96.0],

        [clearImage.leadingAnchor
            constraintEqualToAnchor:top.leadingAnchor
            constant:28.0],

        [clearImage.trailingAnchor
            constraintEqualToAnchor:top.trailingAnchor
            constant:-28.0],

        [clearImage.topAnchor
            constraintEqualToAnchor:top.topAnchor
            constant:8.0],

        [clearImage.heightAnchor
            constraintEqualToConstant:42.0],

        [line.leadingAnchor
            constraintEqualToAnchor:top.leadingAnchor],

        [line.trailingAnchor
            constraintEqualToAnchor:top.trailingAnchor],

        [line.topAnchor
            constraintEqualToAnchor:clearImage.bottomAnchor],

        [line.heightAnchor
            constraintEqualToConstant:0.5],

        [clear.leadingAnchor
            constraintEqualToAnchor:top.leadingAnchor
            constant:28.0],

        [clear.trailingAnchor
            constraintEqualToAnchor:top.trailingAnchor
            constant:-28.0],

        [clear.topAnchor
            constraintEqualToAnchor:line.bottomAnchor],

        [clear.heightAnchor
            constraintEqualToConstant:42.0],

        [self.segment.centerXAnchor
            constraintEqualToAnchor:self.view.centerXAnchor],

        [self.segment.topAnchor
            constraintEqualToAnchor:top.bottomAnchor
            constant:10.0],

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

- (void)reload {
    if (self.favoritesMode) {
        self.items =
            [KTClipboardManager.sharedManager favorites];
    } else {
        self.items =
            [KTClipboardManager.sharedManager items];
    }

    [self.table reloadData];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    self.favoritesMode =
        (sender.selectedSegmentIndex == 1);

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

    KTClipboardItem *item =
        self.items[indexPath.row];

    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"clip"];

    if (!cell) {
        cell =
            [[UITableViewCell alloc]
                initWithStyle:UITableViewCellStyleSubtitle
             reuseIdentifier:@"clip"];
    }

    cell.textLabel.font =
        [UIFont systemFontOfSize:20.0];

    cell.detailTextLabel.font =
        [UIFont systemFontOfSize:16.0];

    cell.detailTextLabel.numberOfLines = 1;

    BOOL showSource = YES;

    showSource = KTShowSource();

    if (showSource) {
        cell.textLabel.text =
            item.appName.length
                ? item.appName
                : @"未知应用";

        cell.detailTextLabel.text =
            item.text ?: @"";
    } else {
        cell.textLabel.text =
            item.text ?: @"";

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

    KTClipboardItem *item =
        self.items[indexPath.row];

    if (item.text.length > 0 && self.input) {
        [KTClipboardManager.sharedManager
            pasteItem:item
            intoInput:self.input];
    }

    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];

    [self closePage];
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {

    if (editingStyle !=
        UITableViewCellEditingStyleDelete)
        return;

    if (indexPath.row >= self.items.count)
        return;

    KTClipboardItem *item =
        self.items[indexPath.row];

    [KTClipboardManager.sharedManager
        removeItem:item];

    [self reload];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIWindow *window = self.view.window;
    if (!window)
        return;

    CGPoint translation = [pan translationInView:window];

    if (pan.state == UIGestureRecognizerStateBegan) {
        self.panStartCenter = window.center;
        return;
    }

    if (pan.state == UIGestureRecognizerStateChanged) {
        if (translation.y > 0.0)
            window.center = CGPointMake(self.panStartCenter.x, self.panStartCenter.y + translation.y);
        return;
    }

    if (pan.state == UIGestureRecognizerStateEnded ||
        pan.state == UIGestureRecognizerStateCancelled) {
        CGFloat offset = window.center.y - self.panStartCenter.y;
        CGFloat velocity = [pan velocityInView:window].y;

        if (offset > 110.0 || velocity > 900.0) {
            [self closePage];
            return;
        }

        [UIView animateWithDuration:0.20
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            window.center = self.panStartCenter;
        }
                         completion:nil];
    }
}

- (void)closePage {
    if (self.closeHandler)
        self.closeHandler();
}

@end
