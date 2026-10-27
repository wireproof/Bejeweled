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
  assert(b.time==0);assert(b.mult==((mask&16)?1:0));
  r.match(b);assert(b.special==0);
  r.update(false,0,b);
  for(auto boost:{Boost::Mystery,Boost::ExtraTime,Boost::Detonator,Boost::Scrambler})assert(!r.click(boost,false,b));
  assert(b.time==0&&b.special==0);
  for(int i=0;i<3;++i){r.click(Boost::Mystery,true,b);r.click(Boost::ExtraTime,true,b);}
  assert(b.special==((mask&1)?1:0));assert(b.time==((mask&8)?500:0));
  assert(r.remaining(Boost::Mystery)==((mask&1)?0:1));
  assert(r.remaining(Boost::ExtraTime)==((mask&8)?0:1));
  for(int tick=1;tick<=2999;++tick)r.update(true,tick,b);
  assert(b.mult==((mask&16)?1:0));r.update(true,3000,b);assert(b.mult==((mask&16)?2:0));
  assert(!r.click(Boost::Detonator,true,b));assert(r.remaining(Boost::Detonator)==2);
  b.gems=1;for(int i=0;i<3;++i){r.click(Boost::Detonator,true,b);r.click(Boost::Scrambler,true,b);}
  assert(b.detonations==((mask&2)?2:0));assert(b.scrambles==((mask&4)?2:0));
  r.reset(0);r.update(true,0,b);const int before=b.mult;r.update(true,1000,b);r.update(true,2000,b);r.update(true,3000,b);assert(b.mult==before);
 }
 {
  Board b;BoostRuntime r;r.reset(9);r.update(true,0,b);
  assert(r.click(Boost::Mystery,true,b)&&r.click(Boost::ExtraTime,true,b));
  r.reset(9);r.update(true,0,b);assert(b.special==1&&b.time==500);
  assert(r.remaining(Boost::Mystery)==1&&r.remaining(Boost::ExtraTime)==1);
  assert(r.click(Boost::Mystery,true,b)&&r.click(Boost::ExtraTime,true,b));
  assert(b.special==2&&b.time==1000);
 }
 for(int level=0;level<=10;++level){
  Board b;BoostRuntime r;r.reset(20,level,level);r.update(true,0,b);
  int limit=BoostRuntime::scrambleUses(level);for(int i=0;i<limit;i++)assert(r.click(Boost::Scrambler,true,b));
  assert(!r.click(Boost::Scrambler,true,b)&&b.scrambles==limit&&r.remaining(Boost::Scrambler)==0);
  int period=100*BoostRuntime::multiplierSeconds(level);for(int t=1;t<period;t++)r.update(true,t,b);
  assert(b.mult==1);r.update(false,period,b);assert(b.mult==1);r.update(true,period,b);assert(b.mult==2);
  r.reset(20);assert(r.remaining(Boost::Scrambler)==2);
 }
 assert(BoostRuntime::scrambleUses(-1)==2&&BoostRuntime::scrambleUses(99)==15);
 assert(BoostRuntime::multiplierSeconds(-1)==30&&BoostRuntime::multiplierSeconds(99)==5);
 std::cout<<"PASS: all 26 permitted loadouts, manual boost effects, no auto-use, repeat-start, pause, use limits, reset and 30-second activation\n";
}
