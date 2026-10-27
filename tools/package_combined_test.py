"""Build the private experimental bridge against the immutable P3 package.

LiveContainer re-signs the final IPA on import. This script does not claim that
structural verification proves runtime correctness.
"""
import argparse
import hashlib
import json
import plistlib
import re
import struct
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
P3_SHA = '998a813e04e88333ac7dd69827264faeb5f79552fd4bef34eed855a470e9e2e0'
MAIN_SHA = '83a709bcc92fa36a3f567cda6e33652873a2c7c47c50142c008a15cf1f4eadc0'
APP = 'Payload/Bejeweled.app/'
LOAD_PATH = '@executable_path/Frameworks/WireproofBejeweled.dylib'

def digest(data):
    return hashlib.sha256(data).hexdigest()

def run(args):
    result = subprocess.run([str(x) for x in args], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    return result.stdout.strip()

def commands(data):
    assert struct.unpack_from('<I', data)[0] == 0xfeedfacf
    offset = 32
    for _ in range(struct.unpack_from('<I', data, 16)[0]):
        cmd, size = struct.unpack_from('<II', data, offset)
        assert size >= 8 and offset + size <= len(data)
        yield cmd, offset, size
        offset += size

def regions(data):
    result = []
    for cmd, pos, _ in commands(data):
        if cmd == 0x19:
            vm, _, off, size = struct.unpack_from('<QQQQ', data, pos + 24)
            result.append((vm, off, size))
    return result

def patch_binary(data, manifest):
    assert digest(data) == manifest.get('input_sha256', manifest.get('source_executable_sha256'))
    output = bytearray(data)
    used = set()
    for patch in manifest['patches']:
        va = int(patch['va'], 0)
        old = bytes.fromhex(patch.get('original', patch.get('original_hex', '')))
        new = bytes.fromhex(patch.get('replacement', patch.get('replacement_hex', '')))
        assert old and len(old) == len(new)
        matches = [off + va - vm for vm, off, size in regions(data) if vm <= va and va + len(old) <= vm + size]
        assert len(matches) == 1
        offset = matches[0]
        assert data[offset:offset + len(old)] == old, patch
        span = set(range(offset, offset + len(old)))
        assert not span & used
        used |= span
        output[offset:offset + len(old)] = new
    return bytes(output)

def text_sections(data):
    result = {}
    for cmd, pos, _ in commands(data):
        if cmd != 0x19:
            continue
        segment = data[pos + 8:pos + 24].split(b'\0')[0]
        if segment != b'__TEXT':
            continue
        count = struct.unpack_from('<I', data, pos + 64)[0]
        for n in range(count):
            section = pos + 72 + 80 * n
            name = data[section:section + 16].split(b'\0')[0].decode()
            size, offset = struct.unpack_from('<QI', data, section + 40)
            result[name] = digest(data[offset:offset + size])
    return result

def verify_macho(data):
    loads, cryptids = [], []
    for cmd, pos, size in commands(data):
        if cmd in (0xc, 0x80000018):
            nameoff = struct.unpack_from('<I', data, pos + 8)[0]
            loads.append(data[pos + nameoff:pos + size].split(b'\0')[0].decode())
        elif cmd == 0x2c:
            cryptids.append(struct.unpack_from('<I', data, pos + 16)[0])
    assert all(x == 0 for x in cryptids)
    return {'sha256': digest(data), 'cryptids': cryptids, 'dylibs': loads}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--patches', type=Path, action='append', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--build', required=True)
    parser.add_argument('--version', required=True, help='Private release version, e.g. 0.0.1')
    parser.add_argument('--base-ipa', type=Path, default=ROOT / 'releases/Bejeweled-P3.ipa')
    parser.add_argument('--ui-assets', type=Path, default=ROOT / 'integration/ui-assets')
    parser.add_argument('--icons', type=Path, default=ROOT / 'integration/app-icon')
    parser.add_argument('--insert-dylib', type=Path, required=True)
    parser.add_argument('--loader-rsb', type=Path, help='Private loader texture archive produced by package_loader_texture.py')
    parser.add_argument('--loader-report', type=Path)
    args = parser.parse_args()
    assert re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', args.version), 'Use major.minor.patch'
    assert args.build.isdecimal() and int(args.build) > 7835, 'Build must advance beyond delivered P5'
    assert args.output.name == f'Bejeweled-{args.version}.ipa', 'Filename must match release version'
    assert not args.output.exists(), 'Never overwrite a delivered build'
    source = args.base_ipa
    assert digest(source.read_bytes()) == P3_SHA
    sources = [ROOT / 'integration' / name for name in ('menu_bridge.mm', 'round_bridge.mm', 'boost_bridge.mm', 'presentation_bridge.mm', 'loadout_bridge.mm', 'scene_bridge.mm', 'hud_bridge.mm')]
    assert all(p.exists() for p in sources)
    assets_dir=args.ui_assets
    assets={APP+'WireproofUI/'+p.name:p.read_bytes() for p in sorted(assets_dir.glob('*.png'))}
    assert len(assets)>=1, 'Expected bundled UI assets'
    icons={APP+p.name:p.read_bytes() for p in sorted(args.icons.glob('*.png'))}
    assert len(icons)==6, 'Expected exact user-artwork app icon sizes'
    assets.update(icons)
    manifests = [json.loads(path.read_text()) for path in args.patches]
    for item in manifests:
        assert item.get('input_sha256', item.get('source_executable_sha256')) == MAIN_SHA
    manifest = {'input_sha256': MAIN_SHA, 'patches': [patch for item in manifests for patch in item['patches']]}
    sdk = run(['xcrun', '--sdk', 'iphoneos', '--show-sdk-path'])
    insert = args.insert_dylib
    with tempfile.TemporaryDirectory(prefix='bejeweled-combined-') as temp:
        temp = Path(temp)
        lib = temp / 'WireproofBejeweled.dylib'
        compile_command = ['xcrun', '--sdk', 'iphoneos', 'clang++', '-arch', 'arm64', '-isysroot', sdk,
                           '-miphoneos-version-min=15.0', '-std=c++17', '-fobjc-arc', '-dynamiclib',
                           '-Wall', '-Wextra', '-Werror', '-O2', '-framework', 'UIKit', '-framework', 'Foundation',
                           '-framework', 'QuartzCore', '-framework', 'CoreGraphics',
                           '-install_name', LOAD_PATH, *sources, '-o', lib]
        run(compile_command)
        run(['codesign', '--force', '--sign', '-', lib])
        run(['codesign', '--verify', '--strict', lib])
        library = lib.read_bytes()
        library_report = verify_macho(library)
        with zipfile.ZipFile(source) as archive:
            assert archive.testzip() is None
            original = archive.read(APP + 'Bejeweled')
            assert digest(original) == MAIN_SHA
            patched = patch_binary(original, manifest)
            executable = temp / 'Bejeweled'
            executable.write_bytes(patched)
            run([insert, '--inplace', '--all-yes', LOAD_PATH, executable])
            injected = executable.read_bytes()
            assert text_sections(patched) == text_sections(injected), 'Injection changed a text section'
            # Scene adapter now owns the native window lifecycle.
            adapted=bytearray(injected)
            for cmd,pos,size in commands(adapted):
                if cmd==0x32: struct.pack_into('<I',adapted,pos+16,(27<<16)|(1<<8))
            injected=bytes(adapted)
            main_report = verify_macho(injected)
            assert main_report['dylibs'].count(LOAD_PATH) == 1
            info = plistlib.loads(archive.read(APP + 'Info.plist'))
            info.update(CFBundleIdentifier='com.wireproof.bejeweled', CFBundleName='Bejeweled',
                        CFBundleDisplayName='Bejeweled', CFBundleVersion=args.build,
                        CFBundleShortVersionString=args.version)
            info['UIDeviceFamily']=[1,2]
            info['UISupportedInterfaceOrientations']=['UIInterfaceOrientationPortrait']
            info['UISupportedInterfaceOrientations~ipad']=info['UISupportedInterfaceOrientations']
            info['UIApplicationSceneManifest']={'UIApplicationSupportsMultipleScenes':False,'UISceneConfigurations':{'UIWindowSceneSessionRoleApplication':[{'UISceneConfigurationName':'Bejeweled','UISceneDelegateClassName':'BJSceneDelegate'}]}}
            info['DTSDKName']='iphoneos27.1'
            info['DTPlatformVersion']='27.1'
            # Remove stale original build labels rather than imply a full rebuild.
            for stale in ('DTSDKBuild','DTPlatformBuild','DTXcode','DTXcodeBuild','DTAppStoreToolsBuild'):
                info.pop(stale,None)
            icon_files=['WireproofIcon60x60','WireproofIcon76x76','WireproofIcon83.5x83.5']
            info.pop('CFBundleIconName',None)
            info.pop('CFBundleIconFile',None)
            info['CFBundleIconFiles']=icon_files
            info['CFBundleIcons']={'CFBundlePrimaryIcon':{'CFBundleIconFiles':icon_files,'UIPrerenderedIcon':True}}
            info['CFBundleIcons~ipad']=info['CFBundleIcons']
            replacements = {APP + 'Bejeweled': injected,
                            APP + 'Info.plist': plistlib.dumps(info, fmt=plistlib.FMT_BINARY, sort_keys=False)}
            if args.loader_rsb:
                assert args.loader_report, 'Loader patch report required'
                report = json.loads(args.loader_report.read_text())
                replacement = args.loader_rsb.read_bytes()
                assert digest(archive.read(APP+'main.rsb')) == report['source_sha256']
                assert digest(replacement) == report['output_sha256']
                assert report['other_group_records_and_payloads_identical']
                replacements[APP+'main.rsb'] = replacement
            hashes = {item.filename: digest(archive.read(item)) for item in archive.infolist()}
            with zipfile.ZipFile(args.output, 'x', compression=zipfile.ZIP_DEFLATED) as output:
                for item in archive.infolist():
                    output.writestr(item, replacements.get(item.filename, archive.read(item)))
                output.writestr(APP + 'Frameworks/WireproofBejeweled.dylib', library)
                for name,data in assets.items():output.writestr(name,data)
        with zipfile.ZipFile(args.output) as archive:
            assert archive.testzip() is None
            changed = [name for name in hashes if digest(archive.read(name)) != hashes[name]]
            assert set(changed) == set(replacements)
            added = sorted(set(archive.namelist()) - set(hashes))
            assert added == sorted([APP + 'Frameworks/WireproofBejeweled.dylib', *assets])
            assert all(archive.read(name)==data for name,data in assets.items())
    report = {'source': str(source), 'source_sha256': P3_SHA, 'output': str(args.output.resolve()),
              'output_sha256': digest(args.output.read_bytes()), 'bundle_id': info['CFBundleIdentifier'],
              'name': info['CFBundleDisplayName'], 'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'], 'changed_members': changed,
              'added_members': added, 'ui_assets': {name:digest(data) for name,data in assets.items()}, 'all_other_members_identical': True, 'zip_integrity': 'passed',
              'main': main_report, 'bridge': library_report,
              'source_files': {str(p.relative_to(ROOT)): digest(p.read_bytes()) for p in sources},
              'patch_manifest': manifest, 'runtime_tested': False,
              'mode': 'Experimental Blitz adaptation using Classic engine; not an exact Blitz engine transplant',
              'limitations': 'See README.md and docs/RELEASE_NOTES.md; device runtime validation pending.'}
    args.output.with_suffix('.verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ('output', 'output_sha256', 'changed_members', 'added_members', 'runtime_tested')}, indent=2))

if __name__ == '__main__':
    main()
