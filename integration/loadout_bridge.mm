#import <UIKit/UIKit.h>
#include "loadout_bridge.hpp"
#include "ui_assets.hpp"
#include <atomic>
#include "../blitz-core/boost_runtime.hpp"
#include <mutex>
namespace {
std::mutex storageMutex;
std::atomic<uint32_t> selected{7};
int levels[5]={};
int best=0; bool loaded=false,dirty=false,savePending=false;
id backgroundObserver=nil;
NSString* path(){return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"Wireproof-Blitz.plist"];}
void load(){if(loaded)return;loaded=true;
 backgroundObserver=[NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(NSNotification*){BJLoadoutFlush();}];NSDictionary*d=[NSDictionary dictionaryWithContentsOfFile:path()];
 NSNumber*m=d[@"boostMask"];uint32_t mask=m?m.unsignedIntValue:7;
 if((mask&~31u)==0&&__builtin_popcount(mask)<=3)selected.store(mask);
 best=MAX(0,[d[@"highScore"] intValue]);
 NSArray*stored=d[@"boostLevels"];if([stored isKindOfClass:NSArray.class]&&stored.count==5)for(int i=0;i<5;i++)if([stored[i] isKindOfClass:NSNumber.class])levels[i]=std::clamp([stored[i] intValue],0,10);}
