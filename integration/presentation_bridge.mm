#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#include <cstdint>
#include <cstring>
#include <cmath>
#include <atomic>
namespace {
IMP originalLayout,originalResize;
char cacheKey, backdropKey;
std::atomic<unsigned> foregroundEpoch{0};
__weak UIView *lastGameView;
id foregroundObserver;
thread_local bool fitting=false;
void note(UIView *view) {
 static NSString *previous; static unsigned count;
 UIWindow *window=view.window;
 NSString *geometry=[NSString stringWithFormat:@"window=%@ safe=%@ parent=%@ bounds=%@ presented=%@",NSStringFromCGRect(window.bounds),NSStringFromUIEdgeInsets(window.safeAreaInsets),NSStringFromCGRect(view.superview.bounds),NSStringFromCGRect(view.bounds),NSStringFromCGRect([view convertRect:view.bounds toView:window])];
 if([geometry isEqualToString:previous]||count>=24)return;
 previous=geometry;++count;
 NSString *dir=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
 NSString *path=[dir stringByAppendingPathComponent:@"Bejeweled-Presentation.log"];
 if(![NSFileManager.defaultManager fileExistsAtPath:path])[NSFileManager.defaultManager createFileAtPath:path contents:nil attributes:nil];
 NSFileHandle *f=[NSFileHandle fileHandleForWritingAtPath:path];
 @try{[f seekToEndOfFile];[f writeData:[[NSString stringWithFormat:@"0.0.22 %.3f %@\n",NSDate.date.timeIntervalSince1970,geometry] dataUsingEncoding:NSUTF8StringEncoding]];[f closeFile];}@catch(NSException *e){(void)e;}
}
void fit(UIView *view) {
 if(fitting||!NSThread.isMainThread)return;
 fitting=true;lastGameView=view;
 [CATransaction begin];[CATransaction setDisableActions:YES];
 view.autoresizingMask=UIViewAutoresizingNone;
 const CGFloat logicalHeight=UIDevice.currentDevice.userInterfaceIdiom==UIUserInterfaceIdiomPad?568:480;
 CGRect logical=CGRectMake(0,0,320,logicalHeight);
 if(!CGRectEqualToRect(view.bounds,logical))view.bounds=logical;
 if(view.contentScaleFactor!=2)view.contentScaleFactor=2;
 UIWindow *window=view.window;UIView *parent=view.superview;
 if(window&&parent){
  // Legacy UIWindow was allocated once from UIScreen. Follow the attached
  // scene after fold/unfold instead of reusing its launch dimensions.
  id<UICoordinateSpace> displaySpace=window.windowScene ? window.windowScene.coordinateSpace : window.screen.coordinateSpace;
  CGRect sceneBounds=displaySpace.bounds;
  if(sceneBounds.size.width>=64 && sceneBounds.size.height>=64 && !CGRectEqualToRect(window.frame,sceneBounds))window.frame=sceneBounds;
  // Fit the artwork to the whole display. Legacy safe-area values can retain
  // a rotated cutout; applying them shrinks the complete game unnecessarily.
  // Keep launch, menu and gameplay on the same full-window transform.
  // Individual controls provide their own edge clearance.
  CGRect available=window.bounds;
  if(available.size.width>=64&&available.size.height>=64){
   CGFloat sx=available.size.width/320,sy=available.size.height/logicalHeight;
   CGFloat ratio=sx/sy;
   // Fill nearly matching portrait displays without cropping controls.
   // Wider tablet/landscape windows retain proportional rendering.
   if(!(available.size.height>available.size.width && ratio>=0.90 && ratio<=1.10))sx=sy=MIN(sx,sy);
   CGPoint c=CGPointMake(CGRectGetMidX(available),CGRectGetMidY(available));
   CGPoint p=[parent convertPoint:c fromView:window];
   CGPoint px=[parent convertPoint:CGPointMake(c.x+sx,c.y) fromView:window];
   CGPoint py=[parent convertPoint:CGPointMake(c.x,c.y+sy) fromView:window];
   CGAffineTransform t=CGAffineTransformMake(px.x-p.x,px.y-p.y,py.x-p.x,py.y-p.y,0,0);
   if(!CGAffineTransformEqualToTransform(view.transform,t))view.transform=t;
   if(!CGPointEqualToPoint(view.center,p))view.center=p;
   CAGradientLayer *backdrop=objc_getAssociatedObject(window,&backdropKey);
   if(!backdrop){
    backdrop=[CAGradientLayer layer];
    backdrop.colors=@[(id)[UIColor colorWithRed:0.10 green:0.025 blue:0.20 alpha:1].CGColor,(id)[UIColor colorWithRed:0.32 green:0.10 blue:0.32 alpha:1].CGColor,(id)[UIColor colorWithRed:0.68 green:0.35 blue:0.22 alpha:1].CGColor];
    backdrop.locations=@[@0,@0.55,@1];
    [window.layer insertSublayer:backdrop atIndex:0];
    objc_setAssociatedObject(window,&backdropKey,backdrop,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
   }
   backdrop.frame=window.bounds;
   for(UIView *ancestor=view.superview;ancestor && ancestor!=window;ancestor=ancestor.superview)ancestor.backgroundColor=UIColor.clearColor;
   window.backgroundColor=[UIColor colorWithRed:0.10 green:0.025 blue:0.20 alpha:1];
   note(view);
  }
 }
 [CATransaction commit];fitting=false;
}
BOOL resizeHook(id renderer,SEL sel,CALayer *layer){
 // Native resizeFromLayer reallocates storage even for transform-only layouts.
 // Cache only successful allocation, and invalidate on scene geometry changes.
 UIView *view=[layer.delegate isKindOfClass:UIView.class]?(UIView*)layer.delegate:nil;
 if([view isKindOfClass:NSClassFromString(@"EAGLView")])fit(view);
 CGRect windowBounds=view.window.bounds;
 NSString *key=[NSString stringWithFormat:@"%p %@ %.3f %@ %u",(__bridge void*)layer,NSStringFromCGRect(layer.bounds),layer.contentsScale,NSStringFromCGRect(windowBounds),foregroundEpoch.load()];
 int width=0,height=0;
 std::memcpy(&width,(const char*)(__bridge void*)renderer+0x20,4);
 std::memcpy(&height,(const char*)(__bridge void*)renderer+0x24,4);
 if(width>0&&height>0&&[objc_getAssociatedObject(renderer,&cacheKey) isEqual:key])return YES;
 BOOL result=reinterpret_cast<BOOL(*)(id,SEL,CALayer*)>(originalResize)(renderer,sel,layer);
 if(result)objc_setAssociatedObject(renderer,&cacheKey,key,OBJC_ASSOCIATION_COPY_NONATOMIC);
 else objc_setAssociatedObject(renderer,&cacheKey,nil,OBJC_ASSOCIATION_COPY_NONATOMIC);
 return result;
}
void layoutHook(UIView *view,SEL sel){fit(view);reinterpret_cast<void(*)(id,SEL)>(originalLayout)(view,sel);}
bool exact(Method m,uintptr_t offset){if(!m)return false;uintptr_t imp=(uintptr_t)method_getImplementation(m);
 for(uint32_t i=0;i<_dyld_image_count();++i)if(imp==(uintptr_t)_dyld_get_image_vmaddr_slide(i)+offset)return true;return false;}
}
extern "C" void BJPresentationSetMenuVisible(bool visible){(void)visible;}
extern "C" void BJPresentationRefresh(void *p){fit((__bridge UIView*)p);}
extern "C" bool BJPresentationInstall(){
 if(originalLayout&&originalResize)return true;
 Method layout=class_getInstanceMethod(NSClassFromString(@"EAGLView"),@selector(layoutSubviews));
 Method resize=class_getInstanceMethod(NSClassFromString(@"ES2Renderer"),NSSelectorFromString(@"resizeFromLayer:"));
 if(!exact(layout,0x100ffd424)||!exact(resize,0x100fa6144))return false;
 foregroundObserver=[NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){(void)n;++foregroundEpoch;[lastGameView setNeedsLayout];}];
 originalResize=method_setImplementation(resize,(IMP)&resizeHook);
 originalLayout=method_setImplementation(layout,(IMP)&layoutHook);
 return true;
}
