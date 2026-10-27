extern "C" void BJPresentationSetMenuVisible(bool visible);
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#include <atomic>
#include <cstdint>
#include <cstring>
#include <cmath>
#include "round_bridge.hpp"
#include "ui_assets.hpp"
#include "loadout_bridge.hpp"
extern "C" void BJBoostLayout(void*,int,int);
extern "C" void BJHUDObserve(void*,std::uintptr_t);

extern "C" bool BJPresentationInstall();
extern "C" void BJPresentationRefresh(void*);
namespace {
uintptr_t slide;
IMP originalMain, originalTimer;
std::atomic<bool> ready{false}, pending{false};
thread_local unsigned depth;
__weak UIWindow *lastWindow;
UIButton *blitzButton;
id buttonTarget;
std::atomic<unsigned> logCount{0};
void logEvent(NSString *event) {
  if(logCount.fetch_add(1)>=64)return;
  static NSObject *lock; static dispatch_once_t once;
  dispatch_once(&once,^{lock=[NSObject new];});
  @synchronized(lock) {
    NSString *dir=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
    if(!dir)return;
    NSString *path=[dir stringByAppendingPathComponent:@"Bejeweled-Bridge.log"];
    NSFileManager *fm=NSFileManager.defaultManager;
    unsigned long long size=[[fm attributesOfItemAtPath:path error:nil] fileSize];
    if(size>16384)[fm removeItemAtPath:path error:nil];
    if(![fm fileExistsAtPath:path])[fm createFileAtPath:path contents:nil attributes:nil];
    NSFileHandle *handle=[NSFileHandle fileHandleForWritingAtPath:path];
    @try {
      [handle seekToEndOfFile];
      NSString *line=[NSString stringWithFormat:@"%.3f %@\n",NSDate.date.timeIntervalSince1970,event];
      [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
      [handle closeFile];
    } @catch(NSException *exception) { (void)exception; }
  }
}

template<class T> T read(const void *base,size_t offset) {
  T v; std::memcpy(&v,static_cast<const uint8_t*>(base)+offset,sizeof v); return v;
}
template<class F> F native(uintptr_t address) { return reinterpret_cast<F>(slide+address); }
bool word(uintptr_t address,uint32_t expected) {return read<uint32_t>(reinterpret_cast<void*>(slide+address),0)==expected;}
void *app() {return read<void*>(reinterpret_cast<void*>(slide+0x102fa7090),0);}
bool menuAvailable(void *a) {
  if (!a || read<int>(a,0xaa4)!=1 || read<uint8_t>(a,0xaa0)) return false;
  void *menu=read<void*>(a,0xb78);
  if (!menu || read<uintptr_t>(menu,0)!=slide+0x1029d8f50 || !read<uint8_t>(menu,0x74)) return false;
  // MainMenu exists during the publisher-logo sequence. Its native queue
  // must be empty before a menu control may draw above the game surface.
  if (read<uintptr_t>(menu,0x6a0)!=read<uintptr_t>(menu,0x6a8)) return false;
  if (read<int>(menu,0x54)!=read<int>(menu,0x120)) return false;
  return native<int(*)(void*)>(0x100d0b82c)(a)==0;
}
float menuOpacity(void *a) {
  void *menu=read<void*>(a,0xb78);
  void *container=read<void*>(menu,0x698);
  if(!container || read<uintptr_t>(container,0)!=slide+0x1029d9388 ||
     !read<uint8_t>(container,0x74))return 0;
  // Zen's CrystalBall is the first retained native orb. Match its authored
  // intro curve instead of starting a separate wall-clock UIKit animation.
  void *orb=read<void*>(container,0x338);
  if(!orb || read<uintptr_t>(orb,0)!=slide+0x1029cc690 ||
     !read<uint8_t>(orb,0x74))return 0;
  auto curve=[](void *object,size_t offset) {
    return native<float(*)(void*)>(0x100f00a98)(static_cast<uint8_t*>(object)+offset);
  };
  // CrystalBall::DrawCrystal (0x100058618), multiplied by the two
  // Bej3Widget::DrawAll parent color factors (0x10012307c).
  float opacity=curve(orb,0x1c8)*read<float>(orb,0xe0c)*
    curve(container,0x138)*curve(menu,0x138);
  return std::isfinite(opacity)?fminf(1.0f,fmaxf(0.0f,opacity)):0.0f;
}
void diagnoseMenu(void *a) {
  static unsigned samples=0;
  static double lastTime=0;
  static NSString *last=nil;
  double now=NSDate.date.timeIntervalSince1970;
  if(!a || samples>=24 || now-lastTime<1.0)return;
  lastTime=now;
  void *menu=read<void*>(a,0xb78);
  bool valid=menu && read<uintptr_t>(menu,0)==slide+0x1029d8f50;
  NSString *line=[NSString stringWithFormat:@"0.0.27 menu: state=%d busy=%u valid=%d visible=%d y=%d target=%d dialogs=%d",
    read<int>(a,0xaa4),read<uint8_t>(a,0xaa0),valid,
    valid?read<uint8_t>(menu,0x74):-1,valid?read<int>(menu,0x54):-1,
    valid?read<int>(menu,0x120):-1,native<int(*)(void*)>(0x100d0b82c)(a)];
  if(![line isEqualToString:last]){last=line;++samples;logEvent(line);}
}
UIView *findGameView(UIView *view) {
  if (!view) return nil;
  if ([view isKindOfClass:NSClassFromString(@"EAGLView")]) return view;
  for (UIView *child in view.subviews) { UIView *found=findGameView(child); if(found)return found; }
  return nil;
}
void publishUI(id delegate,bool visible,float opacity,int width,int height,int cx,int cy);
void frame(id delegate,bool before) {
  if (!ready.load()) return;
  void *a=app();
  if (!a) return;
  void *board=read<void*>(a,0xe58);
  BJHUDObserve(board,slide);
  BJRoundObserve(board);
  static bool sawFrame=false, sawMenu=false;
  if(!sawFrame) { sawFrame=true; logEvent(@"native frame hook reached"); }
  if(!before)diagnoseMenu(a);
  bool available=menuAvailable(a);
  if(available && !sawMenu) { sawMenu=true; logEvent(@"main menu guards passed"); }
  if (before && pending.exchange(false) && available) {
    // Same entry used by the native Lightning menu callback, with distinct
    // private round hooks installed before the next native update.
    logEvent(@"experimental round requested on native frame");
    native<void(*)(void*,int)>(0x10002abbc)(a,4);
    board=read<void*>(a,0xe58);
    if (!BJRoundBegin(board)) {
      logEvent(@"round begin failed; third mode disabled");
      ready.store(false); // Fail closed: never present unmodified Lightning as Blitz.
      dispatch_async(dispatch_get_main_queue(),^{blitzButton.hidden=YES;});
      native<void(*)(void*,bool)>(0x10002da64)(a,false);
    } else logEvent(@"round begin succeeded");
    available=false;
  }
  if (!before) {
    publishUI(delegate,available && ready.load(),available?menuOpacity(a):0.0f,read<int>(a,0x124),read<int>(a,0x128),
      read<int>(reinterpret_cast<void*>(slide+0x102fab4c4),0),
      read<int>(reinterpret_cast<void*>(slide+0x102fab4dc),0));
  }
}
void mainHook(id self,SEL cmd) {
  if(depth++) { reinterpret_cast<void(*)(id,SEL)>(originalMain)(self,cmd); --depth; return; }
  frame(self,true);
  reinterpret_cast<void(*)(id,SEL)>(originalMain)(self,cmd);
  frame(self,false); --depth;
}
void timerHook(id self,SEL cmd) {
  if(depth++) { reinterpret_cast<void(*)(id,SEL)>(originalTimer)(self,cmd); --depth; return; }
  frame(self,true);
  reinterpret_cast<void(*)(id,SEL)>(originalTimer)(self,cmd);
  frame(self,false); --depth;
}
}

@interface WPBlitzMenuTarget : NSObject
-(void)start:(id)sender;
@end
@implementation WPBlitzMenuTarget
-(void)start:(id)sender {
  (void)sender;
  if (!ready.load() || pending.load() || !lastWindow) return;
  BJLoadoutPresent(lastWindow, ^{ if (ready.load()) pending.store(true); });
}
@end

namespace {
void publishUI(id delegate,bool visible,float opacity,int width,int height,int cx,int cy) {
  dispatch_block_t block=^{
    SEL viewSEL=NSSelectorFromString(@"view");
    UIView *root=nil;
    if([delegate respondsToSelector:viewSEL]) {
      auto getView=reinterpret_cast<UIView*(*)(id,SEL)>([delegate methodForSelector:viewSEL]);
      root=getView(delegate,viewSEL);
    }
    UIView *view=findGameView(root);
    if (!view) {
      id appDelegate=UIApplication.sharedApplication.delegate;
      if ([appDelegate respondsToSelector:@selector(window)]) {
        auto getWindow=reinterpret_cast<UIWindow*(*)(id,SEL)>([appDelegate methodForSelector:@selector(window)]);
        view=findGameView(getWindow(appDelegate,@selector(window)));
      }
    }
    if (!view || width<=0 || height<=0 || view.bounds.size.width<64 || view.bounds.size.height<64) {
      static bool reported=false;
      if(visible && !reported) { reported=true; logEvent(@"menu eligible but EAGL view or dimensions unavailable"); }
      blitzButton.hidden=YES; return;
    }
    BJPresentationSetMenuVisible(visible);
    BJPresentationRefresh((__bridge void*)view);
    BJBoostLayout((__bridge void*)view,width,height);
    // UIKit children trigger EAGLView.layoutSubviews, which unconditionally
    // reallocates native renderbuffer storage. Keep controls outside that view.
    UIWindow *host=view.window;
    if(!host || (!visible && !blitzButton))return;
    if (!blitzButton) {
      buttonTarget=[WPBlitzMenuTarget new];
      blitzButton=[UIButton buttonWithType:UIButtonTypeCustom];
      blitzButton.accessibilityLabel=@"Blitz, experimental private mode, sixty seconds";
      UIImageView *orb=[[UIImageView alloc] initWithImage:BJUIAsset(@"blitz-orb-00.png")];
      NSMutableArray<UIImage*> *frames=[NSMutableArray new];
      for(int i=0;i<20;++i) { UIImage *im=BJUIAsset([NSString stringWithFormat:@"blitz-orb-%02d.png",i]); if(im)[frames addObject:im]; }
      orb.animationImages=frames; orb.animationDuration=2.0; orb.tag=201;
      orb.contentMode=UIViewContentModeScaleAspectFit;
      [blitzButton addSubview:orb];
      UIImageView *label=[[UIImageView alloc] initWithImage:BJUIAsset(@"blitz-label.png")];
      label.tag=202; label.contentMode=UIViewContentModeScaleAspectFit;
      [blitzButton addSubview:label];
      [blitzButton addTarget:buttonTarget action:@selector(start:) forControlEvents:UIControlEventTouchUpInside];
    }
    if (lastWindow!=host) {
      [blitzButton removeFromSuperview]; [host addSubview:blitzButton]; lastWindow=host;
      logEvent(@"third mode button attached to window outside EAGL view");
    }
    // Triangle apex uses native X0/Y3; Classic and Zen use native X6/Y6 and X1/Y1.
    // Convert native game coordinates to the actual EAGL view's point space.
    CGFloat x=static_cast<CGFloat>(cx)/width*view.bounds.size.width;
    // Compact native title extends farther down; keep the apex below it.
    const int apexY=height<=960?cy+65:cy;
    CGFloat y=static_cast<CGFloat>(apexY)/height*view.bounds.size.height;
    CGRect presentation=[view convertRect:view.bounds toView:host];
    CGPoint center=[view convertPoint:CGPointMake(x,y) toView:host];
    CGFloat w=presentation.size.width*205.0/640.0;
    CGRect rect=CGRectMake(center.x-w/2,center.y-w/2,w,w);
    if(!CGRectEqualToRect(blitzButton.frame,rect))blitzButton.frame=rect;
    UIImageView *orb=(UIImageView*)[blitzButton viewWithTag:201];
    orb.frame=blitzButton.bounds;
    CGFloat labelWidth=w*0.90, labelHeight=labelWidth*72.0/222.0;
    [blitzButton viewWithTag:202].frame=CGRectMake((w-labelWidth)/2,(w-labelHeight)/2,labelWidth,labelHeight);
    if(visible && !orb.isAnimating)[orb startAnimating];
    if(!visible && orb.isAnimating)[orb stopAnimating];
    static bool reportedGeometry=false;
    if(visible && !reportedGeometry) {
      reportedGeometry=true;
      logEvent([NSString stringWithFormat:@"UI geometry: native=%dx%d game=%@ window=%@ button=%@ hidden=%d alpha=%.2f",
        width,height,NSStringFromCGRect(view.bounds),NSStringFromCGRect(host.bounds),
        NSStringFromCGRect(rect),view.hidden,view.alpha]);
    }
    blitzButton.alpha=opacity;
    blitzButton.hidden=!visible || opacity<=0.0f || !ready.load();
    // Native orb opacity is cosmetic and can remain below full opacity.
    // Menu eligibility and pending state govern activation; UIKit ignores hidden/transparent views.
    blitzButton.enabled=visible && ready.load() && !pending.load();
  };
  if(NSThread.isMainThread)block(); else dispatch_async(dispatch_get_main_queue(),block);
}
void install() {
  logEvent(BJPresentationInstall()?@"portrait presentation hook installed":@"portrait presentation hook unavailable");
  Class cls=NSClassFromString(@"SexyApplicationDelegate");
  Method main=class_getInstanceMethod(cls,NSSelectorFromString(@"mainLoop"));
  Method timer=class_getInstanceMethod(cls,NSSelectorFromString(@"timerCallback"));
  if(!main || !timer) { logEvent(@"install failed: native delegate methods unavailable"); return; }
  bool found=false;
  for(uint32_t i=0;i<_dyld_image_count();++i) {
    const char *path=_dyld_get_image_name(i); if(!path)continue;
    // Match exact method offsets in a loaded image; LiveContainer may rename its executable.
    uintptr_t candidate=static_cast<uintptr_t>(_dyld_get_image_vmaddr_slide(i));
    if(reinterpret_cast<uintptr_t>(method_getImplementation(main))!=candidate+0x100f9d114 ||
       reinterpret_cast<uintptr_t>(method_getImplementation(timer))!=candidate+0x100f9cf7c)continue;
    slide=candidate; found=true; break;
  }
  if(!found) { logEvent(@"install failed: native IMP image identity mismatch"); return; }
  if(!word(0x100f00a98,0xd100c3ff) || !word(0x100058618,0x91072000) ||
     !word(0x10002abbc,0xb90aac01) || !word(0x10002da64,0xd10283ff) ||
     !word(0x100d0b82c,0xd10083ff) || !word(0x10002b058,0x52800000)) {
    logEvent(@"install failed: native entry or timed save-read patch mismatch"); return;
  }
  if(!BJRoundInstall(slide)) { logEvent(@"install failed: round compatibility guards rejected image"); return; }
  originalMain=method_setImplementation(main,reinterpret_cast<IMP>(&mainHook));
  originalTimer=method_setImplementation(timer,reinterpret_cast<IMP>(&timerHook));
  ready.store(true);
  logEvent(@"bridge installed; awaiting eligible main menu");
}
__attribute__((constructor)) void loadBridge() {
  bool presentationInstalled=BJPresentationInstall();
  (void)presentationInstalled;
  // Let Objective-C class registration and UIKit startup finish. No UIKit
  // polling timer and no runtime executable-page writes are used.
  dispatch_async(dispatch_get_main_queue(),^{logEvent(@"0.0.27 (7862) bridge load callback"); install();});
}
}
