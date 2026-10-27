#pragma once
#include <cstdint>
extern "C" {
bool BJRoundInstall(uintptr_t slide);
bool BJRoundBegin(void *board);
void BJRoundObserve(void *board);
bool BJRoundActive(void *board);
bool BJRoundAddTimeTicks(void *board, int ticks);
bool BJRoundSetMultiplier(void *board, float multiplier);
uint64_t BJRoundGeneration(void *board);
}
