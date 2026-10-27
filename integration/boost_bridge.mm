#import <UIKit/UIKit.h>
#include "ui_assets.hpp"
#include "loadout_bridge.hpp"
#include "boost_bridge.hpp"
#include "round_bridge.hpp"
#include "../blitz-core/boost_core.hpp"
#include "../evidence/blitz-bridge-plan/native_primitives.hpp"
#include <algorithm>
#include <atomic>
#include <cstring>
#include <mutex>
#include <vector>

namespace {
using namespace bejeweled_private;
using blitz::Boost; using blitz::Event;
std::mutex queueMutex;
struct Command { std::uint64_t generation; Boost boost; };
std::vector<Command> queue;
std::atomic<std::uint64_t> visibleGeneration{0};
std::uintptr_t imageSlide=0;
std::uint64_t currentGeneration=0;
bool entrypointsValid=false,started=false;
std::int64_t previousTicks=0;
int detonatorUses=0,scramblerUses=0;
bool lastActive=false;
uint32_t loadoutMask=7;
bool equipped(Boost b){return (loadoutMask&(1u<<static_cast<unsigned>(b)))!=0;}
int lastShownDetonator=-1,lastShownScrambler=-1;
std::vector<blitz::GemSet> deferredConversions;
blitz::DefaultBoost mystery(Boost::Mystery),detonator(Boost::Detonator),scrambler(Boost::Scrambler),extra(Boost::ExtraTime),multiplier(Boost::Multiplier);
UIView* overlay=nil;
struct BoostRect {int x=0,y=0,w=0,h=0;};
std::mutex geometryMutex;
BoostRect toolRect,superRect;
bool haveGeometry=false;
void captureControls(void* board) {
 BoostRect rects[2];
 for(int i=0;i<2;++i){
  void* button=nullptr;std::memcpy(&button,static_cast<char*>(board)+(i?0x7138:0x7130),sizeof button);
  if(!button)return;
  auto get=[&](void*p,size_t o){int v;std::memcpy(&v,static_cast<char*>(p)+o,4);return v;};
  rects[i]={get(board,0x50)+get(button,0x50),get(board,0x54)+get(button,0x54),get(button,0x58),get(button,0x5c)};
  // Native Widget setters preserve ownership and normal update/destruction.
  reinterpret_cast<void(*)(void*,bool)>(imageSlide+0x100ed0568)(button,false);
  reinterpret_cast<void(*)(void*,bool)>(imageSlide+0x100ed0c6c)(button,true);
 }
 std::lock_guard<std::mutex> lock(geometryMutex);
 toolRect=rects[0];superRect=rects[1];haveGeometry=true;
}
UIButton *detonateButton=nil,*scrambleButton=nil;

template<class T> T field(const void* p,std::size_t offset) {
 T value{};std::memcpy(&value,static_cast<const char*>(p)+offset,sizeof(value));return value;
}
// Each adapter owns a live board only for this synchronous game callback.
class Adapter final: public blitz::BoardAdapter {
 Board* board_; NativePrimitives api_;
 std::vector<Piece*> eligible(bool special) const {
  std::vector<Piece*> out;
  for(int row=0;row<8;++row)for(int col=0;col<8;++col) {
   auto p=api_.piece(board_,row,col);if(!p||!api_.still(board_,p))continue;
   auto flags=field<std::uint32_t>(p,0x750);
   if(special?(flags&7)!=0:flags==0)out.push_back(p);
  }
  return out;
 }
public:
 explicit Adapter(void* board):board_(static_cast<Board*>(board)),api_(imageSlide){}
 int actionRandomInt(int a,int b) override {
  // Experimental independent RNG; does not consume native game's seeded stream.
  return a+static_cast<int>(arc4random_uniform(static_cast<std::uint32_t>(b-a)));
 }
 int detonatableGemCount() const override {return static_cast<int>(eligible(true).size());}
 void convertRandomGems(blitz::GemSet,blitz::GemSet to,int count) override {
  for(int i=0;i<count;++i){auto candidates=eligible(false);if(candidates.empty()){
    // Initial fill and cascades can have no settled pieces. Preserve the
    // requested effect without retaining native piece or board pointers.
    if(deferredConversions.size()<8)deferredConversions.push_back(to);
    continue;
   }
   auto p=candidates[arc4random_uniform(static_cast<std::uint32_t>(candidates.size()))];
   if(to==blitz::GemSet::Multiplier) {
    // Board::Blastify(Piece*), verified entry 0x395d5828.
    using Fn=void(*)(Board*,Piece*);
    reinterpret_cast<Fn>(imageSlide+0x100165990)(board_,p);
   } else switch(arc4random_uniform(3)) {
    case 0:api_.flame(board_,p);break;
    case 1:api_.hypercube(board_,p,true);break;
    default:api_.laser(board_,p);break;
   }
  }
 }
 void retryConversions() {
  auto pending=std::move(deferredConversions);deferredConversions.clear();
  for(auto to:pending)convertRandomGems(blitz::GemSet::Normal,to,1);
 }
 void scrambleGems() override {api_.scramble(board_);}
 void increaseBlazingSpeed(int) override { /* No verified compatible field: do not write. */ }
 void addExtraTimeAtGameEnd(int ticks) override {BJRoundAddTimeTicks(board_,ticks);}
 void increaseScoreDelta(int) override { /* Extra-period score API remains unresolved. */ }
 void increaseMultiplierWithDetonateDuration(int) override {
  // Native TriggerSpecial gives native effects/scoring. Blitz's temporary bonus
  // duration is unresolved and is deliberately not approximated by a permanent multiplier.
  for(int row=0;row<8;++row)for(int col=0;col<8;++col) {
   // Re-read cell and state each time: an earlier effect may change later cells.
   auto p=api_.piece(board_,row,col);
   if(p&&api_.still(board_,p)&&(field<std::uint32_t>(p,0x750)&7))api_.trigger(board_,p);
  }
 }
};
void refreshButtons(std::uint64_t generation) {
 const int d=2-detonatorUses,s=2-scramblerUses;
 if(d==lastShownDetonator&&s==lastShownScrambler)return;
 lastShownDetonator=d;lastShownScrambler=s;
 dispatch_async(dispatch_get_main_queue(),^{
  if(visibleGeneration.load()!=generation)return;
  ((UILabel*)[detonateButton viewWithTag:100]).text=[NSString stringWithFormat:@"%d",d];
  ((UILabel*)[scrambleButton viewWithTag:100]).text=[NSString stringWithFormat:@"%d",s];
  detonateButton.accessibilityValue=[NSString stringWithFormat:@"%d uses remaining",d];
  scrambleButton.accessibilityValue=[NSString stringWithFormat:@"%d uses remaining",s];
  detonateButton.alpha=d>0?1.0:0.4;scrambleButton.alpha=s>0?1.0:0.4;
  detonateButton.enabled=d>0;scrambleButton.enabled=s>0;
 });
}
}

