# Changelog

## 1.0.2 — 2026-09-15

Crash fix. Two access-violation crashes were traced to the camera de-bar path
holding camera references across game ticks: a camera destroyed during rapid
cinematic transitions (spamming skip through dialogue) could then be reached
through a stale handle, which even a validity check cannot safely test. The fix
came from three independent design passes that converged on the same approach.

### Fixed
- The camera de-bar no longer keeps a persistent list of cameras. Each pass now
  looks up the currently-live cameras fresh and de-bars them in the same step,
  holding no reference past it, so a camera freed during rapid dialogue-skipping
  can no longer be reached through a stale handle.
- Spawn and cinematic-transition triggers are coalesced, so rapid skipping no
  longer stacks async callbacks.
- The camera scan now runs only while a cinematic is actually active (read from
  the player controller's cinematic-mode state), so normal gameplay does no
  object-array walks at all. It still catches mid-cinematic camera cuts.

## 1.0.1 — 2026-09-13

Bug fixes from an independent code review. Three validators checked every
reported claim; only the defects all three confirmed were changed.

### Fixed
- Disabling the mod now fully stops the cinematic fix. The camera enforcement
  path was not gated on the enabled flag, so a cinematic transition could still
  clear the aspect constraint on already-tracked cameras while the mod was off.
- Re-enabling now rescans existing cameras, so a camera that appeared while the
  mod was disabled (including when started with `Enabled = false`) is picked up.
- The shipped README no longer points to `FINDINGS.md` as if it were in the
  download; it notes the file lives in the project repository.

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
