#pragma once
#include <cstdint>
extern "C" {
bool BJBoostCompatible(std::uintptr_t slide);
void BJBoostBegin(std::uintptr_t slide, std::uint64_t generation);
void BJBoostUpdate(void* liveBoard, std::uint64_t generation, bool active, std::int64_t elapsedTicks);
void BJBoostMatch(void* liveBoard, std::uint64_t generation);
void BJBoostEnd(std::uint64_t generation);
}
