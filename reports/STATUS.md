# GG and SMS Bub — rev4 hardware diagnostic checkpoint

## 2026-10-18 alpha.9 candidate: top row, mapping, firmware menu

[Core issue #7](https://github.com/czarroland/gamegear-bub/issues/7)
reports a missing first SMS pixel row at both sizes. The rev4 framework
display path had a three-pixel read lead along rotated Y; dividing that lead
by 2× or 3× skipped native row zero. The candidate keeps only the subpixel
phase of the lead and prevents an empty HBlank after VBlank from consuming
framebuffer row zero. The new framework RTL generated. The full 51-check
regression suite passed, and Vivado 2024.1 routed the rev4 image with
+0.310 ns setup WNS, +0.047 ns hold WHS, zero failing constrained endpoints,
and zero DRC errors (27 findings: one critical warning and 26 warnings).
The bitstream SHA-256 is
`d62f8c53a620f8c232eca25e1b900eb039bff50cc166489153733ea7835262d9`.
The top-row fix still needs an on-device check.

The core mapper now prompts for ten commands and accepts all 12 game-facing
buttons for every command. A tap binds, a one-second single-button hold keeps
the current binding, and holding Start+Select exits. The default SMS 3× crop
movement remains on L/R, but either direction can be remapped. The current
Gamebub firmware leaves core settings open after Map controls is selected;
manually exit the menu to see the mapper
([known issue #9](https://github.com/czarroland/gamegear-bub/issues/9)).
The endpoint arrows remain an upstream firmware matter
([Gamebub issue #58](https://github.com/elipsitz/gamebub/issues/58)).
This repository does not maintain firmware patches.

Alien 3 remains unresolved. The exact mounted ROM has a valid SMS Export Sega
header, so the saved System: Auto setting selects SMS; its region header
does not select TV timing. A new full SoC/SDRAM simulation loaded the exact
ROM with System: Auto, confirmed SMS header selection and Auto PAL, and
produced 196,608 nonblack pixels. On the alpha.9 Next Trial device build,
the game flashes white, then goes black with no sound
([issue #10](https://github.com/czarroland/gamegear-bub/issues/10)).
This is a device failure that the simulation has not reproduced. Florin's
vertical Game Gear port source has not
yet been supplied for a rev4 build or comparison. Keep compatibility open
without delaying the other alpha.9 work.

The routed five-file core package was installed on the mounted BUB card at
`cores/Sega8bit.NextTrial` as **GG and SMS Bub Next Test**. All five files were
read back with matching SHA-256 values; the existing `Sega8bit.Dev` alpha.8
core was not replaced. The previous Next Trial package is backed up at
`build/card-backup-before-alpha9-nexttrial`. The five card files were checked
again after removing the unused firmware hint from `files.json`; the bitstream
is unchanged. The public-core-ID release candidate ZIP is
`build/alpha9-candidate/GG-and-SMS-Bub-v0.1.0-alpha.9-rev4.zip`, SHA-256
`036b547c1ffa41b38fe9af31b9b7acb97abce8d490815f4e53a2a4f91df18009`.
No alpha.9 GitHub prerelease or firmware UF2 has been published or installed.
The Next Trial install is an SD-card file check, not an on-device play check.

## 2026-10-17 alpha.8 follow-up: crop, TV setting, Alien 3

The alpha.7 prerelease enables L/R movement only for SMS 4× crop. The source
now moves the SMS 3× crop by one source line per L/R tap, using a 256×160
source viewport. SMS 4× has been removed from the menu; its old stored value
normalizes to 2×. Position resets on a size-setting write. Auto TV defaults
to NTSC for unknown ROMs and recognizes one exact known PAL image, Alien 3
(Europe, Brazil), by full-ROM CRC-32 `B618B144`; explicit PAL and NTSC remain
available. The Sega export header does not encode TV frequency.

The mounted BUB card has six identical 262,144-byte copies of Alien 3 with
SHA-256 `01e1a84319d4c3c6462ffd79cc77733cfef62aca07cf6c111b5d3c4ed6a364e7`.
The 32 KiB saves beside two copies are all `FF`. The card's `Sega8bit.Dev`
bitstream matches the alpha.7 SHA-256 recorded below. The user reports a
black screen and no audio with the default mapper even under PAL; the core
menu remains usable and changing display size does not help. A direct-engine
simulation and a full SoC/SDRAM simulation of that exact ROM both produced
nonblack video at NTSC timing. With the new Auto TV mode, the integrated
SoC/SDRAM simulation selected PAL for the exact ROM and again produced
nonblack video. The full 51-check `scripts/run_tests.py --four-state` suite
passes with the next-release source changes. Vivado 2024.1 routed the rev4
test image with +0.340 ns setup WNS and +0.023 ns hold WHS, zero failing
constrained endpoints, and zero DRC errors (26 warnings). Its bitstream
SHA-256 is `df6acefda94262a950fbfae69d85b226883e7b226738611f9268a34378c86876`.
The five core files were installed on the BUB card under the separate
`Sega8bit.NextTrial` ID, shown as **GG and SMS Bub Next Test**, and read back
with matching SHA-256 values. The `Sega8bit.Dev` alpha.7 and
`Sega8bit.PALTrial` bitstreams remain unchanged. This is an SD-card install,
not an on-device play result. Alien 3 remains a device-only failure to resolve
before any release claims compatibility. The published alpha.7 ZIP still has
the original 3× behavior and its manual TV setting.

## 2026-10-17 alpha.7 candidate: PAL and control fixes

The unified core now selects SMS NTSC or PAL and includes fixes for the four
open input/display issues: L/R adjusts the SMS 4× crop one source pixel per
press; an on-screen six-step mapper binds D-pad or A/B/X/Y to the emulated
directions and fire buttons; the menu can swap A/B; Select no longer resets
SMS by default; and Start/Pause uses a stable press/release guard. The
optional Select reset requires a one-second hold. Custom on-screen bindings
last for the current core session.

The full `scripts/run_tests.py --four-state` run passed 51 checks, including
the original GG and SMS diagnostic ROMs, SMS 192/224/240 native rasters in
both NTSC and PAL, PAL audio division, mapper prompt logic, Pause bounce and
the integrated host/SoC path. The final one-line crop/mapper isolation change
was followed by another passing integrated SoC test. Vivado 2024.1 then
routed the combined image with +0.389 ns setup WNS and +0.034 ns hold WHS,
zero failing constrained endpoints, and zero DRC errors. The DRC reported 26
warnings, chiefly asynchronous controls of inferred block RAM and existing
framework constraints; the HDMI audio clock remains untimed. The bitstream
SHA-256 is `5bef888d4e6915e638d382c30e24e7d3127c2b033763f7fb80c9c2648ec0c871`.
These are build and simulation results; the combined image still needs a
device play check. FM register control is exercised, but FM synthesis is absent.

## 2026-10-17 local PAL hardware trial; no GitHub release

After the trial was installed, the device tester reported that several PAL
ROMs played and that the requested original test ROMs ran. Exact game names,
hashes, firmware version, audio rates, and save outcomes were not supplied.
This is a successful PAL smoke report for the separate trial, not a play test
of the newer combined controls build. FM was not included.

The rev4 PAL/NTSC bitstream built from local commit
`6ed7d78177866764c8593e086b1faeacf6cdf45c` has SHA-256
`ceaf3e539206829f0a224710a67e6b9617b4a1d321c6c2027617cc2de74626fe`.
The local test ZIP is `build/pal-trial-20261017/GG-and-SMS-Bub-PAL-local-test-rev4.zip`
with SHA-256
`e4ad66f7bbbeec20696940f6bd7f3142c0299b5a5ed2ca4e5247f066d1ef8632`.
It packages the separate `Sega8bit.PALTrial` core ID as **GG and SMS Bub
Test**, includes original GG/SMS diagnostics, and states that FM is absent.
All five core files and the new SMS 192-line diagnostic were installed on the
mounted BUB card, synced, and read back with matching SHA-256. Existing
`Sega8bit.Dev` alpha.6 and `GameGear.Scale23` rollback files were not
overwritten. PAL video, game progression, audio speed, 16 MiB transfer, and
save behavior were not measured individually on device. No GitHub release or
source push was made for this separate candidate. The tester later authorized
a new alpha with PAL and the four control issue fixes.

## 2026-10-17 PAL, FM control, and 16 MiB loader source checks

An original SMS diagnostic and the pinned native engine now exercise 192,
224 and 240 active lines in both NTSC and PAL simulation modes. The completed
viewport descriptor carries the correct TV flag and dimensions. Cadence checks
pass for 262-line NTSC and 313-line PAL after a Gamebub staging correction
to the pinned upstream's PAL 240-line `266 -> 482` jump, which yielded 297
lines. The staged counter now jumps `266 -> 466`, matching the documented
PAL 240-line VCounter sequence. The vendored MiSTer source remains unchanged.
These raster tests count system clocks. The development SoC now has a
**Master System TV** setting, a glitchless dual-MMCM system-clock choice,
and PAL-aware 48 kHz audio averaging. Its PAL MMCM target is 53.205128 MHz
(about 33 ppm above MiSTer's 53.203424 MHz). SoC and audio simulations
pass. Vivado 2024.1 routed the rev4 PAL/NTSC build and wrote a bitstream with
setup WNS +0.058 ns, hold WHS +0.054 ns, no failing constrained endpoints,
and no DRC errors. The existing framework HDMI buffer warning and untimed
HDMI audio clock remain. Actual PAL clock/video output and game compatibility
still require device testing. Alpha.6 remains NTSC only.

An original SMS ROM now writes all eight `$F2` control values and reads them
back through the real Z80, then writes `$F0` and `$F1`. The generated wrapper
passes `fm_enabled` into the upstream system; this source test passes with
that input asserted. The shipping SoC ties it low, and its OPLL remains a
zero-output stub pending the FM licensing and synthesis gate. This test does
not establish audible FM, mixing, or Gamebub audio output. A separate
local-only GHDL synthesis of the pinned MiSTer VM2413 inside the shared
machine passed. Its generated netlist stays ignored and is not part of the
routed PAL trial or any public source/bitstream. A private Verilator check
also sent a keyed tone through the real SMS CPU `$F0`/`$F1` ports into that
VM2413 and observed changing mixed audio. This remains a local feasibility
check, not a released FM feature or an audio-parity result.

The development ROM host window and metadata now accept up to 16 MiB, matching
the size of MiSTer's TecToy Evolution/Noza flash input. An integrated test
skips a synthetic upload's middle, writes its last four bytes through the
normal SoC/SDRAM path, and verifies the final length and mask. It does not
test a complete 16 MiB transfer or the Evolution game/mapper path. The public
alpha.6 package remains unchanged; per the current test hold, no GitHub
release is being published. See
[ROM compatibility audit](../docs/ROM_COMPATIBILITY.md).

## 2026-10-17 community alpha.6 feedback and Auto reproduction

A community tester reports that the alpha.6 build has loaded the games they
tried, but some `.sms` titles start only when **System** is forced to **Master
System**. The tester has not yet supplied the ROM names, hashes, firmware
version, or run lengths, so this is a limited compatibility report. Another
tester reports that the published source built locally; this is not an
independent hardware result. The shared ROM picker remembers the last used
folder for this one core, which adds navigation when GG and SMS ROMs live in
separate directories. Community members demonstrated a two-ID workaround,
but the planned release still targets one selectable core and one bitstream.

The pinned v1.1-beta firmware does not pass `.sms` or `.gg` extensions to the
core. The integrated SoC test now loads a headerless SMS diagnostic with no
hint and confirms that Auto halts with error 8; after a fresh load with the
SMS hint, the same image selects SMS and reaches the normal runtime checks.
The extended test passes in Verilator. An earlier source-only firmware
extension-hint experiment was removed; no firmware build or hardware check
has established this Auto fix on the handheld. Forced System remains the
alpha.6 workaround.

## 2026-10-16 menu name package

[`v0.1.0-alpha.6`](https://github.com/czarroland/gamegear-bub/releases/tag/v0.1.0-alpha.6)
is a public prerelease whose menu name is **GG and SMS Bub**. The existing
internal `Sega8bit.Dev` ID remains so saved settings keep their path. The
package source commit is `b17062b412307cc49898b66432aac31286dcf4d0`;
the bitstream source commit remains
`13cb76b9cd948ddb1afdfe4cb4fb5459785b2366`. Its bitstream is identical
to alpha.5, SHA-256
`0db7c3113fa11391654b0d7ba51dff70d86b4022b45db4404687e47ee14f58ba`.
The uploaded and locally built ZIP SHA-256 is
`b08956c12abc8a80da4baa6f67caec99ac52af578de7fb22bd794a6c34cc47af`.
All 13 ZIP files were copied to `/Volumes/BUB` and read back byte for byte;
the existing settings file SHA-256 stayed
`972829a6ae3e38dbe2ea66bda1ad31d3dcfe9b8368622f4b30ce0560389fe8d9`.
The previous unified-core card files are backed up locally in ignored
`build/card-backup-alpha6`. The menu label has not yet been observed on the
handheld after this copy.

## 2026-10-16 GG/SMS display handoff hardware trial

[`v0.1.0-alpha.5`](https://github.com/czarroland/gamegear-bub/releases/tag/v0.1.0-alpha.5)
is a public prerelease with the corrected LCD frame handoff described below.
Its source tag points to commit `13cb76b9cd948ddb1afdfe4cb4fb5459785b2366`.
GitHub reports the uploaded ZIP digest as
`e6a9103ddff4253343cf356a9ef5aa8b4f6a02031aad81a83aae41d8ea73d966`,
matching the local package. The bitstream SHA-256 is
`0db7c3113fa11391654b0d7ba51dff70d86b4022b45db4404687e47ee14f58ba`.
All 13 package files were installed on the mounted BUB card and read back
byte for byte. The alpha.3 rollback bitstream, settings, and saves were
preserved. An initial Gamebub rev4 play check on 2026-10-16 reports the build
working well. Exact ROM variants, size settings, duration, and save behavior
were not recorded; broader GG/SMS compatibility remains open.

## 2026-10-16 SMS NTSC community prerelease

[`v0.1.0-alpha.4`](https://github.com/czarroland/gamegear-bub/releases/tag/v0.1.0-alpha.4)
is a public prerelease of the one GG/SMS NTSC trial core. Its exact public
source commit is `d71f34e225cbbaba96090164ebfcbd58efe14a75`, bitstream
SHA-256 is `28d39d851cff6a26a6ae6518f7e32a419a8a2f0d8c09ba902b549d6806d5b28d`,
and package ZIP SHA-256 is
`a8f24dcf3140db801982c2995bdea352ca7bec0c91a5a0b9ac1cd543bb89bd49`.
An anonymous download of the public ZIP matched the built package hash.
On the mounted BUB card, all nine core and diagnostic files from that ZIP
match byte for byte; the bitstream is at
`/Volumes/BUB/cores/Sega8bit.Dev/SegaCore-gamebub_rev4.bit`. The alpha.3 GG
core remains available for rollback. Hardware testing exposed a regression:
GG and SMS games animate and respond to buttons but do not advance past their
first screen, including when System is forced to the matching machine type.
The on-device root cause remains unproven; the alpha.5 trial above tests a
specific display handoff correction. The alpha.4 prerelease is therefore
not a qualified playable SMS checkpoint, nor a claim of PAL, FM or full engine
parity.

## 2026-10-16 commercial-game video regression investigation

On alpha.4 hardware, the GG diagnostic's color bar changes when Start is held
and changes back on release. Commercial ROMs still fail: Sonic Triple Trouble
plays an input sound effect without leaving the SEGA screen, and the tested
English translation of Sylvan Tale is white from launch. Both GG ROMs display
normally under alpha.3. This narrows the fault to the new unified path under
game-specific timing; the precise on-device cause is not yet proven.

Local-only RTL traces used the same two owned ROM files without adding them to
source control or release assets. In each 75-frame native-engine run, 73
completed 160×144 viewport descriptors were valid and frame hashes changed
after Start or during gameplay. The native GG frame tracker therefore did not
reproduce the stuck hardware picture in these traces.

The alpha.4 rev4 display RTL fed the LCD driver's `lastRenderedFrame` through a
single-bit clock synchronizer while the matching viewport descriptor crossed
through a separate multi-bit handshake. The LCD could switch buffers before
its descriptor arrived; stale descriptor ownership could then reject later
captures. The development patch now drives that LCD signal from the
descriptor's own buffer index. It also allows a newly granted capture on the
first active pixel when vblank falls. Chisel rev4 elaboration passes with both
changes. Vivado 2024.1 routed the corrected rev4 image with setup WNS
+0.366 ns, hold WHS +0.027 ns, no failing constrained endpoints, DRC zero
errors and 26 warnings. The new bitstream SHA-256 is
`0db7c3113fa11391654b0d7ba51dff70d86b4022b45db4404687e47ee14f58ba`.
A hardware trial is still required; alpha.4 remains unsuitable for normal play.

## 2026-10-16 shared viewport development checkpoint

The development core now declares a fixed 256×240 video storage capacity and
exports completed native viewport dimensions, system/TV flags, epoch and frame
ID from the GG/SMS frame tracker. A combined patch against the pinned Gamebub
framework adds two fixed-stride buffers, a coherent completed-frame descriptor,
display-buffer ownership feedback, bounded sharp 2×/3× LCD/HDMI addressing,
and masked host readback outside the active image. The framework drops and
counts a capture when the display still owns its target buffer or SPI readback
conflicts with capture. The updated top elaborates with Chisel on rev4.

An initial routed 256×240 implementation closed timing after Vivado 2024.1
post-route optimization at setup WNS +0.040 ns and hold WHS +0.001 ns. Its
audio averaging divider dominated the original timing miss. That divider now
computes the same signed result one bit per clock over the roughly
1,118-clock sample interval; the legacy audio test and a new exact signed
division test over varied input windows pass. The completed ownership/audio
revision at development commit `7c72beb` fits with 8,369 LUTs, 65 RAMB36 and
3 RAMB18, and routes with setup WNS +0.168 ns and hold WHS +0.049 ns.
Vivado wrote a bitstream, but this revision still holds the active SoC at
GG/NTSC and is not an SMS release.

The next working revision connects the ROM-type decision to a drained,
recoverable GG/SMS runtime profile transaction, sets SMS's default size to
sharp 2×, and couples the chosen scale to each completed frame descriptor.
All 34 host regression checks pass, including the real GG and SMS engines,
GG→SMS loading through the same SoC, GG 160×144 and SMS 256×192 viewport
sidebands, same-ROM machine override, Pause/console Reset, and retained save
RAM. A targeted SoC rerun also passes the finalized `SEG2` registers and
settings. The framework patch applies to the pristine pinned source, Chisel
elaborates, and the rev4 implementation fits at 8,924 LUTs, 65 RAMB36 and
3 RAMB18. Vivado 2024.1 routed the combined runtime design and wrote a
bitstream with setup WNS +0.221 ns, hold WHS +0.027 ns, no failing constrained
endpoints and DRC 0 errors/26 warnings. The HDMI audio-clock and other
external I/O timing limitations described below still apply. The public
prerelease, matching SD-card installation, and hardware regression are
recorded above.

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

The installed alpha.3 core passed a hardware smoke test. The exact ROMs,
scale selections, test duration, audio and save round-trip results have not
been recorded; no broader hardware compatibility claim is made.

The first independent native MiSTer decoder oracle passes in GHDL for GG/SMS
cartridge selection and bank addressing, including the `$3E` no-BIOS fix. A
real-engine SMS diagnostic passes in Verilator for Pause NMI under `DI`, held
press/repress, the console Reset I/O bit and a complete 256×192 native frame.
Separate real-engine diagnostics pass for 256×224 and 256×240 NTSC frames and
their completed viewport descriptors. PAL timing and physical display are
still unverified.
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
The existing custom firmware was left in place.

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
safely ejected. Subsequent rev4 testing confirmed that both the diagnostic ROM
and Sonic Triple Trouble load and run. The bitstream was
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
`GameGear.Alpha` bitstream still has its known-good SHA-256. The 2×/3× scaling
trial works on hardware. The new 4× centered crop option
passed the integrated simulator suite and Vivado 2024.1 post-route timing:
setup WNS +0.075 ns, hold WHS +0.024 ns, no failing constrained endpoints.
Its bitstream SHA-256 is
`3735089578fbc3645522fa0f12079421cdc9830e7a6bb8a969d2c1f6a128ee2e`.
The `GameGear.ZoomTrial` package was installed on BUB, all five files were
verified byte for byte, and the card safely ejected. The older core bitstreams
still match their recorded SHA-256 values. The 4× mode works on hardware.
A 3.5× bilinear mode is now
packaged separately for a smaller vertical crop. The integrated simulation
suite and Chisel generation passed. Vivado 2024.1 post-route timing closed at
setup WNS +0.008 ns and hold WHS +0.054 ns, with zero failing constrained
endpoints. The bitstream SHA-256 is
`2952f533f7f3d1a7ccbf7ffe04ebc804157bccedbb0a1440f36d9fdc4bdee567`.
The `GameGear.SmoothTrial` package was installed on BUB, all five files were
verified byte for byte, and the card safely ejected. The older Alpha and Zoom
bitstream hashes remain unchanged. The 3.5× mode works on hardware.
Alternative fractional filters remain on the roadmap.

A community tester reported short successful runs with NA/JP/EU ROMs, demos,
test suites, and patched/translated GG titles, and reported working saves.
The same tester found that adding `.sms` to the GG-only file metadata permits
some SMS-format titles to start but leaves missing Pause input, wrong palette,
and 160×144 cropping. These reports inform the SMS tests; most play sessions
were approximately five minutes or less.

Retail games, non-Sega mappers, EEPROM saves, 224-line mode, and SMS
compatibility remain unverified or unimplemented. See `docs/BUILD_AND_TEST.md`
for the board test sequence.
