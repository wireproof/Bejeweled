from pathlib import Path
import struct,zlib,json,hashlib
import numpy as np
from PIL import Image
import argparse
ap=argparse.ArgumentParser();ap.add_argument('--source-rsb',type=Path,required=True);ap.add_argument('--badge-480',type=Path,required=True);ap.add_argument('--badge-960',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);args=ap.parse_args()
assert not args.output.exists()
b=args.source_rsb.read_bytes();result=bytearray(b);u=lambda data,o:struct.unpack_from('<I',data,o)[0];align=lambda n:(n+4095)&~4095
groups=[];changes=[];reports=[]
for i in range(u(b,0x28)):
 q=u(b,0x2c)+i*u(b,0x30);v=struct.unpack_from('<19I',b,q+128)
 groups.append((b[q:q+128].split(b'\0')[0].decode(),q,v))
for scale in [480,960]:
 name,q,v=next(g for g in groups if g[0]==f'Loader_{scale}');w,h,pitch,fmt=struct.unpack_from('<4I',b,u(b,0x58)+v[18]*u(b,0x5c));assert fmt==21
 r=b[v[0]:v[0]+v[1]];toff=u(r,0x28);raw=zlib.decompress(r[toff:toff+u(r,0x2c)])
 words=np.frombuffer(raw,dtype='<u2').reshape(h//32,w//32,32,32).transpose(0,2,1,3).reshape(h,w).copy();old=words.copy()
 # Encode the image-generator edit into the original GPU texture format.
 file=args.badge_480 if scale==480 else args.badge_960;a=np.asarray(Image.open(file).convert('RGBA'),dtype='uint16');hh,ww=a.shape[:2]
 encoded=sum(((a[:,:,i]+8)//17).clip(0,15)<<shift for i,shift in enumerate([12,8,4,0]));words[:hh,:ww]=encoded
 assert np.array_equal(words[hh:],old[hh:]) and np.array_equal(words[:hh,ww:],old[:hh,ww:])
 packedRaw=words.reshape(h//32,32,w//32,32).transpose(0,2,1,3).astype('<u2').tobytes();packed=zlib.compress(packedRaw,9);allocation=align(len(packed));nr=bytearray(r[:toff]);struct.pack_into('<I',nr,0x2c,allocation);nr+=packed+bytes(allocation-len(packed));offset=align(len(result));result+=bytes(offset-len(result))+nr
 for o,value in [(q+128,offset),(q+132,len(nr)),(q+168,allocation)]:struct.pack_into('<I',result,o,value);changes.append((o,4))
 assert zlib.decompress(nr[toff:])==packedRaw
 reports.append({'group':name,'changed_pixels':int(np.count_nonzero(words!=old)),'same_dimensions_and_format':True})
for name,q,v in groups:
 if name.startswith('Loader_'):continue
 assert result[q:q+u(b,0x30)]==b[q:q+u(b,0x30)]
 assert result[v[0]:v[0]+v[1]]==b[v[0]:v[0]+v[1]]
allowed=np.zeros(len(b),bool)
for o,n in changes:allowed[o:o+n]=True
assert np.array_equal(np.frombuffer(b,dtype='uint8')[~allowed],np.frombuffer(result[:len(b)],dtype='uint8')[~allowed])
p=args.output;p.write_bytes(result)
args.output.with_suffix('.verification.json').write_text(json.dumps({'source_sha256':hashlib.sha256(b).hexdigest(),'output_sha256':hashlib.sha256(result).hexdigest(),'groups':reports,'other_group_records_and_payloads_identical':True,'resource_definitions_unchanged':True,'animation_code_unchanged':True},indent=2))
print(reports)
