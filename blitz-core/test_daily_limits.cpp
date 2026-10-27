#include "daily_limits.hpp"
#include <cassert>
#include <iostream>
int main(){
 classic::DailyLimits q;
 const std::int64_t t=1800000000;
 assert(q.remaining(0,t)==10&&q.remaining(1,t)==10);
 for(int i=0;i<10;++i)assert(q.consume(0,t+i*60));
 assert(!q.consume(0,t+600));assert(q.remaining(1,t+600)==10);
 assert(q.remaining(0,t+86399)==0);
 assert(q.remaining(0,t+86400)==1);
 assert(q.consume(0,t+86400));assert(q.remaining(0,t+86400)==0);
 assert(q.remaining(0,t+86460)==1);
 // Restoring the persisted state preserves usage and resists clock rollback.
 classic::DailyLimits restored;restored.spent=q.spent;restored.highWater=q.highWater;
 assert(restored.remaining(0,t-100000)==1);
 assert(restored.consume(0,t-100000));assert(restored.remaining(0,t)==0);
 assert(restored.untilNext(0,t)==60);
 for(int i=0;i<10;++i)assert(restored.consume(1,t+86460));
 assert(!restored.consume(1,t+86460));
 assert(restored.remaining(1,t+86460+86399)==0);
 assert(restored.remaining(1,t+86460+86400)==10);
 assert(restored.remaining(0,t+86460+86400)==10);
 assert(!restored.consume(2,t));assert(restored.untilNext(2,t)==0);
 classic::DailyLimits bad;bad.spent[0]={0,-1,t};assert(bad.remaining(0,t)==9);
 classic::DailyLimits future;future.spent[0]={t+3600};
 assert(future.remaining(0,t)==9);assert(future.untilNext(0,t)==90000);
 assert(future.remaining(0,t+90000)==10);
 classic::DailyLimits excess;for(int i=0;i<20;++i)excess.spent[0].push_back(t+i);
 assert(excess.remaining(0,t+20)==0);assert(excess.spent[0].size()==10);
 classic::DailyLimits zero;assert(!zero.consume(0,0));
 std::cout<<"daily limits: rolling windows, independent quotas, relaunch, rollback and boundaries passed\n";
}
