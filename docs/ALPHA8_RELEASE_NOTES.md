# GG and SMS Bub v0.1.0-alpha.8

This Gamebub rev4 prerelease updates the combined Game Gear and Master System
core. It is a test build: the new image passed simulation and FPGA routing, but
its installation on the BUB SD card has not yet been followed by a device play
check.

## Changes

- **SMS 3× crop:** L moves the picture up one source line per press; R moves it
  down. This corrects [issue #3](https://github.com/czarroland/gamegear-bub/issues/3),
  where alpha.7 moved only the 4× crop. The offset resets when the size setting
  changes.
- **SMS 4× removed:** The size menu now offers only sharp 2× and 3× crop.
  A saved 4× value loads as 2×.
- **Master System TV defaults to Auto:** The exact 256 KiB Alien 3 (Europe,
  Brazil) ROM with CRC-32 `B618B144` selects PAL. Unknown images use NTSC;
  PAL and NTSC can still be selected manually. This is an exact-ROM match,
  not general region detection.
- The alpha.7 controls remain: on-screen button mapping, saved A/B swap,
  debounced Start/Pause, and no Select reset unless the one-second hold option
  is enabled ([issues #4–#6](https://github.com/czarroland/gamegear-bub/issues)).

Thanks to [@dfilskov](https://github.com/dfilskov) for filing issues
[#3](https://github.com/czarroland/gamegear-bub/issues/3),
[#4](https://github.com/czarroland/gamegear-bub/issues/4),
[#5](https://github.com/czarroland/gamegear-bub/issues/5), and
[#6](https://github.com/czarroland/gamegear-bub/issues/6), and for the
follow-up feedback that exposed the 3× crop problem.

## Testing and installation

The 51-check simulation suite passes, including the crop movement, PAL
selection, and original GG/SMS diagnostic ROMs. The rev4 bitstream routed in
Vivado 2024.1 with +0.340 ns setup WNS, +0.023 ns hold WHS, and no DRC errors.
The ZIP contains the core, diagnostic ROMs, simulation logs, and hashes.
Extract it at the root of the BUB SD card. The menu entry is **GG and SMS Bub**;
the core ID remains `Sega8bit.Dev`. Keep the separate alpha.3 GG package for
rollback.

**Known issue:** Alien 3 (Europe, Brazil) still shows a black screen and no
audio on the reported Gamebub setup, even with PAL forced. The same ROM
produces video in simulation. Auto TV is not claimed to fix that boot failure.
The combined alpha.8 image also needs on-device checks with GG, SMS NTSC, and
SMS PAL titles. Please report ROM hash, firmware version, System/TV/size
settings, and exact behavior in the
[issue tracker](https://github.com/czarroland/gamegear-bub/issues).

FM synthesis, save states, and complete mapper/EEPROM compatibility remain
unverified. Original Game Gear core credit belongs to
[GreyRogue](https://github.com/MiSTer-devel/SMS_MiSTer/pull/8); see
[NOTICE.md](https://github.com/czarroland/gamegear-bub/blob/main/NOTICE.md)
for the remaining upstream credits.
