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
  DefaultBoost detonator_{Boost::Detonator},
    scrambler_{Boost::Scrambler},multiplier_{Boost::Multiplier};
public:
  void reset(std::uint32_t mask) {
    mask_=mask&31u;started_=false;previous_=0;detonatorUses_=scramblerUses_=mysteryUses_=extraUses_=0;
    detonator_.reset();scrambler_.reset();multiplier_.reset();
  }
  bool equipped(Boost boost) const {return (mask_&(1u<<static_cast<unsigned>(boost)))!=0;}
  int remaining(Boost boost) const {return boost==Boost::Detonator?2-detonatorUses_:boost==Boost::Scrambler?2-scramblerUses_:boost==Boost::Mystery?1-mysteryUses_:boost==Boost::ExtraTime?1-extraUses_:0;}
  void update(bool active,std::int64_t elapsed,BoardAdapter& board) {
    if(!active)return;
    if(!started_) {
      started_=true;previous_=elapsed;
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
    if(boost==Boost::Scrambler&&scramblerUses_<2&&scrambler_.activate(Event::Click,board)) {
      ++scramblerUses_;return true;
    }
    return false;
  }
};
}