void save(){if(dirty&&[@{@"version":@2,@"boostLevels":@[@(levels[0]),@(levels[1]),@(levels[2]),@(levels[3]),@(levels[4])],@"boostMask":@(selected.load()),@"highScore":@(best)} writeToFile:path() atomically:YES])dirty=false;}
void schedule(){if(savePending)return;savePending=true;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{std::lock_guard<std::mutex>l(storageMutex);savePending=false;save();});}
}
extern "C" int BJLoadoutBoostLevel(int boost){std::lock_guard<std::mutex>l(storageMutex);load();return boost>=0&&boost<5?levels[boost]:0;}
extern "C" uint32_t BJLoadoutMask(){std::lock_guard<std::mutex>l(storageMutex);load();return selected.load();}
extern "C" void BJLoadoutRecordScore(int score){if(score<0)return;std::lock_guard<std::mutex>l(storageMutex);load();if(score>best){best=score;dirty=true;schedule();}}
extern "C" void BJLoadoutFlush(){std::lock_guard<std::mutex>l(storageMutex);if(loaded)save();}
static NSArray* BJNames(){return @[@"Mystery",@"Detonator",@"Scrambler",@"Extra Time",@"Multiplier"];}
static NSArray* BJFiles(){return @[@"mystery_2x.png",@"detonator_2x.png",@"scrambler_2x.png",@"extratime_2x.png",@"multiplier_2x.png"];}
static NSArray* BJHelp(){return @[@"Tap during play to create a surprise special gem. One use per round.",@"Detonate special gems. Two uses per round.",[NSString stringWithFormat:@"Reshuffle the board. %d uses per round.",blitz::BoostRuntime::scrambleUses(BJLoadoutBoostLevel(2))],@"Tap during play to add five seconds. One use per round.",[NSString stringWithFormat:@"Automatic: adds a multiplier gem at the start and every %d seconds. Match it to raise x1.",blitz::BoostRuntime::multiplierSeconds(BJLoadoutBoostLevel(4))]];}
static UILabel* BJLabel(NSString*text,CGFloat size){UILabel*l=[UILabel new];l.text=text;l.textColor=UIColor.whiteColor;l.textAlignment=NSTextAlignmentCenter;l.font=[UIFont boldSystemFontOfSize:size];l.shadowColor=[UIColor colorWithWhite:0 alpha:0.8];l.shadowOffset=CGSizeMake(0,1);l.adjustsFontSizeToFitWidth=YES;l.minimumScaleFactor=0.8;return l;}
@interface BJLoadoutPanel:UIView
@property(nonatomic,copy)void(^completion)(void);
@property(nonatomic,strong)UIView* canvas;
@property(nonatomic,strong)NSArray<UIButton*>* cards;
@property(nonatomic,strong)NSArray<UIButton*>* slots;
@property(nonatomic,strong)UILabel* summary;
@property(nonatomic,strong)UILabel* detail;
@property(nonatomic)uint32_t mask;
@end
@implementation BJLoadoutPanel
-(instancetype)initWithFrame:(CGRect)frame{if((self=[super initWithFrame:frame])){
 self.backgroundColor=[UIColor colorWithRed:0.12 green:0.03 blue:0.20 alpha:1.0];
 self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;_mask=BJLoadoutMask();
 _canvas=[[UIView alloc]initWithFrame:CGRectMake(0,0,400,480)];[self addSubview:_canvas];
 UIImage*panel=[BJUIAsset(@"blitz-N_BoostBG.png") resizableImageWithCapInsets:UIEdgeInsetsMake(28,28,28,28) resizingMode:UIImageResizingModeStretch];
 UIImageView*back=[[UIImageView alloc]initWithImage:panel];back.frame=CGRectMake(5,4,390,472);[_canvas addSubview:back];
 UILabel*title=BJLabel(@"EQUIP BOOSTS",23);title.frame=CGRectMake(20,16,360,28);[_canvas addSubview:title];
 _summary=BJLabel(@"",13);_summary.frame=CGRectMake(20,44,360,22);[_canvas addSubview:_summary];
 NSMutableArray*slots=[NSMutableArray array];for(int i=0;i<3;i++){UIButton*b=[UIButton buttonWithType:UIButtonTypeCustom];b.frame=CGRectMake(100+i*70,69,60,70);b.tag=-1;b.accessibilityLabel=@"Empty boost slot";[b setBackgroundImage:BJUIAsset(@"blitz-BoostUpgradeAnim_EmptySlot.png") forState:UIControlStateNormal];b.imageView.contentMode=UIViewContentModeScaleAspectFit;[b addTarget:self action:@selector(removeSlot:) forControlEvents:UIControlEventTouchUpInside];[_canvas addSubview:b];[slots addObject:b];}_slots=slots;
 UIImageView*line=[[UIImageView alloc]initWithImage:[BJUIAsset(@"blitz-N_GoldSeparator.png") resizableImageWithCapInsets:UIEdgeInsetsMake(0,3,0,3)]];line.frame=CGRectMake(22,145,356,4);[_canvas addSubview:line];
 UILabel*choose=BJLabel(@"CHOOSE UP TO 3 BOOSTS",14);choose.frame=CGRectMake(22,153,238,20);[_canvas addSubview:choose];
 UIButton*levelButton=[UIButton buttonWithType:UIButtonTypeSystem];levelButton.frame=CGRectMake(260,148,118,30);[levelButton setTitle:@"BOOST LEVELS" forState:UIControlStateNormal];[levelButton setTitleColor:UIColor.yellowColor forState:UIControlStateNormal];levelButton.titleLabel.font=[UIFont boldSystemFontOfSize:12];[levelButton addTarget:self action:@selector(showLevels) forControlEvents:UIControlEventTouchUpInside];[_canvas addSubview:levelButton];
 NSMutableArray*cards=[NSMutableArray array];for(int i=0;i<5;i++){UIButton*b=[UIButton buttonWithType:UIButtonTypeCustom];b.tag=i;b.accessibilityLabel=BJNames()[i];b.accessibilityHint=BJHelp()[i];
 UIImageView*icon=[[UIImageView alloc]initWithImage:BJUIAsset(BJFiles()[i])];icon.tag=101;icon.contentMode=UIViewContentModeScaleAspectFit;icon.frame=CGRectMake(6,0,68,79);[b addSubview:icon];
 UILabel*name=BJLabel(BJNames()[i],11);name.frame=CGRectMake(-4,80,88,18);[b addSubview:name];
 UIImageView*check=[[UIImageView alloc]initWithImage:BJUIAsset(@"blitz-Check_On.png")];check.frame=CGRectMake(55,58,23,23);check.tag=103;[b addSubview:check];
 b.frame=CGRectMake(i<3?60+i*100:110+(i-3)*100,i<3?178:276,80,98);[b addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventTouchUpInside];[_canvas addSubview:b];[cards addObject:b];}_cards=cards;
 _detail=BJLabel(@"Tap a boost to equip it. Tap again to remove it.",12);_detail.font=[UIFont systemFontOfSize:12 weight:UIFontWeightMedium];_detail.numberOfLines=2;_detail.frame=CGRectMake(27,375,346,32);[_canvas addSubview:_detail];
 UIButton*play=[UIButton buttonWithType:UIButtonTypeCustom];play.frame=CGRectMake(146,408,175.27,48);[play setBackgroundImage:BJUIAsset(@"blitz-N_Btn_General_Normal.png") forState:UIControlStateNormal];[play setBackgroundImage:BJUIAsset(@"blitz-N_Btn_General_Pressed.png") forState:UIControlStateHighlighted];[play setTitle:@"PLAY" forState:UIControlStateNormal];play.titleLabel.font=[UIFont fontWithName:@"Georgia-Bold" size:25];play.titleLabel.shadowOffset=CGSizeMake(0,2);[play setTitleShadowColor:UIColor.blackColor forState:UIControlStateNormal];[play addTarget:self action:@selector(start) forControlEvents:UIControlEventTouchUpInside];[_canvas addSubview:play];
 UIButton*cancel=[UIButton buttonWithType:UIButtonTypeCustom];cancel.frame=CGRectMake(78,408,48,48);cancel.accessibilityLabel=@"Back to main menu";[cancel setBackgroundImage:BJUIAsset(@"blitz-N_Home_Button_Normal.png") forState:UIControlStateNormal];[cancel addTarget:self action:@selector(cancelled) forControlEvents:UIControlEventTouchUpInside];[_canvas addSubview:cancel];[self refresh];}return self;}
