## 0.0.30 — 2026-10-26

- Classic Mystery and Shuffle each have an independent rolling limit of 10 uses per real-time 24 hours. Usage persists across relaunch, guards against backward clock changes, and displays time until the next use returns. Hints remain unlimited. Busy or ineligible actions do not spend a charge.
- Replace the Lightning results dialog and its sample leaderboard with local Blitz results: final score, Last Hurrah bonus, highest multiplier, personal best, equipped boosts, and progress through 19 original Blitz score milestones. Preserve native final-special processing.
- Add offline level selection for Scrambler (2–15 uses) and Multiplier (30–5 second intervals), using the original eleven-level values. All levels are freely selectable; no invented coin economy. Mystery and Extra Time remain tap-to-use as requested.
- Stop leftover Lightning +5/+10 banked-time gems spawning in Blitz.
- Preserve portrait layout, loading gem, and separate speed/multiplier labels.

Validation: all four host test suites, guarded source checks, and iOS compilation passed. Device gameplay and the new results flow still require owner verification. Install onto Duo without launching.

This begins offline expansion; Rare Gems, quests, events, online services, and full scoring parity remain unfinished. Detonator temporary multiplier, Scrambler speed bonus, and Extra Time extra-period score bonus remain unimplemented. The supplied original-game recording showed menus and download-dependent content, not its end-of-round screen; this results panel is a local adaptation.

## 0.0.29

- Move the animated Blitz SPEED bonus label and value to their own column between the multiplier and score. Keep the scaling pivot and highlight clipping aligned.
- Preserve the gem loading badge and existing boost behavior.
- Installed on Duo without launching; physical gameplay appearance remains to be checked.

# 0.0.28 — 2026-10-26

- Replace PopCap lettering in the private loading badge with a centered blue faceted gem.
- Retain the original ring except the small lettering overhang repair; preserve outer alpha, native loader animation, timing, and resource dimensions in both resolution variants.
- Add a bounded loader archive packager that verifies other resource groups remain identical. Derivative game textures are private build inputs.
- Preserve 0.0.27 boost behavior. All 26 loadout logic tests passed previously; native code paths were inspected, but complete device gameplay validation remains pending. Detonator temporary multiplier and Scrambler speed bonuses remain unimplemented.

Install on Duo without launching.

# 0.0.27 — 2026-10-26

- Make Mystery and Extra Time tap-to-use, one use each per round, as requested.
- Mystery immediately requests one random special gem, deferring until a settled gem is available if the board is cascading.
- Extra Time adds five seconds when tapped; it no longer activates at round start.
- Show remaining uses, disable/dim spent controls, and update the boost selection descriptions. Multiplier remains automatic; Detonator and Scrambler retain two uses.
- Extend all-loadout tests to reject paused/unequipped clicks, prevent repeated use, verify no automatic consumption, and restore uses on round reset.

Install on Duo only; do not launch automatically. Physical activation still needs device confirmation.

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
