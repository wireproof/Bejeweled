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

Mod bridge source, guarded ARM64 patch manifests, a packaging tool, and boost-core tests. It does **not** include the original game executable, game artwork/audio, Apple provisioning profiles or signing credentials. Bejeweled and its original assets belong to their respective owners. This is an independent, unofficial modification, not an EA or PopCap release.

**This is not a standalone game or a source port of the original engine.** Blitz currently adapts Classic's timed engine; it does not bundle the separate Bejeweled Blitz engine and does not claim identical scoring or every Blitz feature. Rare Gems, online leaderboards, accounts, shops, and currency systems are not implemented. Some original Lightning presentation remains.

## Build and install

See [Build instructions](docs/BUILD.md). Native patches target one exact prepared P3 baseline and refuse mismatched inputs. You need your own compatible local game package, UI assets, Xcode, and signing setup. The repository alone cannot produce a playable IPA. An unsigned IPA is available on the [0.0.32 release page](https://github.com/wireproof/Bejeweled/releases/tag/v0.0.32); it requires your own signing and provisioning.

Run the asset-independent checks:

```sh
python3 tools/check_source.py
clang++ -std=c++17 -Wall -Wextra -Werror -pedantic blitz-core/test_boost_core.cpp -o /tmp/bejeweled-boost-test
/tmp/bejeweled-boost-test
```

## Status

Version 0.0.20 was tested by the owner on Duo and described as the best version to date. Version 0.0.32 hides counters on saved-game prompts and fits the Zen Options label inside its button; see [release notes](docs/RELEASE_NOTES.md) for validation and remaining device checks. Test results establish source/packaging correctness, not complete gameplay parity or compatibility with every device.

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

No license to the original game or its assets is granted. See [NOTICE](NOTICE).
