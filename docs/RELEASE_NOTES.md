# 0.0.26 — 2026-10-26

- Show every equipped boost during Blitz, with AUTO/+5s indicators for passive boosts and remaining-use counts for Detonator and Scrambler.
- Correct Multiplier conversion: create the native multiplier gem rather than a blast gem. Matching it uses native collection and point-multiplier scoring.
- Extend the native countdown cap alongside Extra Time so the five extra seconds appear immediately as 1:05.
- Test the round dispatcher across all 26 valid loadouts, first activation, repeat updates, pause, use limits, reset, and the 30-second multiplier interval.

Mystery creates specials as matches occur; Extra Time and Multiplier run automatically. These are not tap-to-use controls. Physical gem collection, countdown, and final layout still require device confirmation. Exact original Blitz parity is not claimed; the adapter still omits the original extra-period score bonus, Scrambler speed bonus, and temporary Detonator multiplier bonus.

# 0.0.25 — 2026-10-26

- Lower Classic and Zen controls another four native units.
- Increase the right HUD inset to keep the original drawing inside the board before renderer scaling, addressing right-edge clipping.
- Move the Blitz multiplier twelve native units inward for rounded display corners.
- Enlarge Blitz power-up artwork and touch areas while keeping adjacent targets separated.

The owner confirmed Blitz activation and appearance in 0.0.24. Final spacing and clipping corrections require physical-device confirmation.

# 0.0.24 — 2026-10-26

- Restore Blitz menu activation independently of its cosmetic fade opacity. Keep the native fade and splash visibility checks.
- Lower the small gameplay controls eight native units, moving artwork and touch areas together without accumulating movement between frames.
- Preserve the corrected button rendering, portrait layout, top-left multiplier, and raised boost selector footer.

Physical tap behavior and final spacing require device confirmation.

# 0.0.23 — 2026-10-26

- Scale each lower native control as a complete drawing, fixing the cross-shaped gaps introduced by per-piece scaling in 0.0.22. Keep the smaller artwork and matching touch layout.
- Synchronize the Blitz menu overlay with the native menu transition so it does not appear over the splash screen.
- Lift Home and Play eight panel units inside the boost selector for cleaner bottom-border clearance.

Physical appearance and touch behavior require device confirmation. These changes preserve portrait presentation, gameplay, boost selection, scores, and the accepted top-left multiplier.

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
