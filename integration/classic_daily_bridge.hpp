#pragma once
#include <cstdint>
extern "C" void BJClassicDailyObserve(void *board,std::uintptr_t slide);
// Called on UIKit main thread after the accepted HUD geometry is applied.
extern "C" void BJClassicDailyLayout(void *gameView,int width,int height);
