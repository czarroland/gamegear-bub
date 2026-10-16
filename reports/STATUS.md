# Game Gear port — rev4 hardware diagnostic checkpoint

## 2026-10-16 GG scaling checkpoint and SMS work

The public
[`v0.1.0-alpha.3`](https://github.com/czarroland/gamegear-bub/releases/tag/v0.1.0-alpha.3)
prerelease contains a GG-only rev4 core with sharp 2×/3× scaling and the
MiSTer Sega engine refreshed to `8443a0d19a88aff7a5900011bccf386daf146945`.
Its source commit is `a18cdfad0d5c269a63e85e11a2a4c68daeb27354`, ZIP
SHA-256 is `7bdd94551a50a85baec2be58d92d09f675754ca62931018aa1d8c39fa0a09f0a`,
and bitstream SHA-256 is
`8dcc320f2bbc2095c61a25cc5b07ca9fb391ab5c4e3b8fbc101fa38822db8bbf`.
The anonymously downloaded ZIP matched that hash. Its core files were
installed from the ZIP and read back at `/Volumes/BUB/cores/GameGear.Scale23`;
older core packages, settings and saves were backed up and preserved. The host
regression suite passed, and Vivado 2024.1 post-route margins were +0.042 ns
setup and +0.053 ns hold. The DRC still warns about the framework HDMI clock
buffer connection and asynchronous BRAM controls.

Rob reported on 2026-10-16 that this installed core runs "fantastically" on
his Bub. The exact ROMs, scale selections, test duration, audio and save
round-trip results have not been supplied; no broader hardware compatibility
claim is made. The dated report is also in the release notes.

The first independent native MiSTer decoder oracle passes in GHDL for GG/SMS
cartridge selection and bank addressing, including the `$3E` no-BIOS fix. A
real-engine SMS diagnostic passes in Verilator for Pause NMI under `DI`, held
press/repress, the console Reset I/O bit and a complete 256×192 native frame.
Unit tests cover Pause rearming across focus/freeze/mode changes, ROM-type
hint/header precedence, and completed-frame descriptors at GG 160×144 and
SMS 256×192/224/240. The integrated GG SoC test also passes load-hint
ordering, header fallback, epoch reset and active 160×144 readback. The SoC
still holds its active profile at GG/NTSC and the framework still has a
160×144 framebuffer; these simulations are groundwork, not an SMS-capable
hardware package.

---

The material below records the original 2026-10-13 GG checkpoint. The dated
update above supersedes its older roadmap and release-status statements.

Date: 2026-10-13 UTC. Target: Gamebub rev4. Goal: native Game Gear.

**Implemented and simulated:** real T80 CPU, VDP and JT89 PSG; portable common-
clock memories; the complete host command mailbox and byte-committed ROM
loader; CRC/length checks; one-chip SDRAM initialization and refresh; a 160×144
frame adapter; signed stereo audio; active-low Game Gear Start and buttons;
focus behavior; and 32 KiB save import/export with a coherent frozen engine.

This source checkpoint is in the Gamebub workspace. The Gamebub framework and
pulled firmware remain unchanged. The enabling firmware source is `v1.1-beta`, Cargo `1.1.0-beta2`, at
`9966de77f037ae5d7610bd9d2b6f0b512ff7eb5c`.

## Verification completed

| Check | Result |
| --- | --- |
| Real VHDL engine analysis and synthesis to simulation Verilog | Pass |
| Portable memory initialization and one/two-cycle read behavior | Pass; rerun in Vivado XSim after the single-write RAM change |
| Signed stereo averaging, fractional sample cadence, mute, zero DC, clipping | Pass; rerun in Vivado XSim after timing pipeline changes |
| SDRAM init, both byte lanes, row boundary, all banks, read latency, idle refresh | Pass; rerun in Vivado XSim after the input capture change |
| Real engine with Sega banking, cartridge RAM, GG Start/buttons, VDP and stereo PSG | Pass in Verilator and four-state Icarus |
| Host protocol + actual engine + pin-level SDRAM model | Pass |
| Ordered ROM commits, CRC, error response, rejected wrong length, clean reload | Pass |
| Three complete frames, 160 pixels × 144 rows, one-cycle enables, 896,040-clock cadence | Pass |
| Full 32 KiB save export, CPU freeze, continuous refresh, save retained across Halt | Pass |
| Original/staged Sega source SHA-256 manifest | Pass |
| Actual Chisel/SDK rev4 generation | Pass |
| All 53 generated external-module ports and display divider | Exact match, divider 38 |
| Vivado 2024.1 rev4 synthesis, place, route, bitstream | Pass; Artix-7 `xc7a100tcsg324-1` |
| Final routed timing | Setup WNS +0.002 ns, hold WHS +0.052 ns; no failing endpoints |
| SD card package | Corrected metadata installed and byte-for-byte verified on BUB; card safely ejected |

Machine-readable results are in `test-results.json`. Tool output is retained
beside this report. The testbench uses the pulled firmware's actual command
format; the Rust MCU firmware itself has not been compiled or executed here.

![Captured real-engine diagnostic frame](diagnostic-frame.png)

The frame contains 11,520 red and 11,520 green pixels. The diagnostic program
writes the real VDP palette and tile memory; no test pattern substitutes for
the video engine. Its current ROM also turns the green bands blue while Start
is held and the red bands blue while A or B is held.

## Hardware diagnostic status

Vivado 2024.1 produced
`build/vivado-checkpoint/GameGearCore-gamebub_rev4.bit` (SHA-256
`3ade2e50d60190ba6828f6ab6d0da1768f304df2f2502de803a8f7bf68478288`).
The FPGA reports are under `build/vivado-checkpoint`; the bitstream is packaged
on `/Volumes/BUB/cores/GameGear.Alpha`, and the original diagnostic is at
`/Volumes/BUB/roms/GameGear/gamegear-diagnostic.gg`. Both copies were verified.
The user's existing custom firmware was left in place.

The +0.002 ns setup margin is thin. Vivado reports no timing failures, but this
is a development build for the first physical test. The routed DRC has no errors;
it retains one framework HDMI clock-routing critical warning and 26 RAM/control
warnings. SDRAM input/output paths are constrained by provisional budgets. The
framework still has unconstrained HDMI audio-clock and other external I/O paths.
The SDRAM protocol model does not establish physical-chip behavior or PCB delay.

The first physical launch returned to the home screen when either the
diagnostic or a retail ROM was selected. The BUB crash log identified a
firmware panic before ROM transfer: `No suitable spi for max clock
Some(1000000Hz)`. The package had set `max_transfer_speed` to 500 KB/s,
which the firmware converts to a 1 MHz SPI cap; its slowest configured SPI
driver is 10 MHz. Both ROM and save metadata now use 5000 KB/s, which selects
that driver. The corrected `files.json` was verified on BUB and the card was
safely ejected. The user subsequently confirmed that both the diagnostic ROM
and Sonic Triple Trouble load and run on the rev4 hardware. The bitstream was
not rebuilt for this fix.

Battery-backed save import/export is implemented in the current core. On
hardware, normal exit produced `gamegear-diagnostic.sav` with the expected
32,768-byte size, first byte `5A`, and an `FF` tail. To test import, the file
was backed up and marker bytes `22 33 44` were placed at offsets 1–3 and `99`
at its final offset. The modified file was verified on BUB and the card safely
ejected; relaunch/exit and post-run inspection are pending. Save states and
Master System mode have not been implemented. A separate sharp 3×/2× scaling
trial passed the integrated simulator suite and rev4 Vivado 2024.1 timing:
setup WNS +0.005 ns, hold WHS +0.021 ns, no failing constrained endpoints.
Its bitstream is `build/vivado-scaling/GameGearCore-gamebub_rev4.bit` (SHA-256
`43f5385af381ae2290b9a1587c892b83fbd138310a18977e0f55dfab59a297ba`).
The package was installed as `/Volumes/BUB/cores/GameGear.ScalingTrial`,
verified byte for byte, and the card safely ejected. The original
`GameGear.Alpha` bitstream still has its known-good SHA-256. The user confirmed
that the 2×/3× scaling trial works on hardware. The new 4× centered crop option
passed the integrated simulator suite and Vivado 2024.1 post-route timing:
setup WNS +0.075 ns, hold WHS +0.024 ns, no failing constrained endpoints.
Its bitstream SHA-256 is
`3735089578fbc3645522fa0f12079421cdc9830e7a6bb8a969d2c1f6a128ee2e`.
The `GameGear.ZoomTrial` package was installed on BUB, all five files were
verified byte for byte, and the card safely ejected. The older core bitstreams
still match their recorded SHA-256 values. The user confirmed that 4× works
on hardware. A 3.5× bilinear mode is now
packaged separately for a smaller vertical crop. The integrated simulation
suite and Chisel generation passed. Vivado 2024.1 post-route timing closed at
setup WNS +0.008 ns and hold WHS +0.054 ns, with zero failing constrained
endpoints. The bitstream SHA-256 is
`2952f533f7f3d1a7ccbf7ffe04ebc804157bccedbb0a1440f36d9fdc4bdee567`.
The `GameGear.SmoothTrial` package was installed on BUB, all five files were
verified byte for byte, and the card safely ejected. The older Alpha and Zoom
bitstream hashes remain unchanged. The user confirmed that 3.5× works on
hardware. Alternative fractional filters remain on the roadmap.

A community tester reported short successful runs with NA/JP/EU ROMs, demos,
test suites, and patched/translated GG titles, and reported working saves.
The same tester found that adding `.sms` to the GG-only file metadata permits
some SMS-format titles to start but leaves missing Pause input, wrong palette,
and 160×144 cropping. These reports inform the SMS tests; most play sessions
were approximately five minutes or less.

Retail games, non-Sega mappers, EEPROM saves, 224-line mode, and SMS
compatibility remain unverified or unimplemented. See `docs/BUILD_AND_TEST.md`
for the board test sequence.
