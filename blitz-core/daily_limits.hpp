#pragma once
#include <algorithm>
#include <array>
#include <cstdint>
#include <vector>

namespace classic {
// A rolling window: each spent charge returns 24 real-time hours later.
// Persist both histories and highWater. Moving the clock backwards cannot
// replenish a charge; without a server, intentional forward changes cannot
// be distinguished from genuine offline elapsed time.
class DailyLimits {
public:
 static constexpr std::int64_t window=24*60*60;
 static constexpr int limit=10;
 using History=std::array<std::vector<std::int64_t>,2>;
 History spent{};
 std::int64_t highWater=0;
 std::int64_t advance(std::int64_t wall) {
  highWater=std::max(highWater,std::max<std::int64_t>(0,wall));
  for(auto &h:spent){
   h.erase(std::remove_if(h.begin(),h.end(),[&](auto t){return t<=0||(highWater>=t&&highWater-t>=window);}),h.end());
   std::sort(h.begin(),h.end());
   if(h.size()>limit)h.erase(h.begin(),h.end()-limit);
  }
  return highWater;
 }
 int remaining(unsigned tool,std::int64_t wall){advance(wall);return tool<spent.size()?limit-static_cast<int>(spent[tool].size()):0;}
 bool consume(unsigned tool,std::int64_t wall){if(!remaining(tool,wall)||highWater<=0)return false;spent[tool].push_back(highWater);return true;}
 std::int64_t untilNext(unsigned tool,std::int64_t wall){advance(wall);if(tool>=spent.size()||spent[tool].empty())return 0;return std::max<std::int64_t>(0,spent[tool].front()+window-highWater);}
};
}
