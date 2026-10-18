# GG and SMS Bub v0.1.0-alpha.7

This prerelease is a Gamebub rev4 test build of the shared Game Gear and
Master System core. SMS NTSC and PAL are selectable in one core. The separate
PAL trial ran several PAL games on a Gamebub; this combined build needs a new
device play check. FM synthesis is not included.

## Changes

- **SMS PAL:** Select **Master System TV → PAL** for PAL software. The same
  core can return to NTSC without installing another bitstream.
- **Issue #3:** SMS **4× crop** now moves the picture one source pixel up with
  L and down with R. Movement is bounded by the current active screen height.
- **Issue #4:** **Map controls** opens a six-step press-to-bind screen for
  Up, Down, Left, Right, A and B. Each step accepts D-pad or A/B/X/Y. Select
  keeps that binding; Start exits. A separate **Swap A/B** menu choice is
  saved by firmware. Custom on-screen bindings last for the current session.
- **Issue #5:** SMS Select has no reset action by default. An optional
  **Hold 1s Reset** setting enables a guarded console Reset.
- **Issue #6:** SMS Start/Pause now requires a stable press and release, so
  contact bounce cannot trigger repeated Pause edges.
- The host upload path accepts ROM images up to 16 MiB. The TecToy Evolution
  profile and specific ROM hacks still need individual gameplay tests.

## Testing and installation

The ZIP contains the rev4 core, original GG and SMS diagnostic ROMs, a
51-check simulation summary and selected per-ROM logs in `test-logs/`. The logs are
simulation evidence, not retail-game test results. Extract the ZIP to the
root of the BUB SD card. The menu name is **GG and SMS Bub** and the core ID
remains `Sega8bit.Dev` so existing settings and saves keep their paths.
Keep the separate alpha.3 GG core as a rollback.

Try a GG title, an SMS NTSC title, and an SMS PAL title. In SMS mode, try
Start/Pause, Select, 4× crop L/R, the mapper, and Swap A/B. Report the ROM
name and SHA-256, firmware version, System/TV/size settings, and exact result
in the [issue tracker](https://github.com/czarroland/gamegear-bub/issues).

The original Game Gear support in the MiSTer Sega core was authored by
[GreyRogue](https://github.com/MiSTer-devel/SMS_MiSTer/pull/8). This Gamebub
port was developed by OpenAI Codex with human direction and hardware testing.
See [NOTICE.md](https://github.com/czarroland/gamegear-bub/blob/main/NOTICE.md)
for full upstream credit and license details.

FM sound, save states, and complete mapper/EEPROM coverage are not included or
claimed in this alpha. SMS PAL and the control changes still need broad
on-device compatibility reports before beta.
