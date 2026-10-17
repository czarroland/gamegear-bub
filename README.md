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
rev4. The current [GG and SMS Bub alpha.6 prerelease](https://github.com/czarroland/gamegear-bub/releases/tag/v0.1.0-alpha.6)
uses one GG/SMS NTSC core entry. This update changes the menu name while
retaining the alpha.5 bitstream and its internal core ID, so existing settings
continue to apply. FM audio and PAL timing remain unimplemented.

With the current v1.1-beta firmware, **System: Auto** can identify a ROM only
from a consistent `TMR SEGA` header. If an `.sms` game does not start under
Auto, select **System: Master System** and reload it; for an unrecognized
`.gg` game, select **Game Gear**. The filename extension alone does not reach
this firmware's core loader. The optional extension-hint firmware patch is
source only and has not been installed or verified on a Bub. The one ROM
picker remembers its last directory, so switching between separate GG and SMS
folders currently requires navigation.

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

The unified development branch exposes only sharp integer 3× and 2× sizes.
Stored 4× and 3.5× GG preferences normalize to 3×. It now selects GG or SMS
NTSC at runtime in one SoC, with a shared 256×240 framebuffer pair and native
active viewport. Its
[alpha.4 GG/SMS trial](https://github.com/czarroland/gamegear-bub/releases/tag/v0.1.0-alpha.4)
was released and installed, but hardware tests found that games do not
progress beyond their first screen. The
[alpha.5 GG/SMS display handoff trial](https://github.com/czarroland/gamegear-bub/releases/tag/v0.1.0-alpha.5)
received an initial successful rev4 play check, with exact ROMs and settings
not yet recorded. Alpha.6 packages that same bitstream under the clearer menu
name and is installed on the BUB card. Alpha.3 remains the GG-only rollback.
PAL and FM remain later work. Earlier
4× and 3.5× trials remain documented as historical results.

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
