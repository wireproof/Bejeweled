#pragma once
#include <cstdint>
extern "C" uint32_t BJLoadoutMask();
extern "C" void BJLoadoutRecordScore(int score);
extern "C" void BJLoadoutFlush();
#ifdef __OBJC__
#import <UIKit/UIKit.h>
void BJLoadoutPresent(UIView* host, void (^completion)(void));
#endif
