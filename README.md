# Bejeweled — WIREPROOF mod

A portrait-first iPhone and iPad adaptation of Bejeweled Classic, preserving its native Classic and Zen gameplay and adding a selectable Blitz-style timed mode in the same app. The project focuses on comfortable play across Duo's cover and inner displays, original-style controls, and direct device installation.

## Features

- Classic and Zen retain the original game engine and presentation.
- Blitz-style 60-second rounds, a five-boost loadout with up to three selected boosts, and a locally saved best score.
- Mystery, Detonator, Scrambler, Extra Time, and Multiplier boosts. Detonator has two uses per round; Scrambler has selectable original levels (2–15 uses).
- Classic Mystery and Shuffle each allow 10 uses per rolling 24 hours, saved locally; hints remain unlimited.
- Blitz results include Last Hurrah, best score, highest multiplier, and 19 original score milestones.
- Offline Scrambler and Multiplier level selection, without an online currency economy.
- A triangular main menu: Blitz above Classic and Zen.
- Portrait-only presentation, fold/resize handling, and a background that fills unused space without cropping the board.
- An original-style boost selection panel and streamlined startup/menu flows.
- One application, with support for locally signed direct installation; LiveContainer is not required.

## What this repository contains

Mod bridge source, guarded ARM64 patch manifests, packaging tools, host tests, UI artwork, approved app icons, and the packaged game's visual, audio, localization and interface resources. See `assets/manifest.json` for file hashes. The release includes an unsigned IPA for signing with your own setup.

This is an unofficial modification of the retained native game engine, not a standalone engine source port. Blitz adapts the timed engine and remains an offline implementation: Rare Gems, quests, online events, accounts, shops and currency systems are not implemented. Detonator's temporary multiplier, Scrambler's speed bonus and Extra Time's extra-period score bonus remain incomplete.

## Build and install

See [Build instructions](docs/BUILD.md). Native patches target one exact prepared P3 baseline and refuse mismatched inputs. You need the compatible prepared baseline, Xcode, the insertion utility, and your own signing setup; UI assets and icons are included. The repository alone cannot produce a playable IPA. An unsigned IPA is available on the [0.0.33 release page](https://github.com/wireproof/Bejeweled/releases/tag/v0.0.33); it requires your own signing and provisioning.

Run the asset-independent checks:

```sh
python3 tools/check_source.py
clang++ -std=c++17 -Wall -Wextra -Werror -pedantic blitz-core/test_boost_core.cpp -o /tmp/bejeweled-boost-test
/tmp/bejeweled-boost-test
```

## Status

November 15, 2026 audit: both Duo and the 11-inch iPad Pro report 0.0.32 (7867). Identical versions were not reinstalled and neither device was launched. Runtime and visual checks were not performed during this audit.

Version 0.0.20 was tested by the owner on Duo and described as the best version to date. Version 0.0.33 corrects iPad portrait side gutters by matching native and UIKit canvas dimensions at 320×480; Duo geometry stays unchanged. Version 0.0.32 fixed resume counters and the Zen label; see [release notes](docs/RELEASE_NOTES.md) for validation and remaining device checks. Test results establish source/packaging correctness, not complete gameplay parity or compatibility with every device.

The public IPA has account and signing metadata removed and service configuration keys blanked. Its game binaries are unchanged, but this sanitized package has not been runtime-tested.

## Source map

| Location | Purpose |
| --- | --- |
| `integration/menu_bridge.mm` | Original menu integration and native frame callbacks |
| `integration/round_bridge.mm` | Timed-round rules and native board hooks |
| `integration/hud_bridge.mm` | Lower-control artwork scaling and native touch geometry |
| `integration/boost_bridge.mm` | Boost execution and in-game controls |
| `integration/loadout_bridge.mm` | Boost picker and local selection/high-score persistence |
| `integration/presentation_bridge.mm` | Rendering geometry and lifecycle handling |
| `integration/scene_bridge.mm` | Window scene integration and portrait policy |
| `integration/*patch_manifest.json` | Exact-byte, hash-guarded native changes |
| `blitz-core/` | Boost rules and host-side tests |
| `tools/` | Packaging and source checks |

See [NOTICE](NOTICE) for attribution.
