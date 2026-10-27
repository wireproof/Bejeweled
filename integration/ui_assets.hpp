#pragma once
#import <UIKit/UIKit.h>
#include <dlfcn.h>
// Resolve beside this injected library, independent of LiveContainer's mainBundle proxy.
static inline UIImage *BJUIAsset(NSString *filename) {
 Dl_info info{};
 if(!dladdr(reinterpret_cast<const void*>(&BJUIAsset),&info)||!info.dli_fname)return nil;
 NSString *library=[NSString stringWithUTF8String:info.dli_fname];
 NSString *root=library.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent;
 return [UIImage imageWithContentsOfFile:[[root stringByAppendingPathComponent:@"WireproofUI"] stringByAppendingPathComponent:filename]];
}