-(void)refresh{int high;{std::lock_guard<std::mutex>l(storageMutex);load();high=best;}
 _summary.text=[NSString stringWithFormat:@"BEST %@   •   %d / 3 EQUIPPED",[NSNumberFormatter localizedStringFromNumber:@(high) numberStyle:NSNumberFormatterDecimalStyle],__builtin_popcount(_mask)];
 int slot=0;for(UIButton*b in _cards){BOOL on=(_mask&(1u<<b.tag))!=0;[b viewWithTag:101].alpha=on?1:0.65;[b viewWithTag:103].hidden=!on;b.accessibilityValue=on?@"Equipped":@"Not equipped";if(on){UIButton*s=_slots[slot++];s.tag=b.tag;[s setImage:BJUIAsset(BJFiles()[b.tag]) forState:UIControlStateNormal];s.accessibilityLabel=[NSString stringWithFormat:@"Remove %@",BJNames()[b.tag]];}}
 while(slot<3){UIButton*s=_slots[slot++];s.tag=-1;[s setImage:nil forState:UIControlStateNormal];s.accessibilityLabel=@"Empty boost slot";}}
-(void)toggle:(UIButton*)b{uint32_t bit=1u<<b.tag;if(_mask&bit)_mask&=~bit;else if(__builtin_popcount(_mask)<3)_mask|=bit;else{_detail.text=@"Three boosts equipped. Remove one to choose another.";return;}_detail.text=[NSString stringWithFormat:@"%@: %@",BJNames()[b.tag],BJHelp()[b.tag]];[self refresh];}
-(void)removeSlot:(UIButton*)b{if(b.tag<0)return;_mask&=~(1u<<b.tag);_detail.text=@"Boost removed. Choose another below.";[self refresh];}
-(void)showLevels{
 UIView*panel=[[UIView alloc]initWithFrame:_canvas.bounds];panel.tag=909;panel.backgroundColor=[UIColor colorWithRed:0.12 green:0.03 blue:0.20 alpha:1];[_canvas addSubview:panel];
 UILabel*t=BJLabel(@"BOOST LEVELS",24);t.frame=CGRectMake(20,35,360,36);[panel addSubview:t];
 UILabel*intro=BJLabel(@"Choose a level for your next round.\nAll levels available offline.",14);intro.numberOfLines=2;intro.frame=CGRectMake(24,80,352,48);[panel addSubview:intro];
 for(int row=0;row<2;row++){int boost=row?4:2;CGFloat y=155+row*108;
 UIImageView*icon=[[UIImageView alloc]initWithImage:BJUIAsset(BJFiles()[boost])];icon.contentMode=UIViewContentModeScaleAspectFit;icon.frame=CGRectMake(28,y,54,64);[panel addSubview:icon];
 UILabel*l=BJLabel(@"",16);l.tag=920+boost;l.numberOfLines=2;l.frame=CGRectMake(85,y,220,65);[panel addSubview:l];
 for(int direction=0;direction<2;direction++){UIButton*b=[UIButton buttonWithType:UIButtonTypeSystem];b.tag=boost*10+direction;b.frame=CGRectMake(306+direction*38,y+8,36,50);[b setTitle:direction?@"+":@"−" forState:UIControlStateNormal];b.titleLabel.font=[UIFont boldSystemFontOfSize:28];[b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];[b addTarget:self action:@selector(changeLevel:) forControlEvents:UIControlEventTouchUpInside];[panel addSubview:b];}}
 UIButton*done=[UIButton buttonWithType:UIButtonTypeCustom];done.frame=CGRectMake(110,398,180,48);[done setBackgroundImage:BJUIAsset(@"blitz-N_Btn_General_Normal.png") forState:UIControlStateNormal];[done setTitle:@"DONE" forState:UIControlStateNormal];done.titleLabel.font=[UIFont boldSystemFontOfSize:22];[done addTarget:self action:@selector(closeLevels) forControlEvents:UIControlEventTouchUpInside];[panel addSubview:done];[self refreshLevels];}
