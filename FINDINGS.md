# Dawnwalker ultrawide — investigation findings

The Blood of Dawnwalker, UE 5.5.4, Steam build 25232147. All facts below come
from asset/mappings/executable inspection with the AutoQTE toolchain (retoc +
UAssetAPI patcher `--schema` / `--list-props` / `--classify`, and byte scans of
`Dawnwalker.exe`). Each item is tagged **PROVEN** (from files) or **NEEDS TEST**
(requires an in-game observation).

## Problem 1 — HUD drifts to the physical edges at 21:9 / 32:9

**PROVEN — the HUD has no anchors to patch.** `WBP_GameHUD` is one widget
(`/Game/_Dawnwalker/UI/_Unified/HUD/WBP_GameHUD.WBP_GameHUD_C`) holding ~60 named
containers. Its tree is `Border → HorizontalBox (HAlign_Right/Left/Fill) →
Overlay / VerticalBox / SizeBox → containers`. There are **zero** `CanvasPanelSlot`
entries and zero `Anchors` in the whole widget (grep count 0). Elements are pinned
to the viewport edges purely by box **alignment**, evaluated against the live
viewport width every frame.

Consequences that decide the approach:
- There is nothing static to edit. A `.pak` asset edit would have to *reparent*
  the tree into a width-limited box — a large, fragile change to a cooked UMG
  `WidgetTree`, not a two-byte edit.
- The correct position depends on the runtime viewport width, which only exists
  at runtime.
- The game rebuilds the HUD on level transitions (a cached HUD reference stops being valid and must be re-acquired), so any fix must re-apply itself.

**PROVEN — the game's UI config is not reachable in the containers.**
`DesignScreenSize`, `UIScaleRule`, `r.SafeZone`, `ApplicationScale` are all absent
from `Dawnwalker-Windows.ucas`; they are engine defaults or in the pak filesystem.
So the tidy "set a project UI setting" route is not available to a mod.

**PROVEN — the runtime plumbing works.** An existing HUD mod acquires
`WBP_GameHUD_C` with `FindAllOf`, survives rebuilds by re-searching when a cached
instance stops being `IsValid`, and moves widgets by writing `RenderTransform`
then calling `SetRenderTransformAngle` once (the only setter that pushes the whole
transform to Slate). It never reads the viewport or aspect ratio — it is a manual
per-element nudge tool, so it recenters nothing on its own.

**Decision: a UE4SS Lua mod.** It is the only layer that can read the live
viewport and re-centre a box-aligned HUD, and it needs no risky reparenting of a
cooked asset. The lever is to confine the HUD to a **centred, configurable-width
box** so every box-aligned child falls back to its 16:9 position. The exact write
that achieves this (padding on the root `Border`/`HorizontalBox` slot, a
`SizeBox` width override, or a root `RenderTransform`) is the one thing that must
be confirmed in game — see the probe below.

## Problem 2 — cinematics fall back to 16:9 with black bars

**PROVEN — the cinematic cameras are authored 16:9.** `BP_CAMERA_CINE` and
`BP_CAMERA_DIALOG` both set `CameraComponent.AspectRatio = 1.7777778`;
`BP_CAMERA_DIALOG` also sets an explicit `Filmback` sensor of 36 × 20.25 mm
(= 16:9). The executable contains the symbols `AspectRatioBars` and
`SetLetterbox`, and the camera schema exposes `bConstrainAspectRatio` +
`AspectRatioAxisConstraint`.

**PROVEN — there is a cinematic overlay widget.** `BP_PlayerHUD` holds an
`Active Cinematic Sequence Overlay Widget` and an `In Cinematic Mode` bool.
`WBP_QuestLevelSequenceOverlay` exists and its tree contains `Top` / `Bottom` /
`Bar` / `SizeBox` elements — the shape of a letterbox. (The `Matte` and `Bars_`
search hits were all false positives: plants, ARKit, prison-bar animations.)

**NEEDS TEST — which of two layers actually produces the bars the player sees.**
Two mechanisms are present and they are removed differently:
1. **Camera aspect constraint** — if cinematic mode sets `bConstrainAspectRatio =
   true` on the active camera (the engine then draws hard bars *below* all UMG).
   Removed by clearing that flag on the live camera (UE4SS) or on the camera
   assets (`.pak`).
2. **A letterbox widget** (`WBP_QuestLevelSequenceOverlay` or a dialogue-specific
   overlay) drawn on top during cinematic mode. Removed by collapsing that widget
   — cleanly and statically via a `.pak` `Visibility = Collapsed` default (the
   proven AutoQTE technique), or at runtime.

The decisive observation: enter a cinematic that shows bars, and check whether the
bars sit **behind** the HUD/subtitles (camera constraint) or are part of the UI
layer, and whether the scene geometry beyond 16:9 is actually being rendered
(only then can the bars be removed without stretching). Prerendered Bink cutscenes
(`BMASM_Bink_DS_OverlayFillScreenWithAspectRatio`) are genuine 16:9 video and must
be left alone — widening them would stretch.

## Chosen shape

- **One UE4SS Lua mod** for both problems: it is already required for problem 1,
  adds no dependency, and is fully configurable per the request.
- Problem 1: read the viewport each time the HUD is (re)built, compute a
  horizontal inset for a configurable target aspect (default 16:9, adjustable
  inward/outward), and apply it to the HUD root; re-apply on rebuild. Menus and
  already-centred UI are left untouched.
- Problem 2: once the in-game test says which layer draws the bars, either clear
  the camera constraint on cinematic entry or collapse the letterbox widget. If it
  turns out to be a pure widget, a tiny optional `.pak` is offered for people
  without UE4SS, exactly as AutoQTE ships two editions.

Nothing here is committed or installed yet; the game folder is stock.
