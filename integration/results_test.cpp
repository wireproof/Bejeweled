#include "results_bridge.hpp"
#include <cassert>
int main(){
 const int thresholds[]={25000,50000,75000,100000,125000,150000,175000,200000,225000,250000,300000,350000,400000,450000,500000,1000000,3000000,5000000,10000000};
 assert(BJResultsMilestone(-1).progress==0);
 assert(BJResultsMilestone(0).next==25000);
 for(int i=0;i<19;i++){
  auto below=BJResultsMilestone(thresholds[i]-1);
  assert(below.reached==i&&below.next==thresholds[i]);
  assert(below.progress>=0&&below.progress<=1);
  auto at=BJResultsMilestone(thresholds[i]);
  assert(at.reached==i+1);
  assert(at.next==(i==18?0:thresholds[i+1]));
 }
 auto complete=BJResultsMilestone(2147483647);
 assert(complete.reached==19&&complete.next==0&&complete.progress==1);
}
