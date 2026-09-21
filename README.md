# Ultrawide HUD and Cinematics — The Blood of Dawnwalker

Two fixes for ultrawide (21:9 / 32:9 and anything wider), in one small UE4SS Lua
mod:

- **HUD recentre.** The HUD is laid out against the full viewport width, so on an
  ultrawide display its elements slide out to the physical edges. This confines
  the HUD to a centred box of a chosen aspect (16:9 by default), so it sits where
  it does on a 16:9 screen. Nothing is scaled — elements keep their size.
- **Cinematic bars removed.** Cinematics constrain the camera to 16:9 and fill the
  rest with black bars. This removes the constraint and widens the field of view
  horizontally, so the full ultrawide image is rendered — real scene at the sides,
  not a stretched or cropped 16:9.
- **Cutscene frame rate uncapped.** The game renders cutscenes at 30 fps and steps
  their animation at 30. This lifts the render cap to your own in-game Frame Rate
  Limit and steps cutscene animation at 60, so cinematics play smoothly. VSync is
  left untouched.

It works at **any resolution and aspect**: the inset is computed from the live
viewport, so 21:9, 32:9, 48:9 and windowed sizes all work, and at exactly 16:9 it
does nothing.

## Requirements

A working Dawnwalker-compatible UE4SS 3.x install (the same loader the other
Dawnwalker mods use). Stock UE4SS cannot detect this game's engine version — use
one of the prepared Dawnwalker UE4SS packages.

## Install

Extract into your game folder and merge `Dawnwalker`, or install with a mod
manager. You end up with:

```
Dawnwalker\Binaries\Win64\ue4ss\Mods\DawnwalkerUltrawide\
    enabled.txt
    Scripts\main.lua
    Scripts\Ultrawide.defaults.ini
```

No `mods.txt` entry is needed. On Xbox / Game Pass the project folder is
`Binaries\WinGDK`. To uninstall, delete the folder.

## Configuration

Copy `Ultrawide.defaults.ini` to `Ultrawide.ini` beside `main.lua` and edit the
copy — `Ultrawide.ini` is never overwritten by an update. Settings load at
startup; restart after editing.

| Setting | Default | Effect |
|---|---|---|
| `Enabled` | `true` | Master switch. Turn the whole mod off. |
| `HudAspect` | `16:9` | Aspect of the centred box the HUD is confined to. Accepts `16:9`, `21:9`, or a number like `1.777778`. |
| `HudWidthOffset` | `0` | Nudge the HUD further inward (+) or outward (−), in layout pixels. |
| `RecenterHUD` | `true` | Turn off to leave the HUD alone and only fix cinematics. |
| `RemoveCinematicBars` | `true` | Remove the 16:9 bars from cinematics. |
| `KeepVerticalFov` | `true` | Widen horizontally (reveal scene). `false` keeps horizontal FOV and crops top/bottom — rarely wanted. |
| `UncapCinematicFps` | `true` | Lift the game's 30 fps cinematic cap: rendering follows your in-game Frame Rate Limit (left at your current cap if it can't be read), animation steps at `CinematicAnimFps`. VSync untouched. |
| `CinematicAnimFps` | `60` | Frame rate cutscene animation is stepped at while `UncapCinematicFps` is on. Whole number. |
| `ToggleKey` | *(none)* | Optional UE4SS key name (e.g. `INS`) to toggle the mod in game. |
| `Verbose` | `false` | Also write `Ultrawide.log` beside `main.lua`. |
| `Trace` | `false` | Extra diagnostic lines (camera passes, HUD padding capture, hook firings) for bug reports. Combine with `Verbose` to capture them in the log. |

Set the HUD to your own display, e.g. `HudAspect = 21:9`, or `HudAspect = 32:9`
to leave the HUD spread wide and only use the cinematic fix.

## How it works

See `FINDINGS.md` in the project repository for the full investigation. In short: the HUD (`WBP_GameHUD_C`)
has no canvas anchors — its containers are box-aligned against the viewport — so
the fix adds equal left/right padding to each container's slot, which recentres
every alignment type without scaling. The bars are `bConstrainAspectRatio` on the
active cine camera; clearing it with `AspectRatioAxisConstraint = MaintainYFOV`
keeps the authored vertical FOV and widens horizontally. Separately, the game clamps
`t.MaxFPS` to 30 and frame-locks the cutscene sequence players at 30 when a cinematic
starts; the mod resets the cap to your own Frame Rate Limit and raises the sequence
player's frame rate to `CinematicAnimFps`, on the cinematic edges only — one bounded
lookup per start, no polling.

## Compatibility

- Runs alongside other Dawnwalker mods; it writes UMG slot padding, camera aspect
  properties, and — during cinematics — the `t.MaxFPS` cap and the cutscene sequence
  player's frame rate. If another mod or your `Engine.ini` manages `t.MaxFPS`, set
  `UncapCinematicFps = false`.
- Do **not** run it together with another ultrawide mod; they act on the same
  cameras and HUD and will fight.
- Reacts to cinematic transitions and camera spawns, so bars are cleared the
  instant a cut happens — the cinematic path is fully event-driven and is never
  re-checked on a timer. A slow backstop only re-centers the HUD after a
  resolution change. There is no per-frame work.

## Known limitations

- Menus and the full-screen map are not repositioned; they already use the whole
  screen and are left alone.
- A cinematic that was authored with no set-dressing beyond 16:9 will show the
  wider framing the artists did not compose for. This reveals what the engine
  renders; it does not invent content.
- Prerendered (Bink) full-motion cutscenes are genuine 16:9 video and are not
  touched — they cannot be widened without stretching.

## Credits

[UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (MIT) was used for data collection
and the development of this mod, and is not bundled.

The Blood of Dawnwalker is © Rebel Wolves; this mod is unofficial and ships no
game assets. Released under the MIT Licence — see `LICENSE.txt`.
