# Ultrawide HUD and Cinematics

Ultrawide support for The Blood of Dawnwalker that respects how the game was
made. It opens up the letterboxed cinematics so the full ultrawide image is
shown, and it brings the HUD in from the physical screen edges to a centered
layout. Nothing is stretched, cropped, or zoomed.

## Why this is needed

The Blood of Dawnwalker is composed for a 16:9 frame. On an ultrawide display,
two things work against that intent.

Cinematics constrain the camera to 16:9 and fill the rest of the panel with
black bars. Your ultrawide screen ends up showing a small window with wasted
space on either side, during exactly the moments the game most wants you to be
inside the world.

The HUD is laid out against the full width of the screen, so at 21:9 or 32:9 its
elements slide out to the far physical edges, far from where they sit on a normal
display and awkward to read across a wide panel.

The usual way to "fix" ultrawide is to stretch or zoom the picture until it fills
the screen. That fights the art. Stretching distorts faces and proportions; zoom
and crop throw away the top and bottom of a shot the cinematographer framed on
purpose. Either way you are no longer seeing what the artists composed.

This mod takes the opposite approach. It preserves the artistic vision and simply
lets you see more of it. The black bars are removed by widening the field of
view, which reveals the real scene the engine is already rendering at the sides:
the same world, at the same scale, with the same authored composition at the
center, now visible edge to edge instead of hidden behind letterboxing. Nothing
is invented and nothing is warped. You are seeing past the 16:9 window into the
shot as it was built.

For the interface, rather than let the HUD scatter to the corners of a wide
panel, the mod confines every element to a centered box of an aspect you choose,
16:9 by default. The UI returns to a comfortable, centralized layout where it
belongs, at its original size. Nothing is scaled.

## What it does

- **Removes cinematic black bars, natively.** Widens the field of view so the
  full ultrawide frame shows real rendered scene at the sides, never a stretched
  or cropped 16:9. An optional mode crops top and bottom instead, if you prefer.
- **Recenters the HUD.** Confines the HUD to a centered aspect box so it sits
  where it does on a 16:9 screen, without scaling anything. The target aspect and
  an inward/outward nudge are configurable.
- **Works at any resolution and aspect.** 21:9, 32:9, 48:9, and windowed sizes
  are all handled from the live viewport, and at 16:9 the mod does nothing.

It is light: no per-frame work, it reacts to cinematic cuts and HUD changes as
they happen, and it reads and writes the game by name so it survives game
updates well.

## Requirements

A Dawnwalker-compatible UE4SS 3.x install (the same loader the other Dawnwalker
mods use). Stock UE4SS cannot detect this game's engine version, so use one of
the prepared Dawnwalker UE4SS packages.

## Install

Extract into your game folder and merge the `Dawnwalker` directory, or install
with a mod manager. No `mods.txt` entry is needed. To uninstall, delete the mod
folder. To change a setting, copy `Ultrawide.defaults.ini` to `Ultrawide.ini`
beside it and edit the copy; your `Ultrawide.ini` is never overwritten by an
update. Settings load at startup, so restart after editing.

## Compatibility and limitations

- Runs alongside other Dawnwalker mods. Do not run it together with another
  ultrawide mod, since they act on the same cameras and HUD.
- Menus and the full-screen map already use the whole screen and are left alone.
- A shot that was set-dressed only for 16:9 will show the wider framing the
  artists did not compose for. This reveals what the engine renders; it does not
  invent content.
- Prerendered (Bink) full-motion cutscenes are genuine 16:9 video and are not
  touched. They cannot be widened without stretching.

## Credits

Original work. No code from any other mod was used. Runs on UE4SS, which is not
bundled. The Blood of Dawnwalker is © Rebel Wolves; this mod is unofficial and
ships no game assets. Released under the MIT Licence.