-(void)refreshLevels{UIView*p=[_canvas viewWithTag:909];for(int boost:{2,4}){int level=BJLoadoutBoostLevel(boost);UILabel*l=(UILabel*)[p viewWithTag:920+boost];l.text=boost==2?[NSString stringWithFormat:@"Scrambler · Level %d\n%d uses per round",level+1,blitz::BoostRuntime::scrambleUses(level)]:[NSString stringWithFormat:@"Multiplier · Level %d\nEvery %d seconds",level+1,blitz::BoostRuntime::multiplierSeconds(level)];}}
-(void)changeLevel:(UIButton*)b{int boost=int(b.tag)/10,delta=b.tag%10?1:-1;{std::lock_guard<std::mutex>l(storageMutex);load();levels[boost]=std::clamp(levels[boost]+delta,0,10);dirty=true;save();}[self refreshLevels];}
-(void)closeLevels{[[_canvas viewWithTag:909] removeFromSuperview];[self refresh];}
-(void)start{{std::lock_guard<std::mutex>l(storageMutex);selected.store(_mask);dirty=true;save();}void(^done)(void)=self.completion;self.completion=nil;[self removeFromSuperview];if(done)done();}
-(void)cancelled{self.completion=nil;[self removeFromSuperview];}
-(void)layoutSubviews{[super layoutSubviews];CGRect r=CGRectInset(self.bounds,8,12);CGFloat scale=MIN(r.size.width/400.0,r.size.height/480.0);_canvas.transform=CGAffineTransformMakeScale(scale,scale);_canvas.center=CGPointMake(CGRectGetMidX(r),CGRectGetMidY(r));}
@end
void BJLoadoutPresent(UIView*host,void(^completion)(void)){if(!host)return;for(UIView*v in host.subviews)if([v isKindOfClass:BJLoadoutPanel.class])return;BJLoadoutPanel*p=[[BJLoadoutPanel alloc]initWithFrame:host.bounds];p.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;p.completion=completion;[host addSubview:p];}
