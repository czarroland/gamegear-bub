# GG and SMS Bub v0.1.0-alpha.9 (rev4)

This alpha is a Game Gear and Master System core build for Gamebub rev4.
It uses the same `Sega8bit.Dev` core ID as alpha.8. Keep the separate
`GameGear.Scale23` rollback package and back up saves before replacing the
core. The ZIP contains no commercial ROMs or firmware image.

## Changes

- **SMS top row:** The rev4 display path now retains native row zero at 2×
  and 3× and ignores an empty line after VBlank when counting captured rows.
  This addresses the source path behind [core issue #7](https://github.com/czarroland/gamegear-bub/issues/7).
  The first row still needs an on-device check.
- **Control mapping:** Map controls now prompts for directions, A/B,
  Start/Pause, crop up/down, and optional SMS Reset. Each can use any D-pad,
  A/B/X/Y, L/R, Start, or Select button. Tap to bind, hold one button for one
  second to keep its binding, or hold Start+Select for one second to exit.
  Bindings last for the current core session; Restore controls resets them.
  The default crop buttons remain L/R.
- **Known menu behavior:** After selecting Map controls, manually exit the
  core settings menu to see the mapping prompt. This is tracked in
  [issue #9](https://github.com/czarroland/gamegear-bub/issues/9).
  The core package does not change Gamebub firmware.

## Known limits and test focus

The mounted Alien 3 (Europe, Brazil) ROM now flashes white, then remains black
with no sound on the alpha.9 Next Trial device build
([issue #10](https://github.com/czarroland/gamegear-bub/issues/10)).
The same exact image produces video
in direct-engine and full SoC/SDRAM simulation, including a new test with
System: Auto and Auto PAL. Its Sega header selects SMS in Auto mode. Florin's
alternate source is pending for a rev4 comparison.
Auto TV recognizes this one known PAL image; unknown images use NTSC and can
be set manually. Alien 3 compatibility is **not** claimed in this release.

Check SMS 2× and 3× on the LCD, including the first native row; move the 3×
crop with the default L/R buttons, then remap both crop commands and repeat.
Check Start/Pause, the mapping exit gesture, and GG controls. Report the ROM
hash, firmware version, and System/TV/size settings.
This build has no FM synthesis or verified save states.

Thanks to [@dfilskov](https://github.com/dfilskov) for the clear top-row and
menu-arrow reports. The menu-arrow behavior remains tracked upstream in
[Gamebub issue #58](https://github.com/elipsitz/gamebub/issues/58).
