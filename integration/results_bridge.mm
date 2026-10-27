#import <UIKit/UIKit.h>
#include "results_bridge.hpp"
#include "ui_assets.hpp"
#include <mutex>
namespace { std::mutex resultMutex; BJRoundResult queued; bool pending=false; uint64_t lastQueued=0;
UILabel* label(NSString*s,CGFloat size){UILabel*l=[UILabel new];l.text=s;l.textColor=UIColor.whiteColor;l.textAlignment=NSTextAlignmentCenter;l.font=[UIFont boldSystemFontOfSize:size];l.adjustsFontSizeToFitWidth=YES;l.minimumScaleFactor=0.65;return l;}
NSString* number(int n){return [NSNumberFormatter localizedStringFromNumber:@(n) numberStyle:NSNumberFormatterDecimalStyle];}
}
int BJResultsPreviousBest(){NSString*p=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"Wireproof-Blitz.plist"];return MAX(0,[[NSDictionary dictionaryWithContentsOfFile:p][@"highScore"] intValue]);}
void BJResultsQueue(const BJRoundResult&r){std::lock_guard<std::mutex>l(resultMutex);if(r.generation==lastQueued)return;queued=r;pending=true;lastQueued=r.generation;}
@interface BJResultsPanel:UIView
@property(nonatomic,strong)UIView*canvas;
@property(nonatomic,copy)void(^again)(void);
@property(nonatomic,copy)void(^home)(void);
@property(nonatomic)BOOL leaving;
-(instancetype)initWithFrame:(CGRect)frame result:(BJRoundResult)r;
@end
@implementation BJResultsPanel
-(instancetype)initWithFrame:(CGRect)frame result:(BJRoundResult)r{if((self=[super initWithFrame:frame])){
 self.backgroundColor=[UIColor colorWithRed:0.12 green:0.03 blue:0.20 alpha:1];self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
 _canvas=[[UIView alloc]initWithFrame:CGRectMake(0,0,400,480)];[self addSubview:_canvas];
 UIImageView*bg=[[UIImageView alloc]initWithImage:[BJUIAsset(@"blitz-N_BoostBG.png") resizableImageWithCapInsets:UIEdgeInsetsMake(28,28,28,28) resizingMode:UIImageResizingModeStretch]];bg.frame=CGRectMake(5,4,390,472);[_canvas addSubview:bg];
 NSArray*texts=@[@"BLITZ RESULTS",r.score>r.previousBest?@"NEW PERSONAL BEST!":@"ROUND COMPLETE",number(r.score),[NSString stringWithFormat:@"PERSONAL BEST  %@",number(MAX(r.score,r.previousBest))],[NSString stringWithFormat:@"LAST HURRAH  +%@",number(r.lastHurrah)],[NSString stringWithFormat:@"HIGHEST MULTIPLIER  ×%d",r.maxMultiplier],@"BOOSTS EQUIPPED"];
 CGFloat ys[]={20,57,88,147,181,208,308};CGFloat sizes[]={25,15,43,14,17,17,13};
 for(NSUInteger i=0;i<texts.count;i++){UILabel*l=label(texts[i],sizes[i]);l.frame=CGRectMake(25,ys[i],350,i==2?52:27);if(i==1&&r.score>r.previousBest)l.textColor=[UIColor colorWithRed:1 green:0.86 blue:0.32 alpha:1];[_canvas addSubview:l];}
 UIImageView*line=[[UIImageView alloc]initWithImage:[BJUIAsset(@"blitz-N_GoldSeparator.png") resizableImageWithCapInsets:UIEdgeInsetsMake(0,3,0,3)]];line.frame=CGRectMake(30,176,340,3);[_canvas addSubview:line];
 const int personalBest=MAX(r.score,r.previousBest);const auto milestone=BJResultsMilestone(personalBest);
 UILabel*next=label(milestone.next?[NSString stringWithFormat:@"NEXT SCORE MILESTONE  %@",number(milestone.next)]:@"ALL SCORE MILESTONES REACHED",13);next.frame=CGRectMake(28,244,344,22);[_canvas addSubview:next];
 UIProgressView*progress=[[UIProgressView alloc]initWithProgressViewStyle:UIProgressViewStyleDefault];progress.frame=CGRectMake(42,273,316,6);progress.progressTintColor=[UIColor colorWithRed:1 green:0.78 blue:0.25 alpha:1];progress.trackTintColor=[UIColor colorWithWhite:0 alpha:0.4];progress.progress=milestone.progress;progress.accessibilityLabel=@"Personal best score milestone progress";progress.accessibilityValue=milestone.next?[NSString stringWithFormat:@"%@ of %@",number(personalBest),number(milestone.next)]:@"Complete";[_canvas addSubview:progress];
 UILabel*earned=label([NSString stringWithFormat:@"%d OF 19 MILESTONES REACHED",milestone.reached],11);earned.frame=CGRectMake(28,283,344,20);[_canvas addSubview:earned];
 NSArray*files=@[@"mystery_2x.png",@"detonator_2x.png",@"scrambler_2x.png",@"extratime_2x.png",@"multiplier_2x.png"];
 int count=__builtin_popcount(r.boosts&31),slot=0;for(int i=0;i<5;i++)if(r.boosts&(1u<<i)){UIImageView*v=[[UIImageView alloc]initWithImage:BJUIAsset(files[i])];v.contentMode=UIViewContentModeScaleAspectFit;v.frame=CGRectMake(200-count*28+slot++*56,339,50,58);[_canvas addSubview:v];}
 if(!count){UILabel*l=label(@"No boosts equipped",14);l.frame=CGRectMake(30,348,340,30);[_canvas addSubview:l];}
 UIButton*play=[UIButton buttonWithType:UIButtonTypeCustom];play.frame=CGRectMake(140,408,190,48);[play setBackgroundImage:BJUIAsset(@"blitz-N_Btn_General_Normal.png") forState:UIControlStateNormal];[play setBackgroundImage:BJUIAsset(@"blitz-N_Btn_General_Pressed.png") forState:UIControlStateHighlighted];[play setTitle:@"PLAY AGAIN" forState:UIControlStateNormal];play.titleLabel.font=[UIFont fontWithName:@"Georgia-Bold" size:19];[play addTarget:self action:@selector(replay) forControlEvents:UIControlEventTouchUpInside];[_canvas addSubview:play];
 UIButton*home=[UIButton buttonWithType:UIButtonTypeCustom];home.frame=CGRectMake(70,408,48,48);home.accessibilityLabel=@"Main menu";[home setBackgroundImage:BJUIAsset(@"blitz-N_Home_Button_Normal.png") forState:UIControlStateNormal];[home addTarget:self action:@selector(mainMenu) forControlEvents:UIControlEventTouchUpInside];[_canvas addSubview:home];
 }return self;}
