# GG and SMS Bub

**Original Game Gear core credit:** [GreyRogue](https://github.com/greyrogue)
added Game Gear support to the
[MiSTer Sega Master System core](https://github.com/MiSTer-devel/SMS_MiSTer)
in [pull request #8](https://github.com/MiSTer-devel/SMS_MiSTer/pull/8),
then contributed Game Gear button and stereo audio fixes. This project ports
and adapts that MiSTer engine for Gamebub; it did not originate the Game Gear
emulation core. The MiSTer core builds on Ben's earlier Papilio Master System
implementation and the work of other MiSTer-devel contributors. See
[source notices](NOTICE.md) for the provenance links and component credits.

**AI-developed Gamebub port:** OpenAI Codex writes the Gamebub adaptation,
tests, and release packages with human direction and testing on Gamebub hardware.

Development port of the MiSTer Sega Master System/Game Gear engine to Gamebub
rev4. The [GG and SMS Bub alpha.7 prerelease](https://github.com/czarroland/gamegear-bub/releases/tag/v0.1.0-alpha.7)
uses one GG/SMS core entry with selectable SMS NTSC or PAL. It includes
on-screen button mapping, plus the crop, Pause and Select fixes requested in
issues #3–#6. The combined build passed simulation and needs device play
checks. FM synthesis is still absent.

With the current v1.1-beta firmware, **System: Auto** can identify a ROM only
from a consistent `TMR SEGA` header. If an `.sms` game does not start under
Auto, select **System: Master System** and reload it; for an unrecognized
`.gg` game, select **Game Gear**. The filename extension alone does not reach
this firmware's core loader. The optional extension-hint firmware patch is
source only and has not been installed or verified on a Bub. The one ROM
picker remembers its last directory, so switching between separate GG and SMS
folders currently requires navigation.

## Why Game Gear and Master System share one core

The [MiSTer core this port comes from](https://github.com/MiSTer-devel/SMS_MiSTer)
already runs both systems in one engine. They share much of the CPU, video,
cartridge, and PSG sound path; the Gamebub port changes the machine profile at
runtime for the screen, palette, controls, and audio. One bitstream lets those
parts be reused instead of packaging two emulator engines. Some games sold for
Game Gear actually run in [Master System compatibility mode](https://www.smspower.org/Tags/SMS-GG),
so both modes are needed for accurate Game Gear coverage. Upstream notes that
those titles may need an `.sms` extension; with the current Gamebub firmware,
select **System: Master System** manually instead. The current build has one
ROM picker and one remembered folder, as described above.

The GG-only alpha.3 release runs native Game Gear games: the diagnostic
ROM and Sonic Triple Trouble have both run on hardware. It includes the Sega
CPU, VDP and JT89 sound engine, a Gamebub host loader, SDRAM controller,
160×144 video, stereo audio, input mapping, and 32 KiB cartridge RAM. Battery
save export has been verified on hardware; import verification is in progress.
The source repository does not include a bitstream, firmware UF2, retail ROM,
or BIOS.

The separate GG-only rollback package is the
[v0.1.0-alpha.3 prerelease](https://github.com/czarroland/gamegear-bub/releases/tag/v0.1.0-alpha.3).
Download its ZIP, then copy its `cores` and `roms` folders to the BUB SD card.
It uses the separate `GameGear.Scale23` core ID and requires the existing
custom core-loading firmware.

The unified core offers sharp integer 3× and 2× for GG, plus
2×, 3× crop and 4× crop for SMS. Stored 4× and 3.5× GG preferences normalize
to 3×. It selects GG, SMS NTSC or SMS PAL at runtime in one SoC, with a shared
256×240 framebuffer pair and native
active viewport. Its
[alpha.4 GG/SMS trial](https://github.com/czarroland/gamegear-bub/releases/tag/v0.1.0-alpha.4)
was released and installed, but hardware tests found that games do not
progress beyond their first screen. The
[alpha.5 GG/SMS display handoff trial](https://github.com/czarroland/gamegear-bub/releases/tag/v0.1.0-alpha.5)
received an initial successful rev4 play check, with exact ROMs and settings
not yet recorded. Alpha.6 packages that same bitstream under the clearer menu
name. Alpha.3 remains the GG-only rollback.
Several PAL games and the original raster diagnostics played on a separate
local PAL trial; the alpha.7 combined build has not yet passed its own device test.
FM remains later work. Earlier
4× and 3.5× trials remain documented as historical results.

The development controls menu includes **Map controls**, which opens a
six-step on-screen prompt for Up, Down, Left, Right, A and B. Each step
captures one physical D-pad or A/B/X/Y press; Select keeps the existing
binding and advances, and Start exits. These custom bindings last for the
current core session. **Swap A/B** is a separate saved menu choice. SMS 4×
crop uses L and R to move the picture one source pixel per press. SMS Start
acts as Pause after debounce. SMS Select does nothing by default, with an
optional one-second hold to reset the console. See the [runtime ABI](docs/SEGA_RUNTIME_ABI.md)
for register details.

The target is one rev4 core package for Game Gear and Master System, with FM
sound and runtime machine selection, following the pinned
[SMS_MiSTer](https://github.com/MiSTer-devel/SMS_MiSTer) engine where the Bub
hardware and firmware permit it. See the
[feature roadmap](docs/NEXT_FEATURES.md), [SEG2 runtime ABI](docs/SEGA_RUNTIME_ABI.md),
[build and hardware test instructions](docs/BUILD_AND_TEST.md),
[recorded results](reports/STATUS.md), and [source notices](NOTICE.md).

```bash
python3 scripts/run_tests.py --four-state
python3 scripts/build_core.py --target gamebub_rev4
```

The enabling firmware source was examined at `v1.1-beta`
(`9966de77f037ae5d7610bd9d2b6f0b512ff7eb5c`). This repository includes
the selected upstream Sega source files. The Gamebub framework and generated
FPGA snapshot are kept outside this repository; obtain the framework under
its own terms at the revision in `manifests/repositories.json` before building.
