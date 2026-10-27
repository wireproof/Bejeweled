#import <UIKit/UIKit.h>
#import <objc/runtime.h>
static UIInterfaceOrientationMask BJOrientations(id object,SEL selector){(void)object;(void)selector;return UIInterfaceOrientationMaskPortrait;}
static BOOL BJHideIndicator(id object,SEL selector){(void)object;(void)selector;return YES;}
static BOOL BJAutorotate(id object,SEL selector){(void)object;(void)selector;return YES;}
static void BJOrientationLog(NSString *message){
 NSString *path=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"Bejeweled-Orientation.log"];
 if(![NSFileManager.defaultManager fileExistsAtPath:path])[NSFileManager.defaultManager createFileAtPath:path contents:nil attributes:nil];
 NSFileHandle *f=[NSFileHandle fileHandleForWritingAtPath:path];
 @try{[f seekToEndOfFile];[f writeData:[[message stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];[f closeFile];}@catch(NSException *e){(void)e;}
}
static void BJAllowRotation(UIViewController *controller){
 if(!controller)return;Class c=object_getClass(controller);
 Method m=class_getInstanceMethod(c,@selector(supportedInterfaceOrientations));
 class_replaceMethod(c,@selector(supportedInterfaceOrientations),(IMP)BJOrientations,method_getTypeEncoding(m));
 m=class_getInstanceMethod(c,@selector(shouldAutorotate));
 class_replaceMethod(c,@selector(shouldAutorotate),(IMP)BJAutorotate,method_getTypeEncoding(m));
 if(@available(iOS 16.0,*))[controller setNeedsUpdateOfSupportedInterfaceOrientations];
 for(UIViewController *child in controller.childViewControllers)BJAllowRotation(child);
 if(controller.presentedViewController)BJAllowRotation(controller.presentedViewController);
}
@interface BJSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,strong) id orientationObserver;
@end
@implementation BJSceneDelegate
+(void)load {
 for(NSString *name in @[@"GameViewController",@"ViewContainerController"]){
  Class c=NSClassFromString(name);if(!c)continue;
  Method m=class_getInstanceMethod(c,@selector(supportedInterfaceOrientations));
  if(m)class_replaceMethod(c,@selector(supportedInterfaceOrientations),(IMP)BJOrientations,method_getTypeEncoding(m));
  class_replaceMethod(c,@selector(prefersHomeIndicatorAutoHidden),(IMP)BJHideIndicator,"B@:");
  m=class_getInstanceMethod(c,@selector(shouldAutorotate));
  if(m)class_replaceMethod(c,@selector(shouldAutorotate),(IMP)BJAutorotate,method_getTypeEncoding(m));
 }
}
-(void)scene:(UIScene*)scene willConnectToSession:(UISceneSession*)session options:(UISceneConnectionOptions*)options {
 (void)session;(void)options;
 if(![scene isKindOfClass:UIWindowScene.class])return;
 id delegate=UIApplication.sharedApplication.delegate;
 UIWindow *w=nil;
 if([delegate respondsToSelector:@selector(window)])w=[delegate window];
 if(!w)for(UIWindow *candidate in ((UIWindowScene*)scene).windows){if(candidate.rootViewController){w=candidate;break;}}
 if(!w)return;
 self.window=w;w.windowScene=(UIWindowScene*)scene;w.frame=((UIWindowScene*)scene).coordinateSpace.bounds;
 [w makeKeyAndVisible];[w setNeedsLayout];
 BJAllowRotation(w.rootViewController);
 [self updateOrientation];
}
-(void)updateOrientation {
 UIWindowScene *scene=self.window.windowScene;if(!scene)return;
 UIDeviceOrientation o=UIDevice.currentDevice.orientation;
 UIInterfaceOrientationMask mask=UIInterfaceOrientationMaskPortrait;
 if(@available(iOS 16.0,*)){
  BJAllowRotation(self.window.rootViewController);
  BJOrientationLog([NSString stringWithFormat:@"device=%ld scene=%ld requested=%lu root=%@ mask=%lu bounds=%@",(long)o,(long)scene.interfaceOrientation,(unsigned long)mask,NSStringFromClass(self.window.rootViewController.class),(unsigned long)self.window.rootViewController.supportedInterfaceOrientations,NSStringFromCGRect(scene.coordinateSpace.bounds)]);
  [scene requestGeometryUpdateWithPreferences:[[UIWindowSceneGeometryPreferencesIOS alloc]initWithInterfaceOrientations:mask] errorHandler:^(NSError *error){BJOrientationLog([NSString stringWithFormat:@"request error: %@",error]);}];
 }
}
-(void)windowScene:(UIWindowScene*)scene didUpdateCoordinateSpace:(id<UICoordinateSpace>)space interfaceOrientation:(UIInterfaceOrientation)orientation traitCollection:(UITraitCollection*)traits {
 (void)space;(void)orientation;(void)traits;self.window.frame=scene.coordinateSpace.bounds;[self.window setNeedsLayout];
 BJOrientationLog([NSString stringWithFormat:@"scene changed: %ld %@",(long)scene.interfaceOrientation,NSStringFromCGRect(scene.coordinateSpace.bounds)]);
}
-(void)sceneDidBecomeActive:(UIScene*)scene {
 (void)scene;id<UIApplicationDelegate> d=UIApplication.sharedApplication.delegate;
 if([d respondsToSelector:@selector(applicationDidBecomeActive:)])[d applicationDidBecomeActive:UIApplication.sharedApplication];
 [self.window setNeedsLayout];[self updateOrientation];
}
-(void)sceneWillResignActive:(UIScene*)scene {
 (void)scene;id<UIApplicationDelegate> d=UIApplication.sharedApplication.delegate;
 if([d respondsToSelector:@selector(applicationWillResignActive:)])[d applicationWillResignActive:UIApplication.sharedApplication];
}
-(void)sceneWillEnterForeground:(UIScene*)scene {
 (void)scene;id<UIApplicationDelegate> d=UIApplication.sharedApplication.delegate;
 if([d respondsToSelector:@selector(applicationWillEnterForeground:)])[d applicationWillEnterForeground:UIApplication.sharedApplication];
}
-(void)sceneDidEnterBackground:(UIScene*)scene {
 (void)scene;id<UIApplicationDelegate> d=UIApplication.sharedApplication.delegate;
 if([d respondsToSelector:@selector(applicationDidEnterBackground:)])[d applicationDidEnterBackground:UIApplication.sharedApplication];
}
@end
