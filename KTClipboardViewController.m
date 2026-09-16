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
    if ((self=[super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) {
        self.backgroundColor=UIColor.clearColor;
        self.selectionStyle=UITableViewCellSelectionStyleDefault;
        _numberLabel=[UILabel new]; _numberLabel.font=[UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightMedium]; _numberLabel.textAlignment=NSTextAlignmentCenter;
        _contentLabel=[UILabel new]; _contentLabel.font=[UIFont systemFontOfSize:17 weight:UIFontWeightRegular]; _contentLabel.numberOfLines=2;
        _sourceLabel=[UILabel new]; _sourceLabel.font=[UIFont systemFontOfSize:12]; _sourceLabel.textColor=UIColor.secondaryLabelColor;
        _timeLabel=[UILabel new]; _timeLabel.font=[UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium]; _timeLabel.textAlignment=NSTextAlignmentRight;
        _dateLabel=[UILabel new]; _dateLabel.font=[UIFont systemFontOfSize:11]; _dateLabel.textColor=UIColor.secondaryLabelColor; _dateLabel.textAlignment=NSTextAlignmentRight;
        for (UIView *v in @[_numberLabel,_contentLabel,_sourceLabel,_timeLabel,_dateLabel]) [self.contentView addSubview:v];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w=self.contentView.bounds.size.width;
    _numberLabel.frame=CGRectMake(8,8,28,48);
    _timeLabel.frame=CGRectMake(w-72,9,62,19);
    _dateLabel.frame=CGRectMake(w-82,30,72,17);
    CGFloat left=44, right=90;
    _contentLabel.frame=CGRectMake(left,8,w-left-right,40);
    _sourceLabel.frame=CGRectMake(left,49,w-left-right,16);
}
@end

@interface KTClipboardViewController () <UITableViewDelegate,UITableViewDataSource>
@property(nonatomic,strong) id<UITextInput> input;
@property(nonatomic,strong) UITableView *table;
@property(nonatomic,strong) NSArray *items;
@property(nonatomic,strong) UIView *grabber;
@property(nonatomic,strong) UIButton *menuButton;
@property(nonatomic,strong) UIButton *clearButton;
@property(nonatomic,strong) UIButton *imageButton;
@property(nonatomic,strong) UIView *menuCard;
@property(nonatomic,strong) UIView *tabBar;
@property(nonatomic,strong) UIView *tabIndicator;
@property(nonatomic,strong) UIButton *clipboardTab;
@property(nonatomic,strong) UIButton *favoriteTab;
@property(nonatomic,assign) BOOL menuVisible;
@property(nonatomic,assign) NSInteger selectedTab;
@end

@implementation KTClipboardViewController
- (instancetype)initWithInput:(id<UITextInput>)input { if ((self=[super initWithNibName:nil bundle:nil])) _input=input; return self; }

- (UIButton *)iconButton:(NSString *)symbol action:(SEL)action {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *img=[UIImage systemImageNamed:symbol];
    if (img) [b setImage:img forState:UIControlStateNormal];
    b.tintColor=UIColor.labelColor;
    b.accessibilityLabel=@"操作";
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    b.layer.cornerRadius=18.0;
    return b;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=UIColor.clearColor;
    self.panel=[UIView new];
    self.panel.backgroundColor=[UIColor colorWithWhite:0.94 alpha:1.0];
    self.panel.layer.cornerRadius=14.0;
    self.panel.layer.maskedCorners=kCALayerMinXMinYCorner|kCALayerMaxXMinYCorner;
    self.panel.layer.masksToBounds=YES;
    [self.view addSubview:self.panel];

    self.grabber=[UIView new]; self.grabber.backgroundColor=UIColor.tertiaryLabelColor; self.grabber.layer.cornerRadius=2.5; self.grabber.userInteractionEnabled=YES;
    [self.panel addSubview:self.grabber];
    [self.grabber addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]];

    self.menuButton=[self iconButton:@"line.3.horizontal" action:@selector(toggleMenu)];
    [self.panel addSubview:self.menuButton];

    self.tabBar=[UIView new]; self.tabBar.backgroundColor=[UIColor colorWithWhite:0.88 alpha:1.0]; self.tabBar.layer.cornerRadius=17.0; self.tabBar.clipsToBounds=YES;
    [self.panel addSubview:self.tabBar];
    self.clipboardTab=[UIButton buttonWithType:UIButtonTypeSystem]; [self.clipboardTab setTitle:@"剪贴板" forState:UIControlStateNormal]; self.clipboardTab.titleLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]; [self.clipboardTab addTarget:self action:@selector(selectClipboardTab) forControlEvents:UIControlEventTouchUpInside];
    self.favoriteTab=[UIButton buttonWithType:UIButtonTypeSystem]; [self.favoriteTab setTitle:@"收藏夹" forState:UIControlStateNormal]; self.favoriteTab.titleLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]; [self.favoriteTab addTarget:self action:@selector(selectFavoriteTab) forControlEvents:UIControlEventTouchUpInside];
    [self.tabBar addSubview:self.clipboardTab]; [self.tabBar addSubview:self.favoriteTab];
    self.tabIndicator=[UIView new]; self.tabIndicator.backgroundColor=UIColor.systemBackgroundColor; self.tabIndicator.layer.cornerRadius=14.0; [self.tabBar addSubview:self.tabIndicator]; [self.tabBar sendSubviewToBack:self.tabIndicator];

    self.menuCard=[UIView new]; self.menuCard.backgroundColor=UIColor.systemBackgroundColor; self.menuCard.layer.cornerRadius=14.0; self.menuCard.layer.shadowOpacity=0.12; self.menuCard.layer.shadowRadius=12; self.menuCard.layer.shadowOffset=CGSizeMake(0,4); self.menuCard.hidden=YES;
    [self.panel addSubview:self.menuCard];
    self.clearButton=[self iconButton:@"trash" action:@selector(clearHistory)];
    self.imageButton=[self iconButton:@"photo.on.rectangle" action:@selector(clearImages)];
    [self.menuCard addSubview:self.clearButton]; [self.menuCard addSubview:self.imageButton];

    self.table=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.delegate=self; self.table.dataSource=self; self.table.backgroundColor=UIColor.clearColor; self.table.separatorColor=[UIColor colorWithWhite:0.82 alpha:1.0]; self.table.separatorInset=UIEdgeInsetsMake(0,44,0,10); self.table.showsVerticalScrollIndicator=YES; self.table.alwaysBounceVertical=YES;
    [self.panel addSubview:self.table];
}
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; [self layoutPanel]; [self reload]; self.panel.transform=CGAffineTransformMakeTranslation(0,CGRectGetHeight(self.view.bounds)); [UIView animateWithDuration:0.22 animations:^{ self.panel.transform=CGAffineTransformIdentity; }]; }
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; [self layoutPanel]; }
- (void)layoutPanel {
    CGFloat w=self.view.bounds.size.width,h=self.view.bounds.size.height; if (w<=0||h<=0) return;
    CGFloat ph=400.0; self.panel.frame=CGRectMake(0,h-ph,w,ph);
    self.grabber.frame=CGRectMake((w-42)/2.0,7,42,5);
    self.menuButton.frame=CGRectMake(14,25,36,36);
    if (!self.selectedTab && !self.tabIndicator.superview) self.selectedTab=0;
    self.tabBar.frame=CGRectMake((w-220)/2.0,22,220,34);
    self.clipboardTab.frame=CGRectMake(2,2,108,30); self.favoriteTab.frame=CGRectMake(110,2,108,30); self.tabIndicator.frame=CGRectMake(self.segmentIndex*108+2,2,108,30);
    self.menuCard.frame=CGRectMake(12,64,150,74);
    self.clearButton.frame=CGRectMake(10,10,56,54); self.imageButton.frame=CGRectMake(84,10,56,54);
    self.table.frame=CGRectMake(0,68,w,ph-68);
}
- (NSInteger)segmentIndex { return self.selectedTab; }
- (void)setTab:(NSInteger)idx animated:(BOOL)animated {
    self.selectedTab=idx;
    self.clipboardTab.tintColor=idx==0?UIColor.systemBlueColor:UIColor.labelColor; self.favoriteTab.tintColor=idx==1?UIColor.systemBlueColor:UIColor.labelColor;
    CGFloat x=idx*108+2;
    void (^changes)(void)=^{ self.tabIndicator.frame=CGRectMake(x,2,108,30); };
    if (animated) [UIView animateWithDuration:0.18 animations:changes]; else changes();
    [self reload];
}
- (void)selectClipboardTab { [self setTab:0 animated:YES]; }
- (void)selectFavoriteTab { [self setTab:1 animated:YES]; }
- (void)reload { NSInteger idx=[self segmentIndex]; self.items=idx?KTClipboardManager.sharedManager.favorites:KTClipboardManager.sharedManager.items; [self.table reloadData]; }
- (void)toggleMenu { self.menuVisible=!self.menuVisible; self.menuCard.hidden=!self.menuVisible; }
- (void)clearImages { [KTClipboardManager.sharedManager clearImages]; self.menuVisible=NO; self.menuCard.hidden=YES; }
- (void)clearHistory { [KTClipboardManager.sharedManager clearClipboardHistory]; self.menuVisible=NO; self.menuCard.hidden=YES; [self reload]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.items.count; }
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath { return 76.0; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.row>=self.items.count) return [UITableViewCell new];
    KTClipboardItem *item=self.items[indexPath.row]; KTClipboardCell *cell=[tableView dequeueReusableCellWithIdentifier:@"clipCell"];
    if(!cell) cell=[[KTClipboardCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"clipCell"];
    cell.numberLabel.text=[NSString stringWithFormat:@"%ld",(long)indexPath.row+1];
    cell.contentLabel.text=item.text ?: @"";
    cell.sourceLabel.text=KTShowSource() ? (item.appName.length?item.appName:@"未知应用") : @"";
    NSDate *date=item.recordedAt ?: NSDate.date; NSCalendar *cal=NSCalendar.currentCalendar; NSDateComponents *dc=[cal components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:date]; NSDateComponents *tc=[cal components:NSCalendarUnitHour|NSCalendarUnitMinute fromDate:date];
    cell.timeLabel.text=[NSString stringWithFormat:@"%02ld:%02ld",(long)tc.hour,(long)tc.minute];
    NSDateComponents *today=[cal components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:NSDate.date];
    cell.dateLabel.text=(dc.year==today.year&&dc.month==today.month&&dc.day==today.day)?@"今天":[NSString stringWithFormat:@"%ld月%ld日",(long)dc.month,(long)dc.day];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.row>=self.items.count) return; KTClipboardItem *item=self.items[indexPath.row]; if(item.text.length&&self.input) [KTClipboardManager.sharedManager pasteItem:item intoInput:self.input]; [tableView deselectRowAtIndexPath:indexPath animated:YES]; [self closePage];
}
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.row>=self.items.count) return nil;
    KTClipboardItem *item=self.items[indexPath.row];
    UIContextualAction *fav=[UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"" handler:^(__unused UIContextualAction *a,__unused UIView *v,void(^done)(BOOL)){ [KTClipboardManager.sharedManager setFavorite:!item.favorite forItem:item]; done(YES); [self reload]; }];
    fav.image=[UIImage systemImageNamed:item.favorite?@"star.slash":@"star"]; fav.backgroundColor=UIColor.systemOrangeColor;
    UIContextualAction *del=[UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"" handler:^(__unused UIContextualAction *a,__unused UIView *v,void(^done)(BOOL)){ [KTClipboardManager.sharedManager removeItem:item]; done(YES); [self reload]; }];
    del.image=[UIImage systemImageNamed:@"trash"]; return [UISwipeActionsConfiguration configurationWithActions:@[del,fav]];
}
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint t=[pan translationInView:self.view]; CGPoint v=[pan velocityInView:self.view];
    if(pan.state==UIGestureRecognizerStateEnded||pan.state==UIGestureRecognizerStateCancelled){ if(t.y>55||v.y>650) [self closePage]; else [UIView animateWithDuration:0.16 animations:^{ self.panel.transform=CGAffineTransformIdentity; }]; }
}
- (void)closePage { if(self.closeHandler) self.closeHandler(); }
@end
