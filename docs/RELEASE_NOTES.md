# 0.0.22 — 2026-10-26

- Remove the loading/gameplay inset so the splash, menu, and board use the same full-window bounds.
- Reduce lower gameplay control artwork and matching touch geometry, and keep the row clear of the central menu button.
- Keep the accepted top-left multiplier and centered Auto-Hint/Help section.

The owner confirmed that 0.0.21 reached full screen after loading and the multiplier placement worked. The remaining button overlap shown on cover and inner displays motivates this update. Physical appearance and touch behavior of 0.0.22 still require device confirmation.

# 0.0.21 — 2026-10-26

First public mod-source release. The original game package and assets remain private inputs.

Changes from 0.0.20:

- Center Auto-Hint and Help together in the Classic/Zen options section. Keep both settings independently selectable and move their native labels and touch controls together.
- Add spacing between the lower gameplay controls and clearance from the right edge. Original button sizes and behavior remain intact; Blitz overlays follow their native control positions.
- Move the Blitz multiplier indicator from the top-right to the top-left.
- Preserve the accepted portrait-only policy, fold/resize lifecycle handling, full-screen background, original-style boost selector, selected icon, and triangular mode menu.
- Add public source documentation, explicit local build inputs, and asset-independent source checks.

Validation:

- Strict ARM64 Objective-C++ bridge compilation with warnings treated as errors.
- All 40 native patch spans checked against the exact P3 executable; no overlapping patches.
- Readback of changed native coordinate instructions.
- Boost-core host tests passed.
- IPA integrity, expected archive changes, and library-insertion text preservation checked.
- Public source packaging tested using separately supplied private inputs.

The owner reported 0.0.20 working well on Duo. Physical appearance and touch behavior of these 0.0.21 refinements still need on-device confirmation. No full regression or exact Blitz parity is claimed. The app retains Classic's engine; it does not include the separate Blitz engine.
