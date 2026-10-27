#import <UIKit/UIKit.h>
#include "classic_daily_bridge.hpp"
#include "../blitz-core/daily_limits.hpp"
#include "../evidence/blitz-bridge-plan/native_primitives.hpp"
#include <atomic>
#include <cstring>
#include <mutex>

namespace {
classic::DailyLimits quota;
bool loaded=false;
std::int64_t lastSaved=0;
std::uintptr_t lastBoard=0;
std::uint64_t generation=0;
std::mutex stateMutex;
struct Rect {int x=0,y=0,w=0,h=0;};
struct Snapshot {bool show=false,enabled=false;std::uint64_t generation=0;Rect rect[2];int count[2]={10,10};std::int64_t wait[2]={0,0};};
Snapshot snapshot;
struct Command {std::uint64_t generation;unsigned tool;};
std::vector<Command> commands;
UIView *overlay=nil;
NSArray<UIButton*> *controls=nil;
std::uint64_t uiGeneration=0;
UILabel *toast=nil;
std::uint64_t toastSerial=0;
void showMessage(NSString *message){
 if(!overlay||overlay.hidden)return;
 if(!toast||toast.superview!=overlay){toast=[UILabel new];toast.userInteractionEnabled=NO;toast.textAlignment=NSTextAlignmentCenter;toast.numberOfLines=2;toast.font=[UIFont boldSystemFontOfSize:15];toast.textColor=UIColor.whiteColor;toast.backgroundColor=[UIColor colorWithWhite:0.05 alpha:0.92];toast.layer.cornerRadius=12;toast.clipsToBounds=YES;[overlay addSubview:toast];}
 toast.frame=CGRectMake(overlay.bounds.size.width*.1,overlay.bounds.size.height*.20,overlay.bounds.size.width*.8,64);toast.text=message;toast.hidden=NO;const auto serial=++toastSerial;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),dispatch_get_main_queue(),^{if(serial==toastSerial)toast.hidden=YES;});
}
bool hasNormalPiece(void*board,std::uintptr_t slide){
 bejeweled_private::NativePrimitives api(slide);
 if(!api.compatibleEntrypoints())return false;
 auto*b=static_cast<bejeweled_private::Board*>(board);
 for(int row=0;row<8;++row)for(int col=0;col<8;++col){
  auto*p=api.piece(b,row,col);if(!p||!api.still(b,p))continue;
  std::uint32_t flags;unsigned char selectable;
  std::memcpy(&flags,reinterpret_cast<const char*>(p)+0x750,4);
  std::memcpy(&selectable,reinterpret_cast<const char*>(p)+0x55f,1);
  if(flags==0&&selectable==1)return true;
 }
 return false;
}
constexpr NSString *storageKey=@"Wireproof.Classic.RollingDailyLimits.v1";
template<class T>T read(const void*p,std::size_t offset){T result;std::memcpy(&result,static_cast<const char*>(p)+offset,sizeof result);return result;}
void load(){
 if(loaded)return;loaded=true;
 NSDictionary *d=[NSUserDefaults.standardUserDefaults dictionaryForKey:storageKey];
 if(!d)return;
 id high=d[@"highWater"];if([high isKindOfClass:NSNumber.class])quota.highWater=[high longLongValue];
 NSArray *histories=d[@"spent"];
 if([histories isKindOfClass:NSArray.class]&&histories.count==2)for(unsigned i=0;i<2;++i){
  id h=histories[i];if(![h isKindOfClass:NSArray.class])continue;
  for(id n in h)if([n isKindOfClass:NSNumber.class])quota.spent[i].push_back([n longLongValue]);
 }
}
void save(){
 NSMutableArray *histories=[NSMutableArray new];
 for(const auto&h:quota.spent){NSMutableArray*a=[NSMutableArray new];for(auto t:h)[a addObject:@(t)];[histories addObject:a];}
 [NSUserDefaults.standardUserDefaults setObject:@{@"highWater":@(quota.highWater),@"spent":histories} forKey:storageKey];
 // Persist before applying the native action, so app restart does not grant
 // another charge. No writes to the original game profile or purchases.
 [NSUserDefaults.standardUserDefaults synchronize];lastSaved=quota.highWater;
}
bool compatible(std::uintptr_t slide){
 return read<std::uint32_t>((void*)(slide+0x10018eaf4),0)==0x52800041&&
 read<std::uint32_t>((void*)(slide+0x10018fc2c),0)==0xa9be4ff4&&
 read<std::uint32_t>((void*)(slide+0x10015b034),0)==0xa9bd57f6&&
 read<std::uint32_t>((void*)(slide+0x10015ae8c),0)==0x52840808;
}
}
@interface BJClassicDailyOverlay:UIView
@end
@implementation BJClassicDailyOverlay
-(BOOL)pointInside:(CGPoint)p withEvent:(UIEvent*)event {
 (void)event;for(UIView*c in self.subviews)if(!c.hidden&&c.userInteractionEnabled&&CGRectContainsPoint(c.frame,p))return YES;return NO;
}
@end
@interface BJClassicDailyControl:NSObject
+(void)pressed:(UIButton*)sender;
@end
@implementation BJClassicDailyControl
+(void)pressed:(UIButton*)sender {
 std::lock_guard<std::mutex> guard(stateMutex);
 if(!snapshot.show||snapshot.generation!=uiGeneration||sender.tag<0||sender.tag>=2)return;
 if(snapshot.count[sender.tag]==0){
  auto minutes=(snapshot.wait[sender.tag]+59)/60;
  showMessage([NSString stringWithFormat:@"10 uses per 24 hours\nNext use in %lldh %02lldm",minutes/60,minutes%60]);return;
 }
 if(!snapshot.enabled){showMessage(@"Wait for the gems to settle");return;}
 if(commands.empty())commands.push_back({snapshot.generation,static_cast<unsigned>(sender.tag)});
}
@end
extern "C" void BJClassicDailyObserve(void*board,std::uintptr_t slide){
 Snapshot next;
 const auto identity=reinterpret_cast<std::uintptr_t>(board);
 if(identity!=lastBoard){lastBoard=identity;++generation;}
 next.generation=generation;
 std::vector<Command> pending;
 {std::lock_guard<std::mutex> guard(stateMutex);pending.swap(commands);}
 if(board&&compatible(slide)){
  const auto vt=read<std::uintptr_t>(board,0);
  // Exact Classic RTTI only: Zen, Lightning/Blitz and all other modes retain
  // their native behavior. No board pointer is retained for a UIKit callback.
  if(vt&&!(vt&7)&&read<std::uintptr_t>((void*)(vt-8),0)==slide+0x1029cc668){
   auto isPaused=reinterpret_cast<bool(*)(void*)>(slide+0x10015b034);
   auto suspended=reinterpret_cast<bool(*)(void*)>(slide+0x10015ae8c);
   auto canInteract=reinterpret_cast<bool(*)(void*)>(read<std::uintptr_t>((void*)vt,0x7c8));
   next.show=!isPaused(board)&&!suspended(board)&&!read<unsigned char>(board,0x76)&&!read<unsigned char>(board,0x36e0);
   // Pause/options drawers do not always set Board::IsGamePaused.
   void*app=read<void*>((void*)(slide+0x102fa7090),0);
   if(app){
    // Saved-game confirmation is a modal dialog, not a pause/options drawer.
    if(reinterpret_cast<int(*)(void*)>(slide+0x100d0b82c)(app)>0 || !read<unsigned char>(board,0x74))next.show=false;
    const int hiddenY=read<int>((void*)(slide+0x102fab3fc),0);
    for(std::size_t offset:{0xaf0,0xb00,0xb60}){void*menu=read<void*>(app,offset);
     if(menu&&read<unsigned char>(menu,0x74)&&(read<int>(menu,0x54)<hiddenY||read<int>(menu,0x120)<hiddenY))next.show=false;}
   }
   next.enabled=next.show&&!suspended(board)&&!read<unsigned char>(board,0x36e0)&&canInteract(board);
   load();const auto now=static_cast<std::int64_t>(NSDate.date.timeIntervalSince1970);
   // Index 0 is Mystery/supertool; index 1 is Shuffle/tool.
   for(auto command:pending)if(next.enabled&&command.generation==generation&&command.tool<2){
    // Recheck suspension after each command, never queue actions through pause.
    if(!suspended(board)&&(command.tool!=0||hasNormalPiece(board,slide))&&quota.consume(command.tool,now)){
     save();reinterpret_cast<void(*)(void*)>(slide+(command.tool?0x10018eaf4:0x10018fc2c))(board);
    }else if(command.tool==0){
     const auto expected=generation;
     dispatch_async(dispatch_get_main_queue(),^{if(uiGeneration==expected)showMessage(@"No settled normal gem available\nYour daily use was not spent");});
    }
   }
   for(unsigned i=0;i<2;++i){
    next.count[i]=quota.remaining(i,now);next.wait[i]=quota.untilNext(i,now);
    void*b=read<void*>(board,i?0x7130:0x7138);
    if(!b){next.show=false;continue;}
    next.rect[i]={read<int>(board,0x50)+read<int>(b,0x50),read<int>(board,0x54)+read<int>(b,0x54),read<int>(b,0x58),read<int>(b,0x5c)};
    if(next.rect[i].w<=0||next.rect[i].h<=0||next.rect[i].w>300||next.rect[i].h>300)next.show=false;
   }
   if(quota.highWater-lastSaved>=60)save();
  }
 }
 std::lock_guard<std::mutex> guard(stateMutex);snapshot=next;
}
extern "C" void BJClassicDailyLayout(void*gameView,int width,int height){
 if(!NSThread.isMainThread)return;
 UIView*view=(__bridge UIView*)gameView;Snapshot s;
 {std::lock_guard<std::mutex>guard(stateMutex);s=snapshot;}
 if(!s.show||!view.window||width<=0||height<=0||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive){overlay.hidden=YES;return;}
 if(!overlay||overlay.superview!=view.window){
  [overlay removeFromSuperview];overlay=[[BJClassicDailyOverlay alloc]initWithFrame:view.window.bounds];
  overlay.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
  NSMutableArray*a=[NSMutableArray new];
  for(unsigned i=0;i<2;++i){
   UIButton*b=[UIButton buttonWithType:UIButtonTypeCustom];b.tag=i;
   b.accessibilityLabel=i?@"Shuffle":@"Mystery gem";
   [b addTarget:BJClassicDailyControl.class action:@selector(pressed:) forControlEvents:UIControlEventTouchUpInside];
   UILabel*label=[UILabel new];label.tag=100;label.textAlignment=NSTextAlignmentCenter;label.textColor=UIColor.whiteColor;
   label.backgroundColor=[UIColor colorWithRed:0.05 green:0.11 blue:0.30 alpha:1];label.layer.cornerRadius=5;label.clipsToBounds=YES;
   label.font=[UIFont boldSystemFontOfSize:13];[b addSubview:label];[overlay addSubview:b];[a addObject:b];
  }
  controls=a;[view.window addSubview:overlay];
 }
 uiGeneration=s.generation;overlay.hidden=NO;
 for(unsigned i=0;i<2;++i){
  auto r=s.rect[i];const CGFloat sx=view.bounds.size.width/width,sy=view.bounds.size.height/height;
  // Covers native touch region and its lower-right count. Native artwork stays
  // rendered; the compact opaque count badge replaces the old purchase count.
  CGRect nativeRect=CGRectMake(r.x*sx,r.y*sy,r.w*sx,r.h*1.18*sy);
  UIButton*b=controls[i];b.frame=[view convertRect:nativeRect toView:overlay];
  UILabel*l=(UILabel*)[b viewWithTag:100];l.frame=CGRectMake(b.bounds.size.width*.62,b.bounds.size.height*.66,b.bounds.size.width*.40,b.bounds.size.height*.34);
  l.text=[NSString stringWithFormat:@"%d",s.count[i]];
  l.alpha=s.count[i]>0?1:0.65;
  b.accessibilityValue=[NSString stringWithFormat:@"%d of 10 uses available in the last 24 hours",s.count[i]];
  b.accessibilityHint=s.count[i]>0?@"Each use returns after 24 real-time hours":[NSString stringWithFormat:@"Next use returns in %lld minutes",(s.wait[i]+59)/60];
 }
}
