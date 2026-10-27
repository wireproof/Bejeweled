#pragma once
#include <cstdint>

// Literal translation of the shipped default boost action trees.
// This is not a verified implementation of Blitz's action interpreter.
namespace blitz {
enum class Boost { Mystery, Detonator, Scrambler, ExtraTime, Multiplier };
enum class Event { Match, Click, GameBegin, TimeTick };
enum class GemSet { Normal, Special, Multiplier };
struct BoardAdapter {
  virtual ~BoardAdapter() = default;
  // Must resolve native ActionRandomInt interval semantics; no assumed RNG here.
  virtual int actionRandomInt(int first, int second) = 0;
  virtual int detonatableGemCount() const = 0;
  virtual void convertRandomGems(GemSet from, GemSet to, int count) = 0;
  virtual void scrambleGems() = 0;
  virtual void increaseBlazingSpeed(int rawDelta) = 0;
  virtual void addExtraTimeAtGameEnd(int rawTime) = 0;
  virtual void increaseScoreDelta(int rawDelta) = 0;
  // Preserves nested AST operation without inventing detonation/multiplier order
  // or the meaning of the return value used as a duration expression.
  virtual void increaseMultiplierWithDetonateDuration(int bonus) = 0;
};
struct State {
  std::int64_t attempts=0, charge=0, uses=0, multiplierBonus=0, ticks=0;
};
class DefaultBoost {
  Boost kind_;
  State state_{};
public:
  explicit DefaultBoost(Boost kind): kind_(kind) {}
  const State& state() const { return state_; }
  void reset() { state_={}; }
  // Host must establish native Compute/Activation ordering and event frequency.
  void compute(Event event, BoardAdapter& board) {
    if(kind_==Boost::Detonator) {
      if(event==Event::Match) ++state_.charge;
      if(event==Event::Click) state_.multiplierBonus=state_.charge>=25?4:2;
    }
    if(kind_==Boost::Multiplier) {
      if(event==Event::TimeTick) ++state_.ticks;
      if(event==Event::GameBegin) board.convertRandomGems(GemSet::Normal,GemSet::Multiplier,1);
    }
  }
  // Native ActionOr evaluates both operands before testing their Boolean values.
  // Click events must be routed only to the clicked boost.
  bool activate(Event event, BoardAdapter& board) {
    switch(kind_) {
    case Boost::Mystery: {
      if(event!=Event::Match) return false;
      bool forced=state_.attempts>=20;
      bool randomPass=20>=board.actionRandomInt(0,100);
      if(!randomPass) ++state_.attempts;
      if(!(forced || randomPass)) return false;
      state_.attempts=0;
      board.convertRandomGems(GemSet::Normal,GemSet::Special,1);
      return true;
    }
    case Boost::Detonator:
      // Native GreaterThan returns its own comparison, discarding the nested
      // LessEqual result. UI/event-dispatch limits remain outside this module.
      if(event!=Event::Click || board.detonatableGemCount()<=0) return false;
      ++state_.uses;
      board.increaseMultiplierWithDetonateDuration(static_cast<int>(state_.multiplierBonus));
      state_.charge=0;
      return true;
    case Boost::Scrambler:
      if(event!=Event::Click || state_.uses>2) return false;
      ++state_.uses;
      board.scrambleGems();
      board.increaseBlazingSpeed(200);
      return true;
    case Boost::ExtraTime:
      if(event!=Event::GameBegin) return false;
      board.addExtraTimeAtGameEnd(500);
      board.increaseScoreDelta(2000);
      return true;
    case Boost::Multiplier:
      if(event!=Event::TimeTick || state_.ticks<3000) return false;
      state_.ticks=0;
      board.convertRandomGems(GemSet::Normal,GemSet::Multiplier,1);
      return true;
    }
    return false;
  }
};
}
