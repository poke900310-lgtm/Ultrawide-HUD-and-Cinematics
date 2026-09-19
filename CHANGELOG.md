# Changelog

## 1.0.4 — 2026-09-19

### Changed
- **Cinematic bars are now cleared purely on events — the camera is never swept on a
  timer.** Bars are already prevented at the source (each camera is de-barred the
  instant it is created), so the periodic safety pass over the active camera was
  removed: in testing it never did useful work (no camera was ever found barred), and
  in a missed-event case its only effect would have been to pop bars away a few seconds
  after they appeared, which reads worse than a clean, consistent frame. The cinematic
  path now does zero steady-state work. The slow HUD re-centre backstop is kept: it is
  what catches a resolution or window change (which fires no event) and never causes a
  visible flash.

## 1.0.3 — 2026-09-17

A major reliability and correctness overhaul — the first update since 1.0.1. The
cinematic bar removal was rebuilt to be crash-safe and to touch only the camera
you are actually looking through, and a HUD recentre bug that displaced HUD
elements was fixed.

### Fixed
- **Crash safety.** The player controller and the HUD widget are no longer kept
  from one game tick to the next. On a level or save load the engine frees them,
  and even a validity check on a freed handle can itself fault; the controller is
  now re-derived every pass from live engine state (with a fresh fallback lookup)
  and the HUD is found fresh, so a stale handle can never be reached. This closes
  the access-violation crashes seen on loads and during rapid dialogue skipping.
- **HUD padding no longer destroyed.** Recentring previously overwrote every HUD
  container's padding and zeroed the top/bottom (and left/right) offsets the game
  authors to keep elements apart — which could make the weapon / special-ability
  icon overlap the quick-slot bar, most visibly at 21:9, and did not clear even
  with the inset forced to zero. It now captures each container's original padding
  once and only adds the recentre inset to the sides, preserving the game's own
  spacing; turning the mod off restores that original padding instead of zeroing
  it. Thanks to the player who reported and diagnosed the overlap.

### Changed
- **Cinematic bars are cleared preemptively, one camera at a time.** Instead of
  scanning every camera in the game on each pass, each camera is de-barred the
  instant it is created — before it can ever be shown — and the on-screen camera
  is resolved directly from the camera manager. No per-frame work and no full
  object-array scan remain; normal gameplay does essentially nothing.

### Added
- **`Trace` setting** (off by default) for detailed per-pass diagnostics when
  reporting a bug, plus timestamps on log lines.

## 1.0.2 — 2026-09-15 (internal; not released, superseded by 1.0.3)

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
