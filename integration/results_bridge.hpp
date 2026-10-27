#pragma once
#include <cstdint>
struct BJRoundResult { int score=0, previousBest=0, lastHurrah=0, maxMultiplier=1; uint32_t boosts=0; uint64_t generation=0; };
// Original Blitz score milestones from default_menus.json. Progress is local
// personal-best progress; it does not award online currency or claim a rank.
struct BJScoreMilestone { int reached=0, next=25000; float progress=0; };
inline BJScoreMilestone BJResultsMilestone(int best) {
 constexpr int thresholds[]={25000,50000,75000,100000,125000,150000,175000,200000,225000,250000,300000,350000,400000,450000,500000,1000000,3000000,5000000,10000000};
 if(best<0)best=0;
 int reached=0;for(int threshold:thresholds){if(best<threshold)return {reached,threshold,static_cast<float>(best)/threshold};++reached;}
 return {reached,0,1.0f};
}
int BJResultsPreviousBest();
void BJResultsQueue(const BJRoundResult& result);
#ifdef __OBJC__
#import <UIKit/UIKit.h>
// Call on the main thread. Callbacks must enqueue native engine actions.
void BJResultsDrain(UIView* host, void(^playAgain)(void), void(^mainMenu)(void));
#endif
