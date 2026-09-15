#import "KTClipboardViewController.h"
#import "KTClipboardManager.h"
#import "KTSettings.h"
#import <UIKit/UIKit.h>

@interface KTClipboardCell : UITableViewCell
@property(nonatomic,strong) UILabel *numberLabel,*contentLabel,*sourceLabel,*timeLabel,*dateLabel;
@property(nonatomic,strong) UIImageView *thumbView;
@end
@implementation KTClipboardCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if((self=[super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])){
        self.backgroundColor=UIColor.clearColor; self.selectionStyle=UITableViewCellSelectionStyleDefault;
        _numberLabel=[UILabel new]; _numberLabel.font=[UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium]; _numberLabel.textAlignment=NSTextAlignmentCenter;
        _contentLabel=[UILabel new]; _contentLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightRegular]; _contentLabel.numberOfLines=2;
        _sourceLabel=[UILabel new]; _sourceLabel.font=[UIFont systemFontOfSize:10]; _sourceLabel.textColor=UIColor.secondaryLabelColor;
        _timeLabel=[UILabel new]; _timeLabel.font=[UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightMedium]; _timeLabel.textAlignment=NSTextAlignmentRight;
        _dateLabel=[UILabel new]; _dateLabel.font=[UIFont systemFontOfSize:9]; _dateLabel.textColor=UIColor.secondaryLabelColor; _dateLabel.textAlignment=NSTextAlignmentRight;
        _thumbView=[UIImageView new]; _thumbView.contentMode=UIViewContentModeScaleAspectFit; _thumbView.layer.cornerRadius=6; _thumbView.clipsToBounds=YES; _thumbView.hidden=YES;
        for(UIView *v in @[_numberLabel,_contentLabel,_sourceLabel,_timeLabel,_dateLabel,_thumbView]) [self.contentView addSubview:v];
    } return self;
}
- (void)layoutSubviews {
    [super layoutSubviews]; CGFloat w=self.contentView.bounds.size.width;
    _numberLabel.frame=CGRectMake(6,5,24,38); _timeLabel.frame=CGRectMake(w-68,5,58,16); _dateLabel.frame=CGRectMake(w-76,21,66,14);
    CGFloat left=36,right=82; _contentLabel.frame=CGRectMake(left,5,w-left-right,31); _sourceLabel.frame=CGRectMake(left,37,w-left-right,13); _thumbView.frame=CGRectMake(left,5,38,38);
}
@end

@interface KTClipboardViewController () <UITableViewDelegate,UITableViewDataSource,UIGestureRecognizerDelegate>
@property(nonatomic,strong) id<UITextInput> input; @property(nonatomic,strong) UITableView *table; @property(nonatomic,strong) NSArray *items;
@property(nonatomic,strong) UIView *grabber,*dragArea; @property(nonatomic,strong) UIButton *menuButton,*clearButton,*imageButton;
@property(nonatomic,strong) UIView *tabBar,*tabIndicator; @property(nonatomic,strong) UIButton *clipboardTab,*favoriteTab;
@property(nonatomic,assign) BOOL menuVisible; @property(nonatomic,assign) NSInteger selectedTab; @property(nonatomic,assign) BOOL appearing; @property(nonatomic,assign) BOOL closing;
@end

