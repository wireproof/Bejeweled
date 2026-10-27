#include "boost_core.hpp"
#include <cassert>
#include <iostream>
#include <vector>
using namespace blitz;
struct Board final: BoardAdapter {
  int rng=99, randomCalls=0, gems=1;
  std::vector<int> effects;
  int actionRandomInt(int a,int b) override { assert(a==0&&b==100); ++randomCalls; return rng; }
  int detonatableGemCount() const override { return gems; }
  void convertRandomGems(GemSet from,GemSet to,int n) override {
    assert(from==GemSet::Normal&&n==1); effects.push_back(to==GemSet::Special?10:20);
  }
  void scrambleGems() override { effects.push_back(30); }
  void increaseBlazingSpeed(int n) override { assert(n==200);effects.push_back(40); }
  void addExtraTimeAtGameEnd(int n) override { assert(n==500);effects.push_back(50); }
  void increaseScoreDelta(int n) override { assert(n==2000);effects.push_back(60); }
  void increaseMultiplierWithDetonateDuration(int n) override { effects.push_back(n); }
};
int main() {
  {
    Board b;DefaultBoost x(Boost::Mystery);
    for(int i=0;i<20;++i) assert(!x.activate(Event::Match,b));
    assert(x.state().attempts==20&&b.randomCalls==20);
    assert(x.activate(Event::Match,b));
    assert(b.randomCalls==21&&x.state().attempts==0&&b.effects==std::vector<int>{10});
    b.rng=20;assert(x.activate(Event::Match,b));
    b.rng=21;assert(!x.activate(Event::Match,b));
    x.reset();assert(x.state().attempts==0);
  }
  {
    Board b;DefaultBoost x(Boost::Mystery);
    for(int i=0;i<20;++i) x.activate(Event::Match,b);
    assert(x.activate(Event::Match,b));
    assert(b.randomCalls==21&&x.state().attempts==0);
  }
  {
    Board b;DefaultBoost x(Boost::Detonator);
    b.gems=0;x.compute(Event::Click,b);assert(!x.activate(Event::Click,b));
    assert(x.state().uses==0&&b.effects.empty());b.gems=1;
    x.compute(Event::Click,b);assert(x.activate(Event::Click,b));assert(b.effects.back()==2);
    for(int i=0;i<25;++i)x.compute(Event::Match,b);
    x.compute(Event::Click,b);assert(x.activate(Event::Click,b));assert(b.effects.back()==4&&x.state().charge==0);
    // Outer GreaterThan ignores its nested usage comparison return.
    // Dispatch/UI may impose a separate limit; this tests only the action node.
    x.compute(Event::Click,b);assert(x.activate(Event::Click,b));
    assert(x.activate(Event::Click,b));assert(x.state().uses==4);
  }
  {
    Board b;DefaultBoost x(Boost::Scrambler);
    assert(!x.activate(Event::Match,b));
    for(int i=0;i<3;++i)assert(x.activate(Event::Click,b));
    assert(!x.activate(Event::Click,b));
    assert((b.effects==std::vector<int>{30,40,30,40,30,40}));
  }
  {
    Board b;DefaultBoost x(Boost::ExtraTime);
    assert(!x.activate(Event::TimeTick,b));assert(x.activate(Event::GameBegin,b));
    assert((b.effects==std::vector<int>{50,60}));
  }
  {
    Board b;DefaultBoost x(Boost::Multiplier);x.compute(Event::GameBegin,b);
    assert(b.effects==std::vector<int>{20});
    for(int i=1;i<3000;++i){x.compute(Event::TimeTick,b);assert(!x.activate(Event::TimeTick,b));}
    x.compute(Event::TimeTick,b);assert(x.activate(Event::TimeTick,b));
    assert(x.state().ticks==0&&b.effects.size()==2);
  }
  std::cout<<"All literal AST conformance tests passed; native semantics remain unverified.\n";
}
