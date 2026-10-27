# Local build instructions

## Requirements and boundary

Use macOS with Xcode command-line tools and an iPhoneOS SDK, Python 3, and an ARM64-compatible `insert_dylib` utility supplied separately. The maintained build uses Xcode/iPhoneOS SDK 27.1. Device reports in this project concern iOS/iPadOS 27.2; that is not a claim that the entire original game was recompiled with that SDK.

The bridge is compiled from source. The retained game executable is patched, and its SDK declaration is updated alongside the scene adapter. The original game is **not** rebuilt from source.

The current builder accepts exactly the private prepared P3 package:

| Input | SHA-256 |
| --- | --- |
| `Bejeweled-P3.ipa` | `998a813e04e88333ac7dd69827264faeb5f79552fd4bef34eed855a470e9e2e0` |
| Main executable inside that package | `83a709bcc92fa36a3f567cda6e33652873a2c7c47c50142c008a15cf1f4eadc0` |

P3 is an earlier privately prepared baseline, **not an unmodified App Store download**. It already contains the startup cleanup and launch resources. Neither that baseline nor a general stock-to-P3 conversion is distributed here. If you do not already have the compatible baseline, these sources are useful for inspection and adaptation but are not a complete playable-game build kit. Do not bypass the hash guards to try another version.

## Prepare local inputs

Keep all private inputs under ignored `inputs/`:

```text
inputs/Bejeweled-P3.ipa
inputs/ui-assets/           # PNGs listed in docs/asset-inputs.json
inputs/app-icon/            # six PNGs listed in docs/asset-inputs.json
inputs/insert_dylib         # separately supplied executable
```

The asset inventory records names, sizes and hashes only. It does not supply artwork. The UI uses the named original-style PNGs and twenty orb animation frames; do not substitute files with different geometry without adjusting the layout code. The chosen app icon is also a private input.

## Package

```sh
mkdir -p dist
python3 tools/check_source.py
python3 tools/package_combined_test.py \
  --base-ipa inputs/Bejeweled-P3.ipa \
  --ui-assets inputs/ui-assets \
  --icons inputs/app-icon \
  --insert-dylib inputs/insert_dylib \
  --patches integration/menu_patch_manifest.json \
  --patches integration/round_patch_manifest.json \
  --patches integration/presentation_patch_manifest.json \
  --patches integration/promotions_patch_manifest.json \
  --patches integration/triangle_patch_manifest.json \
  --patches integration/window_patch_manifest.json \
  --patches integration/options_layout_patch_manifest.json \
  --patches integration/hud_layout_patch_manifest.json \
  --version 0.0.31 --build 7866 \
  --output dist/Bejeweled-0.0.31.ipa
```

The tool refuses to overwrite an existing output. It verifies baseline hashes, exact bytes, patch overlap, archive integrity, preserved text during library insertion, and expected changed/added members. The adjacent verification JSON records build evidence. It may contain local paths; review it before sharing.

## Sign and install

The packaging output is **not ready for direct device installation**. Sign the app and embedded frameworks with your own Apple development identity and a matching provisioning profile for `com.wireproof.bejeweled` (or adapt the identity deliberately). Use Xcode's device workflow or your established signing process. Do not upload provisioning profiles or signed device builds to this public repository.

After signing and verifying the app, Xcode's device tools can install your local `.app`:

```sh
xcrun devicectl list devices
xcrun devicectl device install app --device YOUR_DEVICE_ID /absolute/path/Bejeweled.app
xcrun devicectl device process launch --device YOUR_DEVICE_ID com.wireproof.bejeweled
```

Keep the same bundle identifier and signing team for updates. Do not uninstall an existing app merely to update it; uninstalling removes its data. LiveContainer and a directly installed app have separate containers; automatic save migration is not implemented.

## Device checks

Verify cold launch, cover-to-inner folding, portrait stability, background/foreground, Classic and Zen settings, every lower control's touch target, Blitz loadout persistence, countdown, multiplier visibility, and best-score persistence. Host tests cannot establish these physical behaviors.

Optional private loading badge: use `tools/package_loader_texture.py` with the baseline main.rsb and edited 184×184 / 367×368 badge PNGs, then supply its output with `--loader-rsb` and its verification JSON with `--loader-report`. These derivative textures remain private; native loading code and resource geometry stay unchanged.
