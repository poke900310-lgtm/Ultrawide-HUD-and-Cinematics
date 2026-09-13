# Ultrawide HUD and Cinematics

Fills your ultrawide screen without fighting the art: removes cinematic black bars by widening the view to reveal real scene, never stretched or zoomed, and recenters the HUD.

## Description

On an ultrawide display, The Blood of Dawnwalker gives you two problems, and the common fixes make them worse. This mod solves both while keeping the picture exactly as the artists composed it.

The game is framed for 16:9. Cinematics constrain the camera to that frame and fill the rest of your panel with black bars, so the widest, most cinematic moments show a small window with wasted space on either side. The HUD is laid out against the full width of the screen, so at 21:9 or 32:9 its elements slide out to the far physical edges, away from where they sit on a normal display and awkward to read across a wide panel.

The usual way to force ultrawide is to stretch or zoom the image until it fills the screen. That fights the art: stretching distorts faces and proportions, and zoom throws away the top and bottom of a shot the cinematographer framed on purpose. Either way you are no longer seeing what was composed.

This mod does the opposite. It removes the black bars by widening the field of view, which reveals the real scene the engine is already rendering at the sides - the same world, at the same scale, with the same composition at the center, now visible edge to edge instead of hidden behind letterboxing. Nothing is invented and nothing is warped; you are simply seeing past the 16:9 window into the shot as it was built.

For the interface, it confines the HUD to a centered box of an aspect you choose, 16:9 by default, so the UI returns to a comfortable, centralized layout at its original size. Nothing is scaled.

**What it leaves alone**

Menus and the full-screen map already use the whole screen, so they are untouched. Prerendered (Bink) cutscenes are genuine 16:9 video and cannot be widened without stretching, so the mod does not touch them either. A shot that was set-dressed only for 16:9 will show the wider framing the artists did not compose for; this reveals what the engine renders, it does not add anything.

Confirmed at 32:9. The inset is computed from the live viewport, so 21:9, 48:9 and windowed sizes work the same way, and at exactly 16:9 the mod does nothing.

## Installation instructions

**Mod manager** - install the archive; it carries the full path from the game folder, so it deploys into place on its own.

**Manual** - extract the archive into your game folder and merge `Dawnwalker`:

```
...\The Blood of Dawnwalker\
```

On Xbox / Game Pass the project folder is `Binaries\WinGDK`, not `Binaries\Win64`, so move the `DawnwalkerUltrawide` folder there afterwards.

You end up with:

```
Dawnwalker\Binaries\Win64\ue4ss\Mods\DawnwalkerUltrawide\
    enabled.txt
    Scripts\main.lua
    Scripts\Ultrawide.defaults.ini
```

No `mods.txt` entry is needed - the mod loads from its own `enabled.txt`.

**Configuration** - settings live in `Ultrawide.ini` beside `main.lua`. It is not shipped: create it, and it will survive mod updates, unlike `Ultrawide.defaults.ini`, which is the reference copy and gets overwritten.

```
Enabled = true
HudAspect = 16:9
HudWidthOffset = 0
RecenterHUD = true
RemoveCinematicBars = true
KeepVerticalFov = true
ToggleKey =
Verbose = false
```

`HudAspect` is the aspect of the centered box the HUD is confined to; set it to your display, or to a value wider than your screen to leave the HUD spread out and only use the cinematic fix. `HudWidthOffset` nudges the HUD further in or out. Settings load at startup, so restart the game after editing.

**Uninstallation** - delete the `DawnwalkerUltrawide` folder. Nothing else is touched.

## Main features

- Removes the 16:9 black bars from cinematics by widening the field of view, so the full ultrawide frame shows real rendered scene at the sides, never a stretch or a zoom
- Recenters the HUD into a centered box of a chosen aspect, without scaling anything
- **HudAspect** sets the box and **HudWidthOffset** nudges it inward or outward
- Works at any resolution and aspect - 21:9, 32:9, 48:9, windowed - and does nothing at 16:9
- Optional **ToggleKey** turns the whole mod on and off in game
- No per-frame work: it reacts to cinematic cuts and HUD rebuilds as they happen

## Requirements

UE4SS. Any working Dawnwalker-compatible install will do. Stock UE4SS cannot detect this game's engine version, so use one of the prepared Dawnwalker UE4SS packages.

**Compatibility** - it only writes UMG slot padding and camera aspect properties, ships no assets, needs no `mods.txt` entry, and does not touch `dwmapi.dll` or `UE4SS-settings.ini`, so it will not fight your UE4SS install or any other package over those files. Do not run it together with another ultrawide mod, since they act on the same cameras and HUD.

## Shout outs

UE4SS-RE and its contributors - UE4SS was used for data collection and the development of this mod, and none of it exists without the loader.

Vercadi, for maintaining the Dawnwalker UE4SS package.

Rebel Wolves, for a game worth seeing edge to edge.