@implementation KTClipboardViewController
- (instancetype)initWithInput:(id<UITextInput>)input { if((self=[super initWithNibName:nil bundle:nil]))_input=input; return self; }
- (UIButton *)iconButton:(NSString *)symbol action:(SEL)action { UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem]; UIImage *img=[UIImage systemImageNamed:symbol]; if(img)[b setImage:img forState:UIControlStateNormal]; b.tintColor=UIColor.labelColor; b.imageView.contentMode=UIViewContentModeScaleAspectFit; [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside]; return b; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor=UIColor.clearColor;
    self.panel=[UIView new]; self.panel.backgroundColor=[UIColor colorWithWhite:.94 alpha:1]; self.panel.layer.cornerRadius=30; self.panel.layer.maskedCorners=kCALayerMinXMinYCorner|kCALayerMaxXMinYCorner; self.panel.layer.masksToBounds=YES; [self.view addSubview:self.panel];
    self.dragArea=[UIView new]; self.dragArea.backgroundColor=UIColor.clearColor; self.dragArea.userInteractionEnabled=YES; [self.panel addSubview:self.dragArea]; UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(handlePan:)]; pan.delegate=self; pan.cancelsTouchesInView=NO; [self.dragArea addGestureRecognizer:pan];
    self.grabber=[UIView new]; self.grabber.backgroundColor=UIColor.tertiaryLabelColor; self.grabber.layer.cornerRadius=2.5; [self.dragArea addSubview:self.grabber];
    self.menuButton=[self iconButton:@"line.3.horizontal" action:@selector(toggleMenu)]; [self.panel addSubview:self.menuButton];
    self.clearButton=[self iconButton:@"trash" action:@selector(clearHistory)]; self.imageButton=[self iconButton:@"photo.on.rectangle" action:@selector(clearImages)]; self.clearButton.tintColor=UIColor.systemRedColor; self.clearButton.hidden=YES; self.imageButton.hidden=YES; [self.panel addSubview:self.clearButton]; [self.panel addSubview:self.imageButton];
    self.tabBar=[UIView new]; self.tabBar.backgroundColor=UIColor.clearColor; [self.panel addSubview:self.tabBar];
    self.clipboardTab=[UIButton buttonWithType:UIButtonTypeSystem]; [self.clipboardTab setTitle:@"剪贴板" forState:UIControlStateNormal]; self.clipboardTab.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]; [self.clipboardTab addTarget:self action:@selector(selectClipboardTab) forControlEvents:UIControlEventTouchUpInside];
    self.favoriteTab=[UIButton buttonWithType:UIButtonTypeSystem]; [self.favoriteTab setTitle:@"收藏夹" forState:UIControlStateNormal]; self.favoriteTab.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]; [self.favoriteTab addTarget:self action:@selector(selectFavoriteTab) forControlEvents:UIControlEventTouchUpInside]; [self.tabBar addSubview:self.clipboardTab]; [self.tabBar addSubview:self.favoriteTab];
    self.tabIndicator=[UIView new]; self.tabIndicator.backgroundColor=UIColor.systemBackgroundColor; self.tabIndicator.layer.cornerRadius=14; [self.tabBar insertSubview:self.tabIndicator atIndex:0];
    self.table=[[UITableView alloc]initWithFrame:CGRectZero style:UITableViewStylePlain]; self.table.delegate=self; self.table.dataSource=self; self.table.backgroundColor=UIColor.clearColor; self.table.separatorColor=[UIColor colorWithWhite:.82 alpha:1]; self.table.separatorInset=UIEdgeInsetsMake(0,36,0,10); self.table.showsVerticalScrollIndicator=YES; self.table.alwaysBounceVertical=YES; [self.panel addSubview:self.table];
}
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; [self layoutPanel]; [self reload]; self.closing=NO; self.appearing=YES; self.panel.transform=CGAffineTransformMakeTranslation(0,400); [UIView animateWithDuration:.38 delay:0 usingSpringWithDamping:.90 initialSpringVelocity:.15 options:UIViewAnimationOptionCurveEaseOut animations:^{self.panel.transform=CGAffineTransformIdentity;} completion:^(__unused BOOL f){self.appearing=NO;}]; }
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; [self layoutPanel]; }
- (void)layoutPanel { CGFloat w=self.view.bounds.size.width,h=self.view.bounds.size.height;if(w<=0||h<=0)return; CGFloat ph=400; self.panel.frame=CGRectMake(0,h-ph,w,ph); self.dragArea.frame=CGRectMake(0,0,w,92); self.grabber.frame=CGRectMake((w-40)/2,8,40,5); self.menuButton.frame=CGRectMake(14,24,34,34); self.clearButton.frame=CGRectMake(52,8,28,28); self.imageButton.frame=CGRectMake(84,8,28,28); self.tabBar.frame=CGRectMake((w-210)/2,27,210,34); self.clipboardTab.frame=CGRectMake(2,2,103,30); self.favoriteTab.frame=CGRectMake(105,2,103,30); self.tabIndicator.frame=CGRectMake(self.selectedTab?105:2,2,103,30); self.table.frame=CGRectMake(0,68,w,ph-68); }
- (void)reload { self.items=self.selectedTab?KTClipboardManager.sharedManager.favorites:KTClipboardManager.sharedManager.items; [self.table reloadData]; }
- (void)toggleMenu { self.menuVisible=!self.menuVisible; if(self.menuVisible){ self.clearButton.hidden=NO; self.imageButton.hidden=NO; self.clearButton.transform=CGAffineTransformMakeTranslation(0,18); self.imageButton.transform=CGAffineTransformMakeTranslation(0,18); self.clearButton.alpha=0; self.imageButton.alpha=0; [UIView animateWithDuration:.20 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{self.clearButton.alpha=1;self.imageButton.alpha=1;self.clearButton.transform=CGAffineTransformIdentity;self.imageButton.transform=CGAffineTransformIdentity;} completion:nil]; } else { [UIView animateWithDuration:.14 animations:^{self.clearButton.alpha=0;self.imageButton.alpha=0;self.clearButton.transform=CGAffineTransformMakeTranslation(0,10);self.imageButton.transform=CGAffineTransformMakeTranslation(0,10);} completion:^(__unused BOOL f){self.clearButton.hidden=YES;self.imageButton.hidden=YES;}]; } }
- (void)clearImages { [KTClipboardManager.sharedManager clearImages]; [self toggleMenu]; }
- (void)clearHistory { [KTClipboardManager.sharedManager clearClipboardHistory]; [self toggleMenu]; [self reload]; }
- (void)setTab:(NSInteger)idx { self.selectedTab=idx; self.clipboardTab.tintColor=idx?UIColor.labelColor:UIColor.systemBlueColor; self.favoriteTab.tintColor=idx?UIColor.systemBlueColor:UIColor.labelColor; CGFloat x=idx?105:2; [UIView animateWithDuration:.24 delay:0 usingSpringWithDamping:.88 initialSpringVelocity:.15 options:UIViewAnimationOptionCurveEaseInOut animations:^{self.tabIndicator.frame=CGRectMake(x,2,103,30);} completion:nil]; [self reload]; }
- (void)selectClipboardTab { [self setTab:0]; } - (void)selectFavoriteTab { [self setTab:1]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{return self.items.count;}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{return 60;}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath { if(indexPath.row>=self.items.count)return [UITableViewCell new]; KTClipboardItem *item=self.items[indexPath.row]; KTClipboardCell *cell=[tableView dequeueReusableCellWithIdentifier:@"clipCell"]; if(!cell)cell=[[KTClipboardCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"clipCell"]; cell.numberLabel.text=[NSString stringWithFormat:@"%ld",(long)indexPath.row+1]; cell.thumbView.hidden=item.imageData.length==0; cell.thumbView.image=item.imageData.length?[UIImage imageWithData:item.imageData]:nil; cell.contentLabel.hidden=item.imageData.length>0; cell.contentLabel.text=item.imageData.length?@"图片":(item.text?:@""); cell.sourceLabel.text=KTShowSource()?(item.appName.length?item.appName:@"未知应用"): @""; NSDate *date=item.recordedAt?:NSDate.date; NSCalendar *cal=NSCalendar.currentCalendar; NSDateComponents *dc=[cal components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:date]; NSDateComponents *tc=[cal components:NSCalendarUnitHour|NSCalendarUnitMinute fromDate:date]; cell.timeLabel.text=[NSString stringWithFormat:@"%02ld:%02ld",(long)tc.hour,(long)tc.minute]; NSDateComponents *today=[cal components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:NSDate.date]; cell.dateLabel.text=(dc.year==today.year&&dc.month==today.month&&dc.day==today.day)?@"今天":[NSString stringWithFormat:@"%ld月%ld日",(long)dc.month,(long)dc.day]; return cell; }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath { if(indexPath.row>=self.items.count)return; KTClipboardItem *item=self.items[indexPath.row]; if(item.text.length&&self.input)[KTClipboardManager.sharedManager pasteItem:item intoInput:self.input]; [tableView deselectRowAtIndexPath:indexPath animated:YES]; [self closePage]; }
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath { if(indexPath.row>=self.items.count)return nil; KTClipboardItem *item=self.items[indexPath.row]; UIContextualAction *fav=[UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"" handler:^(__unused UIContextualAction*a,__unused UIView*v,void(^done)(BOOL)){[KTClipboardManager.sharedManager setFavorite:!item.favorite forItem:item];done(YES);[self reload];}]; fav.image=[UIImage systemImageNamed:item.favorite?@"star.slash":@"star"]; fav.backgroundColor=UIColor.systemOrangeColor; UIContextualAction *del=[UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"" handler:^(__unused UIContextualAction*a,__unused UIView*v,void(^done)(BOOL)){[KTClipboardManager.sharedManager removeItem:item];done(YES);[self reload];}]; del.image=[UIImage systemImageNamed:@"trash"]; return [UISwipeActionsConfiguration configurationWithActions:@[del,fav]]; }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch { CGPoint p=[touch locationInView:self.panel]; return p.y<=92; }
- (void)handlePan:(UIPanGestureRecognizer *)pan { CGFloat y=MAX(0,[pan translationInView:self.view].y); CGFloat vy=[pan velocityInView:self.view].y; if(pan.state==UIGestureRecognizerStateBegan){self.panel.transform=CGAffineTransformIdentity;return;} if(pan.state==UIGestureRecognizerStateChanged){self.panel.transform=CGAffineTransformMakeTranslation(0,y);return;} if(pan.state==UIGestureRecognizerStateEnded||pan.state==UIGestureRecognizerStateCancelled){if(y>45||vy>260){[self closePage];}else{[UIView animateWithDuration:.22 delay:0 usingSpringWithDamping:.92 initialSpringVelocity:vy/1000 options:UIViewAnimationOptionCurveEaseOut animations:^{self.panel.transform=CGAffineTransformIdentity;} completion:nil];}} }
- (void)closePage { if(self.appearing||self.closing)return; self.closing=YES; [UIView animateWithDuration:.38 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{self.panel.transform=CGAffineTransformMakeTranslation(0,400);} completion:^(__unused BOOL f){if(self.closeHandler)self.closeHandler();}]; }
@end
