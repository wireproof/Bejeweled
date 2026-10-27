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
  int detonatorUses_=0,scramblerUses_=0;
  DefaultBoost mystery_{Boost::Mystery},detonator_{Boost::Detonator},
    scrambler_{Boost::Scrambler},extra_{Boost::ExtraTime},multiplier_{Boost::Multiplier};
public:
  void reset(std::uint32_t mask) {
    mask_=mask&31u;started_=false;previous_=0;detonatorUses_=scramblerUses_=0;
    mystery_.reset();detonator_.reset();scrambler_.reset();extra_.reset();multiplier_.reset();
  }
  bool equipped(Boost boost) const {return (mask_&(1u<<static_cast<unsigned>(boost)))!=0;}
  int remaining(Boost boost) const {return boost==Boost::Detonator?2-detonatorUses_:boost==Boost::Scrambler?2-scramblerUses_:0;}
  void update(bool active,std::int64_t elapsed,BoardAdapter& board) {
    if(!active)return;
    if(!started_) {
      started_=true;previous_=elapsed;
      if(equipped(Boost::ExtraTime))extra_.activate(Event::GameBegin,board);
      if(equipped(Boost::Multiplier))multiplier_.compute(Event::GameBegin,board);
    }
    const auto delta=std::clamp<std::int64_t>(elapsed-previous_,0,1000);previous_=elapsed;
    for(std::int64_t i=0;equipped(Boost::Multiplier)&&i<delta;++i) {
      multiplier_.compute(Event::TimeTick,board);multiplier_.activate(Event::TimeTick,board);
    }
  }
  void match(BoardAdapter& board) {
    if(!started_)return;
    if(equipped(Boost::Detonator))detonator_.compute(Event::Match,board);
    if(equipped(Boost::Mystery))mystery_.activate(Event::Match,board);
  }
  bool click(Boost boost,bool active,BoardAdapter& board) {
    if(!active||!started_||!equipped(boost))return false;
    if(boost==Boost::Detonator&&detonatorUses_<2) {
      detonator_.compute(Event::Click,board);
      if(detonator_.activate(Event::Click,board)){++detonatorUses_;return true;}
    }
    if(boost==Boost::Scrambler&&scramblerUses_<2&&scrambler_.activate(Event::Click,board)) {
      ++scramblerUses_;return true;
    }
    return false;
  }
};
}