@interface BJBoostOverlay : UIView
@end
@implementation BJBoostOverlay
-(BOOL)pointInside:(CGPoint)point withEvent:(UIEvent*)event {
 (void)event;
 for(UIView *child in self.subviews)
  if(!child.hidden && child.userInteractionEnabled && CGRectContainsPoint(child.frame,point))return YES;
 return NO;
}
@end

@interface BJBoostControl : NSObject
+ (void)pressed:(UIButton*)sender;
@end
@implementation BJBoostControl
+ (void)pressed:(UIButton*)sender {
 auto generation=visibleGeneration.load();if(!generation)return;
 std::lock_guard<std::mutex> lock(queueMutex);
 if(queue.size()<8)queue.push_back({generation,sender.tag==1?Boost::Detonator:Boost::Scrambler});
}
@end

namespace {
void displayOverlay(std::uint64_t generation) {
 dispatch_async(dispatch_get_main_queue(),^{
  if(visibleGeneration.load()!=generation)return;
  [overlay removeFromSuperview];overlay=nil;
  UIWindow* window=nil;
  for(UIScene* scene in UIApplication.sharedApplication.connectedScenes)
   if([scene isKindOfClass:UIWindowScene.class]&&scene.activationState==UISceneActivationStateForegroundActive)
    for(UIWindow* candidate in ((UIWindowScene*)scene).windows)if(candidate.isKeyWindow)window=candidate;
  // Original game is an app-delegate-era UIKit app; it may have no scenes.
  if(!window&&[UIApplication.sharedApplication.delegate respondsToSelector:@selector(window)])
   window=UIApplication.sharedApplication.delegate.window;
  if(!window){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
   for(UIWindow* candidate in UIApplication.sharedApplication.windows)
    if(candidate.isKeyWindow)window=candidate;
#pragma clang diagnostic pop
  }
  if(!window)return;
  overlay=[[BJBoostOverlay alloc]initWithFrame:window.bounds];overlay.hidden=YES;
  overlay.backgroundColor=UIColor.clearColor;
  overlay.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
  detonateButton=[UIButton buttonWithType:UIButtonTypeCustom];scrambleButton=[UIButton buttonWithType:UIButtonTypeCustom];
  NSArray<UIButton*>* controls=@[detonateButton,scrambleButton];
  for(NSUInteger i=0;i<controls.count;++i){
   UIButton* b=controls[i];b.tag=i+1;
   b.hidden=!equipped(i==0?Boost::Detonator:Boost::Scrambler);
   b.accessibilityLabel=i==0?@"Detonator":@"Scrambler";
   UIImageView* icon=[[UIImageView alloc]initWithImage:BJUIAsset(i==0?@"detonator_2x.png":@"scrambler_2x.png")];
   icon.contentMode=UIViewContentModeScaleAspectFit;icon.frame=b.bounds;
   icon.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
   [b addSubview:icon];
   UILabel* count=[UILabel new];count.tag=100;count.text=@"2";count.textColor=UIColor.whiteColor;
   count.font=[UIFont boldSystemFontOfSize:15];count.textAlignment=NSTextAlignmentCenter;
   count.layer.shadowColor=UIColor.blackColor.CGColor;count.layer.shadowOpacity=1;count.layer.shadowRadius=2;
   count.layer.shadowOffset=CGSizeMake(0,1);count.translatesAutoresizingMaskIntoConstraints=NO;
   [b addSubview:count];[NSLayoutConstraint activateConstraints:@[
    [count.centerXAnchor constraintEqualToAnchor:b.centerXAnchor],
    [count.bottomAnchor constraintEqualToAnchor:b.bottomAnchor constant:0]]];
   [b addTarget:BJBoostControl.class action:@selector(pressed:) forControlEvents:UIControlEventTouchUpInside];
   [overlay addSubview:b];
  }
  [window addSubview:overlay];
 });
}
}

