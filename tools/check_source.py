"""Asset-independent guard and source-release checks."""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
expected = '83a709bcc92fa36a3f567cda6e33652873a2c7c47c50142c008a15cf1f4eadc0'
used = set()
count = 0
for path in sorted((ROOT / 'integration').glob('*patch_manifest.json')):
    manifest = json.loads(path.read_text())
    assert manifest.get('input_sha256', manifest.get('source_executable_sha256')) == expected, path
    for patch in manifest['patches']:
        address = int(patch['va'], 0)
        old = bytes.fromhex(patch.get('original', patch.get('original_hex', '')))
        new = bytes.fromhex(patch.get('replacement', patch.get('replacement_hex', '')))
        assert old and len(old) == len(new) and address % 4 == 0, (path, patch)
        span = set(range(address, address + len(old)))
        assert not used & span, ('Overlapping patches', path, patch)
        used |= span
        count += 1
compile((ROOT / 'tools/package_combined_test.py').read_text(), 'package_combined_test.py', 'exec')
print(f'PASS: {count} guarded patches, no overlap, packaging syntax valid')
