"""Rebuild the bridge using an exact, completed 0.0.32 package as baseline.

This avoids depending on the retired P3 archive. No source hash guard is bypassed.
The resulting package must be signed locally before device installation.
"""
import argparse, hashlib, json, plistlib, subprocess, tempfile, zipfile
from pathlib import Path
from package_combined_test import ROOT, APP, LOAD_PATH, run, regions, verify_macho
BASES = {'dd506b30a028f502ba021cf218530c5d627496a8f2f9aa35040c3bbe4de56f04',
         '4acad8fd1794b585caf370b4fb5bdbce9ddd9a96b55d289120a5f01d899724ad'}
def sha(b): return hashlib.sha256(b).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--base-ipa',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 assert not a.output.exists()
 source=a.base_ipa.read_bytes();assert sha(source) in BASES,'Unrecognized baseline'
 sdk=run(['xcrun','--sdk','iphoneos','--show-sdk-path'])
 names=['menu','round','boost','presentation','loadout','scene','hud','classic_daily','results']
 with tempfile.TemporaryDirectory() as td:
  lib=Path(td)/'WireproofBejeweled.dylib'
  run(['xcrun','--sdk','iphoneos','clang++','-arch','arm64','-isysroot',sdk,'-miphoneos-version-min=15.0','-std=c++17','-fobjc-arc','-dynamiclib','-Wall','-Wextra','-Werror','-O2','-framework','UIKit','-framework','Foundation','-framework','QuartzCore','-framework','CoreGraphics','-install_name',LOAD_PATH,*[ROOT/'integration'/f'{n}_bridge.mm' for n in names],'-o',lib])
  run(['codesign','--force','--sign','-',lib]);run(['codesign','--verify','--strict',lib]);library=lib.read_bytes()
  with zipfile.ZipFile(a.base_ipa) as z:
   assert z.testzip() is None
   info=plistlib.loads(z.read(APP+'Info.plist'));assert (info['CFBundleShortVersionString'],info['CFBundleVersion'])==('0.0.32','7867')
   old=z.read(APP+'Bejeweled');new=bytearray(old)
   patch=next(x for x in json.loads((ROOT/'integration/presentation_patch_manifest.json').read_text())['patches'] if x['va']=='0x100fa1298')
   replacement=bytes.fromhex(patch['replacement']);expected=replacement.replace(bytes.fromhex('093c8052'),bytes.fromhex('09478052'))
   va=int(patch['va'],16);offset=next(off+va-vm for vm,off,size in regions(old) if vm<=va<vm+size)
   assert old[offset:offset+len(expected)]==expected,'0.0.32 native canvas guard failed'
   new[offset:offset+len(replacement)]=replacement
   changes=[i for i,(x,y) in enumerate(zip(old,new)) if x!=y];assert len(changes)==1
   assert verify_macho(new)['dylibs'].count(LOAD_PATH)==1
   info.update(CFBundleShortVersionString='0.0.33',CFBundleVersion='7868')
   replacements={APP+'Bejeweled':bytes(new),APP+'Info.plist':plistlib.dumps(info),APP+'Frameworks/WireproofBejeweled.dylib':library}
   removed=[]
   with zipfile.ZipFile(a.output,'x',zipfile.ZIP_DEFLATED) as out:
    for item in z.infolist():
     n=item.filename
     if not n.startswith('Payload/') or '/SC_Info/' in n or '/_CodeSignature/' in n or n.endswith('embedded.mobileprovision'):removed.append(n);continue
     out.writestr(item,replacements.get(n,z.read(n)))
  with zipfile.ZipFile(a.output) as out,zipfile.ZipFile(a.base_ipa) as z:
   assert out.testzip() is None
   changed=[n for n in out.namelist() if out.read(n)!=z.read(n)];assert set(changed)==set(replacements)
  report={'version':'0.0.33','build':'7868','baseline_sha256':sha(source),'output_sha256':sha(a.output.read_bytes()),'changed_members':changed,'removed_metadata':removed,'native_changed_bytes':changes,'all_other_members_identical':True,'runtime_tested':False}
  a.output.with_suffix('.verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
