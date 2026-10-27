#pragma once
#include "boost_core.hpp"
#include <algorithm>
namespace blitz {
// Owns one round's equipped-boost dispatch. Native adapters supply effects;
// paused updates and clicks never advance or consume boosts.
class BoostRuntime {
  std::uint32_t mask_=0;
  bool started_=false;
  std::int64_t previous_=0;
  int detonatorUses_=0,scramblerUses_=0,mysteryUses_=0,extraUses_=0;
  int scrambleLimit_=2,multiplierPeriod_=3000; std::int64_t multiplierTicks_=0;
  DefaultBoost detonator_{Boost::Detonator},
    scrambler_{Boost::Scrambler},multiplier_{Boost::Multiplier};
public:
  static constexpr int scrambleUses(int level){constexpr int values[]={2,3,4,5,7,8,9,11,12,13,15};return values[std::clamp(level,0,10)];}
  static constexpr int multiplierSeconds(int level){constexpr int values[]={30,28,26,24,20,18,16,12,10,8,5};return values[std::clamp(level,0,10)];}
  void reset(std::uint32_t mask,int scrambleLevel=0,int multiplierLevel=0) {
    scrambleLimit_=scrambleUses(scrambleLevel);multiplierPeriod_=100*multiplierSeconds(multiplierLevel);multiplierTicks_=0;
    mask_=mask&31u;started_=false;previous_=0;detonatorUses_=scramblerUses_=mysteryUses_=extraUses_=0;
    detonator_.reset();scrambler_.reset();multiplier_.reset();
  }
  bool equipped(Boost boost) const {return (mask_&(1u<<static_cast<unsigned>(boost)))!=0;}
  int remaining(Boost boost) const {return boost==Boost::Detonator?2-detonatorUses_:boost==Boost::Scrambler?scrambleLimit_-scramblerUses_:boost==Boost::Mystery?1-mysteryUses_:boost==Boost::ExtraTime?1-extraUses_:0;}
  void update(bool active,std::int64_t elapsed,BoardAdapter& board) {
    if(!active)return;
    if(!started_) {
      started_=true;previous_=elapsed;
      if(equipped(Boost::Multiplier))multiplier_.compute(Event::GameBegin,board);
    }
    const auto delta=std::clamp<std::int64_t>(elapsed-previous_,0,1000);previous_=elapsed;
    if(equipped(Boost::Multiplier)) {
      multiplierTicks_+=delta;
      while(multiplierTicks_>=multiplierPeriod_) {
        multiplierTicks_-=multiplierPeriod_;
        board.convertRandomGems(GemSet::Normal,GemSet::Multiplier,1);
      }
    }
  }
  void match(BoardAdapter& board) {
    if(!started_)return;
    if(equipped(Boost::Detonator))detonator_.compute(Event::Match,board);
  }
  bool click(Boost boost,bool active,BoardAdapter& board) {
    if(!active||!started_||!equipped(boost))return false;
    // User-selected tap-to-use behavior: no automatic Mystery rolls or
    // start-of-round Extra Time, and one deliberate activation per round.
    if(boost==Boost::Mystery&&mysteryUses_<1) {
      board.convertRandomGems(GemSet::Normal,GemSet::Special,1);++mysteryUses_;return true;
    }
    if(boost==Boost::ExtraTime&&extraUses_<1) {
      board.addExtraTimeAtGameEnd(500);++extraUses_;return true;
    }
    if(boost==Boost::Detonator&&detonatorUses_<2) {
      detonator_.compute(Event::Click,board);
      if(detonator_.activate(Event::Click,board)){++detonatorUses_;return true;}
    }
    if(boost==Boost::Scrambler&&scramblerUses_<scrambleLimit_) {
      board.scrambleGems();board.increaseBlazingSpeed(200);++scramblerUses_;return true;
    }
    return false;
  }
};
}
