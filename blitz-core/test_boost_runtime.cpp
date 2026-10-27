#include "boost_runtime.hpp"
#include <cassert>
#include <iostream>
using namespace blitz;
struct Board:BoardAdapter {
 int special=0,mult=0,time=0,scrambles=0,detonations=0,gems=0;
 int actionRandomInt(int,int)override{return 0;}
 int detonatableGemCount()const override{return gems;}
 void convertRandomGems(GemSet,GemSet to,int n)override{(to==GemSet::Multiplier?mult:special)+=n;}
 void scrambleGems()override{++scrambles;}
 void increaseBlazingSpeed(int)override{}
 void addExtraTimeAtGameEnd(int n)override{time+=n;}
 void increaseScoreDelta(int)override{}
 void increaseMultiplierWithDetonateDuration(int)override{++detonations;}
};
int main(){
 for(unsigned mask=0;mask<32;++mask){
  if(__builtin_popcount(mask)>3)continue;
  Board b;BoostRuntime r;r.reset(mask);
  r.update(false,0,b);r.match(b);assert(b.special==0&&b.mult==0&&b.time==0);
  r.update(true,0,b);r.update(true,0,b);
  assert(b.time==((mask&8)?500:0));assert(b.mult==((mask&16)?1:0));
  r.match(b);assert(b.special==((mask&1)?1:0));
  r.update(false,0,b);assert(!r.click(Boost::Scrambler,false,b));
  for(int tick=1;tick<=2999;++tick)r.update(true,tick,b);
  assert(b.mult==((mask&16)?1:0));r.update(true,3000,b);assert(b.mult==((mask&16)?2:0));
  assert(!r.click(Boost::Detonator,true,b));assert(r.remaining(Boost::Detonator)==2);
  b.gems=1;for(int i=0;i<3;++i){r.click(Boost::Detonator,true,b);r.click(Boost::Scrambler,true,b);}
  assert(b.detonations==((mask&2)?2:0));assert(b.scrambles==((mask&4)?2:0));
  r.reset(0);r.update(true,0,b);const int before=b.mult;r.update(true,1000,b);r.update(true,2000,b);r.update(true,3000,b);assert(b.mult==before);
 }
 std::cout<<"PASS: all 26 permitted loadouts, passive effects, repeat-start, pause, use limits, reset and 30-second activation\n";
}
