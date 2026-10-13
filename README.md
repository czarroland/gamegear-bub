# Game Gear on Gamebub

Development port of the MiSTer Sega Master System/Game Gear engine to Gamebub
rev4. The current core runs native Game Gear games: the diagnostic ROM and Sonic
Triple Trouble have both run on hardware. It includes the Sega CPU, VDP and
JT89 sound engine, a Gamebub host loader, SDRAM controller, 160×144 video,
stereo audio, input mapping, and 32 KiB cartridge RAM. Battery save export has
been verified on hardware; import verification is in progress. The source
repository does not include a bitstream, firmware UF2, retail ROM, or BIOS.

The current rev4 development package is the
[v0.1.0-alpha.1 pre-release](https://github.com/czarroland/gamegear-bub/releases/tag/v0.1.0-alpha.1).
Download its ZIP, then copy its `cores` and `roms` folders to the BUB SD card.
It uses the `GameGear.Dev` core ID and requires the custom core-loading firmware.

A separate rev4 trial confirmed sharp integer 3× and 2× screen sizes on
hardware. The current source also adds a centered 4× zoom option that crops
12 Game Gear lines from the top and bottom; its hardware test is pending.
The known-good Game Gear package remains available.

The target is [SMS_MiSTer](https://github.com/MiSTer-devel/SMS_MiSTer) feature
parity where the Bub hardware and firmware permit it. See the
[feature roadmap](docs/NEXT_FEATURES.md), [build and hardware test instructions](docs/BUILD_AND_TEST.md),
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
