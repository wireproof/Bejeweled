#include <array>
#include <cstdint>
#include <cstring>
#include <algorithm>

// Geometry and art are changed together. Resizing a Bej3Button alone leaves
// its original sprite centered at its old size, so only these three HUD
// instances receive a private Draw vtable entry. Ownership/destruction stays native.
namespace {
std::uintptr_t imageSlide=0;
constexpr std::uintptr_t tableVA=0x1029fc370;
constexpr std::size_t tableBytes=0x2d8, addressPoint=0x10, drawSlot=0xd8;
std::array<std::uintptr_t,tableBytes/sizeof(std::uintptr_t)> table{};
bool initialized=false,compatible=false;
template<class T>T read(const void*p,std::size_t o){T v;std::memcpy(&v,static_cast<const char*>(p)+o,sizeof v);return v;}
template<class T>void write(void*p,std::size_t o,T v){std::memcpy(static_cast<char*>(p)+o,&v,sizeof v);}
template<class F>F fn(std::uintptr_t va){return reinterpret_cast<F>(imageSlide+va);}
void draw(void*button,void*graphics){
 const int w=read<int>(button,0x58),h=read<int>(button,0x5c);
 const int originalW=read<int>(reinterpret_cast<void*>(imageSlide+0x102eab154),0);
 const int originalH=read<int>(reinterpret_cast<void*>(imageSlide+0x102eab158),0);
 if(originalW<=0||originalH<=0){fn<void(*)(void*,void*)>(0x100128cbc)(button,graphics);return;}
 // Graphics::SetScale stores scale and pivot at0x18..0x24. The caller's
 // translation at0x10/0x14 is retained. Restore all four fields after drawing.
 float saved[4];std::memcpy(saved,static_cast<char*>(graphics)+0x18,sizeof saved);
 fn<void(*)(void*,float,float,float,float)>(0x100d38c98)(graphics,
    saved[0]*float(w)/originalW,saved[1]*float(h)/originalH,0.0f,0.0f);
 write(button,0x58,originalW);write(button,0x5c,originalH);
 fn<void(*)(void*,void*)>(0x100128cbc)(button,graphics);
 write(button,0x58,w);write(button,0x5c,h);
 std::memcpy(static_cast<char*>(graphics)+0x18,saved,sizeof saved);
}
bool prepare(std::uintptr_t slide){
 if(initialized)return compatible&&slide==imageSlide;
 initialized=true;imageSlide=slide;
 auto source=reinterpret_cast<void*>(slide+tableVA);
 if(read<std::uintptr_t>(source,addressPoint+drawSlot)!=slide+0x100128cbc ||
    read<std::uintptr_t>(source,addressPoint+0x148)!=slide+0x100129050 ||
    read<std::uint32_t>(reinterpret_cast<void*>(slide+0x100d38c98),0)!=0xd10083ff)return false;
 std::memcpy(table.data(),source,tableBytes);
 table[(addressPoint+drawSlot)/sizeof(std::uintptr_t)]=reinterpret_cast<std::uintptr_t>(&draw);
 compatible=true;return true;
}
}
extern "C" void BJHUDObserve(void*board,std::uintptr_t slide){
 if(!board||!prepare(slide))return;
 // RTTI survives the private Blitz board vtable clone. Reject other live
 // board classes before accessing the shared HUD member offsets.
 const auto boardTable=read<std::uintptr_t>(board,0);
 if(!boardTable||(boardTable&7))return;
 const auto type=read<std::uintptr_t>(reinterpret_cast<void*>(boardTable-8),0);
 if(type!=slide+0x1029cc668&&type!=slide+0x1029d2548&&type!=slide+0x1029d0968)return;
 const int boardW=read<int>(board,0x58);
 const int naturalW=read<int>(reinterpret_cast<void*>(slide+0x102eab154),0);
 const int naturalH=read<int>(reinterpret_cast<void*>(slide+0x102eab158),0);
 if(boardW<320||boardW>2048||naturalW<40||naturalW>200||naturalH<30||naturalH>150)return;
 const int w=naturalW*4/5,h=naturalH*4/5;
 const int gap=std::max(6,naturalW*12/100),inset=std::max(8,naturalW*16/100);
 const auto custom=reinterpret_cast<std::uintptr_t>(table.data())+addressPoint;
 // Left-to-right: supertool (Mystery/Detonator), tool (Scramble), hint.
 constexpr std::size_t offsets[]={0x7138,0x7130,0x7128};
 for(int i=0;i<3;++i){
  void*button=read<void*>(board,offsets[i]);if(!button)continue;
  auto vptr=read<std::uintptr_t>(button,0);
  if(vptr!=slide+tableVA+addressPoint&&vptr!=custom)continue;
  const int x=boardW-inset-w-(2-i)*(w+gap),y=read<int>(button,0x54);
  // Native Resize updates geometry and hit testing, retaining the profile's Y.
  fn<void(*)(void*,int,int,int,int)>(0x100ed0ac8)(button,x,y,w,h);
  write(button,0,custom);
 }
}
