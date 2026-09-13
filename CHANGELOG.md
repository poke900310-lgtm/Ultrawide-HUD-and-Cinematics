# Changelog

## 1.0.0 — 2026-09-13

First public release.

### Added
- **HUD recentre.** Confine the box-aligned HUD to a centred aspect box, set with
  `HudAspect` and nudged with `HudWidthOffset`, using equal left/right slot
  padding. Nothing is scaled. Works at any resolution and aspect (21:9, 32:9,
  48:9, windowed) and does nothing at or below 16:9.
- **Cinematic bar removal.** Clear the camera aspect constraint and set
  MaintainYFOV so the field of view widens horizontally, revealing real scene
  instead of a stretched or cropped 16:9. `KeepVerticalFov = false` crops top and
  bottom instead.
- **Event-driven, low cost.** Reacts to camera spawns, cinematic transitions, and
  HUD rebuilds, each with a 300 ms follow-up, backed by a slow 5 s insurance net.
  No per-frame work. Type-safe property writes and IsValid gating throughout.
- Optional in-game toggle key, and an ini that works at zero configuration.