-(void)replay{if(_leaving)return;_leaving=YES;void(^done)(void)=_again;_again=nil;_home=nil;[self removeFromSuperview];if(done)done();}
-(void)mainMenu{if(_leaving)return;_leaving=YES;void(^done)(void)=_home;_again=nil;_home=nil;[self removeFromSuperview];if(done)done();}
-(void)layoutSubviews{[super layoutSubviews];CGRect r=UIEdgeInsetsInsetRect(self.bounds,self.safeAreaInsets);r=CGRectInset(r,8,8);CGFloat s=MIN(r.size.width/400.0,r.size.height/480.0);_canvas.transform=CGAffineTransformMakeScale(s,s);_canvas.center=CGPointMake(CGRectGetMidX(r),CGRectGetMidY(r));}
@end
void BJResultsDrain(UIView*host,void(^again)(void),void(^home)(void)){if(!host||![NSThread isMainThread])return;for(UIView*v in host.subviews)if([v isKindOfClass:BJResultsPanel.class])return;BJRoundResult r;{std::lock_guard<std::mutex>l(resultMutex);if(!pending)return;r=queued;pending=false;}BJResultsPanel*p=[[BJResultsPanel alloc]initWithFrame:host.bounds result:r];p.again=again;p.home=home;[host addSubview:p];}
