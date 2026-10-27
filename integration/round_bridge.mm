// Experimental Blitz adaptation, Classic 4.0.0/7831 ARM64 only.
// Per-instance vtable: no executable-page writes, no Classic/Zen changes.
#include "round_bridge.hpp"
#include "boost_bridge.hpp"
#include "loadout_bridge.hpp"
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <cstring>

namespace {
constexpr uintptr_t kTable=0x1029cee80;
constexpr size_t kPrefixWords=4; // constructor vptr=table+0x20, including virtual-base offsets
constexpr size_t kTableBytes=0xb00; // next symbol __ZTTN4Sexy10SpeedBoardE
constexpr uintptr_t kUpdate=0x100088ef8, kNew=0x1000865a4;
constexpr uintptr_t kD1=0x100085d98,kD0=0x100085da4,kOver=0x100087ba8;
constexpr uintptr_t kTime=0x100087a98,kTicks=0x1000897ec,kMultiplier=0x100087b54;
constexpr uintptr_t kWantSpecial=0x10008a31c,kDrop=0x10008a81c;
constexpr uintptr_t kSaveName=0x100085f80,kPaused=0x10015b034,kSuspended=0x10015ae8c;
constexpr uintptr_t kCollect=0x10008afa8,kBonus=0x100087a80;
struct Round {void* board=nullptr; uintptr_t* original=nullptr; uintptr_t* clone=nullptr;
 uint64_t generation=0; bool active=false; int extraSeconds=0; float multiplier=1;
 int elapsed=0; bool ending=false;};
Round rounds[8]; uintptr_t slide=0; bool installed=false; uint64_t sequence=0;
template<class F> F native(uintptr_t va){return reinterpret_cast<F>(va+slide);}
template<class T> T& field(void* p,size_t off){return *reinterpret_cast<T*>(static_cast<char*>(p)+off);}
Round* state(void* b){for(auto& r:rounds)if(r.board==b)return &r;return nullptr;}
void end(Round& r){if(r.active){BJLoadoutFlush();r.active=false;BJBoostEnd(r.generation);}}
void reset(Round& r){end(r);r.generation=++sequence;r.active=true;r.ending=false;
 r.extraSeconds=0;r.multiplier=1;r.elapsed=0;field<int>(r.board,0x8cd0)=0;
 BJBoostBegin(slide,r.generation);}
bool playable(void*);
int nativeElapsed(void*b){
 const float ticks=field<float>(b,0x90b8)-(field<int>(b,0x202c)==1?250.0f:0.0f);
 if(!std::isfinite(ticks))return 0;
 return static_cast<int>(std::clamp(ticks,0.0f,18000.0f));
}
void update(void* b){
 Round* r=state(b);if(!r||!r->active){native<void(*)(void*)>(kUpdate)(b);return;}
 field<int>(b,0x8cd0)=0; // verified Lightning bank; no additional timed rounds
 const int before=field<int>(b,0x204c); // native Board::MatchMade counter
 native<void(*)(void*)>(kUpdate)(b);
 r=state(b);if(!r||!r->active)return;
 field<int>(b,0x8cd0)=0;
 const int after=field<int>(b,0x204c);
 const int64_t count=static_cast<int64_t>(after)-before;
 if(!r->ending && playable(b) && count>0 && count<=64)
  for(int64_t i=0;i<count;++i)BJBoostMatch(b,r->generation);
 // Same elapsed expression as native GetTicksLeft, before its display cap.
 // Avoid an artificial 500-tick jump when the extra-time limit grows.
 r->elapsed=std::max(r->elapsed,nativeElapsed(b));
 BJBoostUpdate(b,r->generation,!r->ending&&playable(b),r->elapsed);
 // SpeedBoard::DrawScore at 0x10008b99c reads signed score at +0x1e38.
 BJLoadoutRecordScore(field<int>(b,0x1e38));
}
void newGame(void* b,bool replay){Round* r=state(b);if(r)reset(*r);
 native<void(*)(void*,bool)>(kNew)(b,replay);if(r)field<int>(b,0x8cd0)=0;}
void destroy(void* b,bool deleting){Round* r=state(b);uintptr_t* allocation=nullptr;
 if(r){end(*r);*reinterpret_cast<uintptr_t**>(b)=r->original;allocation=r->clone;*r=Round{};}
 native<void(*)(void*)>(deleting?kD0:kD1)(b);std::free(allocation);}
void d1(void* b){destroy(b,false);}void d0(void* b){destroy(b,true);}
void gameOver(void* b,bool arg){Round* r=state(b);if(r&&r->active){field<int>(b,0x8cd0)=0;
 // ExtraTime is prepared by boost adapter before native finalization.
 const int oldExtra=r->extraSeconds;
 BJBoostUpdate(b,r->generation,true,nativeElapsed(b));
 if(r->extraSeconds>oldExtra && native<int(*)(void*)>(kTicks)(b)>0 && !arg)return;
 r->ending=true;}
 if(r&&r->active){BJLoadoutRecordScore(field<int>(b,0x1e38));BJLoadoutFlush();}
 native<void(*)(void*,bool)>(kOver)(b,arg);}
int timeLimit(void* b){auto*r=state(b);return r&&r->active?60+r->extraSeconds:60;}
float multiplier(void* b){auto*r=state(b);return r&&r->active?r->multiplier:5.0f;}
bool wantSpecial(void*,void*){return false;}
void noDrop(void*,void*){}void noTime(void*,int){}
// ARM64 aggregate >16 bytes returns through x8, exactly the native string sret.
// Empty Apple libc++ alternate-layout short string: SaveGame(bool) exits before serialization.
struct EmptyString { unsigned char bytes[24]; };
EmptyString noSavedGame(void*,bool){return {}; }
bool playable(void*b){return !native<bool(*)(void*)>(kPaused)(b) && !native<bool(*)(void*)>(kSuspended)(b); }
struct Replacement{uintptr_t va;uintptr_t fn;};
Replacement replacements[]={
 {kUpdate,reinterpret_cast<uintptr_t>(&update)},{kNew,reinterpret_cast<uintptr_t>(&newGame)},
 {kD1,reinterpret_cast<uintptr_t>(&d1)},{kD0,reinterpret_cast<uintptr_t>(&d0)},
 {kOver,reinterpret_cast<uintptr_t>(&gameOver)},{kTime,reinterpret_cast<uintptr_t>(&timeLimit)},
 {kMultiplier,reinterpret_cast<uintptr_t>(&multiplier)},
 {kWantSpecial,reinterpret_cast<uintptr_t>(&wantSpecial)},{kDrop,reinterpret_cast<uintptr_t>(&noDrop)},
 {kSaveName,reinterpret_cast<uintptr_t>(&noSavedGame)},
 {kCollect,reinterpret_cast<uintptr_t>(&noTime)},{kBonus,reinterpret_cast<uintptr_t>(&noTime)}};
}
extern "C" bool BJRoundInstall(uintptr_t s){
 if(installed)return slide==s;if(!BJBoostCompatible(s))return false;slide=s;
 const auto*vt=reinterpret_cast<const uintptr_t*>(kTable+slide+32);
 if(vt[0]!=kD1+slide||vt[1]!=kD0+slide)return false;
 // All essential replacement methods must be in this exact version's vtable.
 for(uintptr_t va:{kUpdate,kNew,kOver,kTime,kMultiplier,kWantSpecial,kDrop,kSaveName}){
  bool found=false;for(size_t i=0;i<(kTableBytes-32)/8;++i)found|=vt[i]==va+slide;
  if(!found)return false;
 }
 installed=true;return true;
}
extern "C" bool BJRoundBegin(void*b){
 if(!installed||!b)return false;
 auto*original=*reinterpret_cast<uintptr_t**>(b);
 if(auto*r=state(b);r&&original==r->clone+kPrefixWords){reset(*r);return true;}
 if(reinterpret_cast<uintptr_t>(original)!=kTable+slide+32)return false;
 Round*slot=state(b);if(slot){end(*slot);std::free(slot->clone);*slot=Round{};}
 if(!slot)for(auto&r:rounds)if(!r.board){slot=&r;break;}
 if(!slot)return false;
 auto*copy=static_cast<uintptr_t*>(std::malloc(kTableBytes));if(!copy)return false;
 std::memcpy(copy,original-kPrefixWords,kTableBytes);
 for(size_t i=kPrefixWords;i<kTableBytes/8;++i)for(auto p:replacements)
  if(copy[i]==p.va+slide)copy[i]=p.fn;
 slot->board=b;slot->original=original;slot->clone=copy;
 *reinterpret_cast<uintptr_t**>(b)=copy+kPrefixWords;reset(*slot);return true;
}
extern "C" void BJRoundObserve(void*b){for(auto&r:rounds)if(r.active){
 if(r.board!=b)end(r);
 else if(r.ending||!playable(b))BJBoostUpdate(b,r.generation,false,r.elapsed);
 }}
extern "C" bool BJRoundActive(void*b){auto*r=state(b);return r&&r->active&&!r->ending&&playable(b);}
extern "C" uint64_t BJRoundGeneration(void*b){auto*r=state(b);return r&&r->active?r->generation:0;}
extern "C" bool BJRoundAddTimeTicks(void*b,int ticks){auto*r=state(b);
 if(!r||!r->active||r->ending||ticks<=0||ticks%100||ticks>6000)return false;
 r->extraSeconds=std::min(120,r->extraSeconds+ticks/100);return true;}
extern "C" bool BJRoundSetMultiplier(void*b,float value){auto*r=state(b);
 if(!r||!r->active||!std::isfinite(value)||value<1||value>100)return false;
 r->multiplier=value;return true;}