extern "C" bool BJBoostCompatible(std::uintptr_t slide) {
 NativePrimitives api(slide);
 return api.compatibleEntrypoints()&&field<std::uint32_t>(reinterpret_cast<void*>(slide+0x100165990),0)==0x395d5828;
}
extern "C" void BJBoostBegin(std::uintptr_t slide,std::uint64_t generation) {
 loadoutMask=BJLoadoutMask();imageSlide=slide;currentGeneration=generation;started=false;previousTicks=0;detonatorUses=scramblerUses=0;
 {std::lock_guard<std::mutex> lock(geometryMutex);haveGeometry=false;}
 lastActive=false;lastShownDetonator=lastShownScrambler=-1;
 mystery.reset();detonator.reset();scrambler.reset();extra.reset();multiplier.reset();
 deferredConversions.clear();
 entrypointsValid=BJBoostCompatible(slide);
 {std::lock_guard<std::mutex> lock(queueMutex);queue.clear();}
 visibleGeneration.store(entrypointsValid?generation:0);
 if(entrypointsValid)displayOverlay(generation);
}
extern "C" void BJBoostUpdate(void* board,std::uint64_t generation,bool active,std::int64_t elapsedTicks) {
 if(!board||!entrypointsValid||generation!=currentGeneration)return;
 captureControls(board);
 if(active!=lastActive){lastActive=active;dispatch_async(dispatch_get_main_queue(),^{if(visibleGeneration.load()==generation)overlay.hidden=!active;});}
 if(!active){std::lock_guard<std::mutex> lock(queueMutex);queue.clear();return;}
 Adapter adapter(board);
 if(!started){started=true;previousTicks=elapsedTicks;if(equipped(Boost::ExtraTime))extra.activate(Event::GameBegin,adapter);if(equipped(Boost::Multiplier))multiplier.compute(Event::GameBegin,adapter);}
 adapter.retryConversions();
 // Round bridge supplies elapsed native centiseconds. Paused callbacks do not advance.
 auto delta=std::clamp<std::int64_t>(elapsedTicks-previousTicks,0,1000);previousTicks=elapsedTicks;
 for(std::int64_t i=0;equipped(Boost::Multiplier)&&i<delta;++i){multiplier.compute(Event::TimeTick,adapter);multiplier.activate(Event::TimeTick,adapter);}
 std::vector<Command> pending;{std::lock_guard<std::mutex> lock(queueMutex);pending.swap(queue);}
 for(auto c:pending)if(c.generation==generation){
  if(equipped(Boost::Detonator)&&c.boost==Boost::Detonator&&detonatorUses<2){detonator.compute(Event::Click,adapter);if(detonator.activate(Event::Click,adapter))++detonatorUses;}
  if(equipped(Boost::Scrambler)&&c.boost==Boost::Scrambler&&scramblerUses<2){if(scrambler.activate(Event::Click,adapter))++scramblerUses;}
 }
 refreshButtons(generation);
}
extern "C" void BJBoostMatch(void* board,std::uint64_t generation) {
 if(!board||!entrypointsValid||!started||generation!=currentGeneration)return;
 Adapter adapter(board);if(equipped(Boost::Detonator))detonator.compute(Event::Match,adapter);if(equipped(Boost::Mystery))mystery.activate(Event::Match,adapter);
}
extern "C" void BJBoostEnd(std::uint64_t generation) {
 if(generation!=currentGeneration)return;
 currentGeneration=0;entrypointsValid=false;started=false;visibleGeneration.store(0);
 deferredConversions.clear();
 {std::lock_guard<std::mutex> lock(queueMutex);queue.clear();}
 dispatch_async(dispatch_get_main_queue(),^{if(!visibleGeneration.load()){[overlay removeFromSuperview];overlay=nil;detonateButton=nil;scrambleButton=nil;}});
}

extern "C" void BJBoostLayout(void* gameView,int width,int height) {
 UIView *view=(__bridge UIView*)gameView;
 if(!overlay||!view.window||width<=0||height<=0)return;
 BoostRect rects[2];{
  std::lock_guard<std::mutex> lock(geometryMutex);
  if(!haveGeometry)return;
  rects[0]=toolRect;rects[1]=superRect;
 }
 // Scrambler replaces the left native tool, Detonator the middle tool.
 UIButton* buttons[2]={scrambleButton,detonateButton};
 for(int i=0;i<2;++i){
  auto r=rects[i];if(r.w<=0||r.h<=0)continue;
  CGRect gameRect=CGRectMake(r.x*view.bounds.size.width/width,r.y*view.bounds.size.height/height,
   r.w*view.bounds.size.width/width,r.h*view.bounds.size.height/height);
  CGRect hostRect=[view convertRect:gameRect toView:overlay];
  if(!CGRectEqualToRect(buttons[i].frame,hostRect))buttons[i].frame=hostRect;
 }
}
