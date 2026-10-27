#pragma once
#include <cstdint>
#include <cstring>

// Experimental adapter for original Bejeweled Classic 4.0.0 build 7831.
// NOT a Blitz implementation. No constructor, injection, hook or automatic writes.
// Call only from the game's own synchronous callback while a live SpeedBoard
// is owned by the caller. Board pointers must never be retained across a frame.
namespace bejeweled_private {
struct Piece;
struct Board;
class NativePrimitives {
  std::uintptr_t slide_;
  template<class Fn> Fn at(std::uintptr_t va) const {
    return reinterpret_cast<Fn>(slide_ + va);
  }
  bool instruction(std::uintptr_t va, std::uint32_t expected) const {
    std::uint32_t word;
    std::memcpy(&word, reinterpret_cast<const void*>(slide_+va), sizeof word);
    return word == expected;
  }
public:
  // slide must come from the loaded Bejeweled image, not image index zero
  // (LiveContainer's index-zero image is the host). Verify full executable SHA
  // offline before loading; short entry guards below are an additional check.
  explicit NativePrimitives(std::uintptr_t slide): slide_(slide) {}
  bool compatibleEntrypoints() const {
    return instruction(0x100164604,0x2a010048) &&
      instruction(0x100167670,0xbd402020) &&
      instruction(0x10018eafc,0xa9ba6ffc) &&
      instruction(0x10016dd30,0xa9bb67fa) &&
      instruction(0x100164f34,0xd10483ff) &&
      instruction(0x1001653d0,0xd10183ff) &&
      instruction(0x100165648,0xa9bd57f6) &&
      instruction(0x100165770,0xa9bd57f6);
  }
  bool isUnmodifiedSpeedBoard(const Board* board) const {
    if (!board) return false;
    std::uintptr_t vptr;
    std::memcpy(&vptr,board,sizeof vptr);
    return vptr == slide_ + 0x1029ceea0;
  }
  Piece* piece(Board* board,int row,int col) const {
    if (!board || row<0 || row>=8 || col<0 || col>=8) return nullptr;
    return at<Piece*(*)(Board*,int,int)>(0x100164604)(board,row,col);
  }
  bool still(Board* board,Piece* piece) const {
    return board && piece && at<bool(*)(Board*,Piece*)>(0x100167670)(board,piece);
  }
  // Native Board::UseTool tailcalls Scramble(2). SpeedBoard::UseTool itself
  // is a stub, therefore call this evidenced base implementation directly.
  void scramble(Board* board) const {
    at<void(*)(Board*,int)>(0x10018eafc)(board,2);
  }
  // Caller selects an eligible special piece. A null partner is explicitly
  // handled by the native routine; this is not a blanket detonate-all policy.
  bool trigger(Board* board,Piece* source) const {
    return source && at<bool(*)(Board*,Piece*,Piece*)>(0x10016dd30)(board,source,nullptr);
  }
  void incrementMultiplier(Board* board) const {
    at<void(*)(Board*,Piece*)>(0x100164f34)(board,nullptr);
  }
  void flame(Board* board,Piece* source) const {
    at<void(*)(Board*,Piece*)>(0x1001653d0)(board,source);
  }
  void hypercube(Board* board,Piece* source,bool nativeFlag) const {
    at<void(*)(Board*,Piece*,bool)>(0x100165648)(board,source,nativeFlag);
  }
  void laser(Board* board,Piece* source) const {
    at<void(*)(Board*,Piece*)>(0x100165770)(board,source);
  }
};
}
