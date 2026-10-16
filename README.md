# Game Gear on Gamebub

Development port of the MiSTer Sega Master System/Game Gear engine to Gamebub
rev4. The published alpha releases run native Game Gear games: the diagnostic
ROM and Sonic Triple Trouble have both run on hardware. They include the Sega
CPU, VDP and JT89 sound engine, a Gamebub host loader, SDRAM controller,
160×144 video, stereo audio, input mapping, and 32 KiB cartridge RAM. Battery
save export has been verified on hardware; import verification is in progress.
The source repository does not include a bitstream, firmware UF2, retail ROM,
or BIOS.

The last published Game Gear development package is the
[v0.1.0-alpha.2 pre-release](https://github.com/czarroland/gamegear-bub/releases/tag/v0.1.0-alpha.2).
Download its ZIP, then copy its `cores` and `roms` folders to the BUB SD card.
It uses the `GameGear.Dev` core ID and requires the custom core-loading firmware.

The implementation branch now exposes only sharp integer 3× and 2× sizes.
Stored 4× and 3.5× preferences normalize to 3×. This source change has not yet
been qualified on hardware or published as a new package. Earlier alpha
releases still contain the 4× and 3.5× experiments; their reports remain as
historical test results.

The target is one rev4 core package for Game Gear and Master System, with FM
sound and runtime machine selection, following the pinned
[SMS_MiSTer](https://github.com/MiSTer-devel/SMS_MiSTer) engine where the Bub
hardware and firmware permit it. See the
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
