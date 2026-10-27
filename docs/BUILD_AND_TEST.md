# GG and SMS Bub — rev4 build and hardware test record

The published Game Gear alpha releases and earlier scaling trials are hardware
test records. The diagnostic ROM and Sonic Triple Trouble run on rev4 under
the GG-only build. The unified GG/SMS NTSC development branch uses one SoC and
a shared 256×240 framebuffer. Alpha.4 exposed a first-screen video regression;
alpha.5 received an initial successful hardware play check. The alpha.6
prerelease uses the same bitstream with the **GG and SMS Bub** menu name and
is installed on the BUB SD card. Alpha.3 remains the GG-only rollback.
The published alpha.6 build has no FM or PAL. A separate local PAL trial
passed routed timing and several PAL ROMs played on hardware. Alpha.7 includes
PAL raster and clock selection plus the four control fixes. Its combined image
passed routed timing and still needs its own device test.
FM synthesis remains gated. See `docs/SEGA_RUNTIME_ABI.md` for the unified
package's registers, defaults, and compatibility limits; the records below
describe the earlier GG-only hardware checkpoints.

## Scope

The first target is Gamebub revision 4 and native Game Gear mode: 160×144 pixels,
12-bit color, stereo PSG, Sega bank switching, and 32 KiB cartridge RAM.
ROMs must be headerless, 32 KiB–4 MiB, and aligned to four bytes. The upstream
mapper detector receives every committed ROM byte in address order. Auto,
Sega, Codemasters, Dahjee, Linear, and Zemina settings are exposed; only Auto
and Sega have been exercised by this checkpoint's diagnostic.

The first GG-only checkpoint fixes GG mode and omits the BIOS, FM chip, cheats,
System E decryption, and save-state frontend. The unified GG/SMS/FM target is
described in `docs/NEXT_FEATURES.md`. Game Gear serial-link support is disabled.
The 224-line VDP mode's GG crop and retail-game compatibility are unverified.

| Bub control | Game Gear input |
| --- | --- |
| D-pad | D-pad |
| B | Button 1 |
| A | Button 2 |
| Start | Active-low Start, read at port 0 bit 7 |

Opening the firmware menu leaves emulation running, masks game input, and mutes
audio. Cartridge export freezes the engine until FileReadEnd; SDRAM refresh
continues. Reset and Halt retain cartridge RAM. A new save import clears its
32 KiB slot to `FF`, so short saves have a defined tail.

## Pinned sources

| Source | Revision |
| --- | --- |
| [SMS_MiSTer](https://github.com/MiSTer-devel/SMS_MiSTer) | `8443a0d19a88aff7a5900011bccf386daf146945` |
| [Gamebub framework](https://github.com/gamebub/framework) | `db9d3b0e7989db4a8edc66e47b843097d71f078c` |
| [Third-party core template](https://github.com/gamebub/core-example) | `00d68424946aa5e5620c15dce700e22b209f7291` |
| [Core-loading firmware](https://github.com/elipsitz/gamebub/tree/v1.1-beta) | `9966de77f037ae5d7610bd9d2b6f0b512ff7eb5c` |

The firmware checkout is **v1.1-beta**, whose handheld Cargo version is
**1.1.0-beta2**. Its HDMI dependency is
`380c974933ce0221aeed8bbf8f667d2dd0027961`. This enabling firmware was pulled
and inspected. The stock/default firmware checkout was also inspected; it
does not provide the same working third-party core loading path.

The local development workspace contains a pulled firmware source subset, but
this source repository does not vendor the firmware. `manifests/repositories.json`
records the pins. To obtain the complete firmware repository, including FPGA
sources and the HDMI submodule:

```bash
git clone https://github.com/elipsitz/gamebub.git gamebub-firmware
cd gamebub-firmware
git checkout 9966de77f037ae5d7610bd9d2b6f0b512ff7eb5c
git submodule update --init --recursive
```

No firmware was compiled or flashed in this workspace. Firmware builds need
the pinned project's ESP32-S3/Xtensa Rust toolchain (the crate requires Rust
1.93), ESP-IDF 5.4.3, and the correct board feature. For revision 4, the app
build uses `cargo build --release --features rev4` from `firmware/handheld`.
Its UF2 bundler takes the built app ELF plus a complete `system_data` directory;
that directory also needs the Gamebub built-in assets/bitstreams. Follow the
pulled project's build setup before running that command. Do not assume that
an older stable UF2 supplies this core loader.

## Source layout

| Path | Purpose |
| --- | --- |
| `vendor/sms_mister/rtl` | Original pinned Sega sources |
| `rtl/generated` | Regenerated, patched engine; `.vhd` normalized to `.vhdl` |
| `patches` / `manifests` | Auditable source diffs, hashes, and all 182 port bindings |
| `rtl/portable` | Common-clock memories replacing Altera primitives |
| `rtl/platform` | GG engine wrapper, host protocol, SDRAM, clocks, video, audio |
| `chisel/src/GameGearCore.scala` | Gamebub framework interface declaration |
| `generated/handheld_rev4` | Local generated rev4 RTL snapshot; excluded from this repository |
| `framework` | Pinned local build dependency; excluded from this repository |
| `metadata` | Core, ROM/save, and settings descriptors |
| `tests` / `scripts` | Actual-engine simulations and reproducible tooling |
| `diagnostics` | Original diagnostic ROM, generated by source in `scripts` |
| `reports` | Recorded simulation results and captured frame |

The vendored Sega files preserve the exact bytes of the pinned upstream
revision, including CRLF line endings in four files. Staging decodes UTF-8 and
normalizes CRLF to LF only in `rtl/generated`; `manifests/sources.json` records
both raw and staged hashes and each file's newline normalization. Staging now
rejects a changed vendor hash or missing upstream patch anchor. Identifier
rewrites leave VHDL comments and string literals intact.

The Sega staging script excludes unavailable peripherals explicitly, adds a
CPU WAIT input, fixes a nine-bit T80 mask, normalizes entity bindings/case
choices, and avoids Verilog-reserved or conflicting synthesized names. Staging
does not edit the original vendor files. The new work RAM clearer holds CPU
reset for 8,192 clocks. Loading acknowledges a host word only after four SDRAM
bytes commit; those same commit events feed the mapper detector and CRC.

## Reproduce simulation

Install Python 3, GHDL with synthesis support (4.1 tested), Icarus Verilog
(12 tested), Verilator (5.020 tested), GNU Make, and a C++ compiler. On Ubuntu,
the relevant packages are `ghdl-mcode iverilog verilator g++ make`.

```bash
python3 scripts/run_tests.py
python3 scripts/run_tests.py --four-state
```

The second command additionally runs the full engine in four-state Icarus,
which takes longer. Executable overrides are `GHDL`, `IVERILOG`, `VVP`, and
`VERILATOR`. `IVL_BASE` supports a relocated Icarus installation. Verilator's
normal `VERILATOR_ROOT` override is also supported.

The suite generates Verilog from the real VHDL CPU/VDP/memory engine and links
the real JT89 Verilog sound chip. It does not substitute a CPU, VDP, or PSG.
The integrated testbench sends the command format used by the pulled firmware;
it does not run the Rust MCU firmware itself.

Passing checks cover memory initialization/latency, signed audio and fractional
48 kHz sample cadence, SDRAM byte lanes/rows/banks/CAS/refresh, mapper streaming,
bank selection, CRC and length validation, host request lifecycles, input and
focus behavior, three complete 160×144 frames, native frame cadence, and a full
32 KiB save export with the CPU frozen and SDRAM refreshing. Each native frame
takes `342 × 262 × 10 = 896,040` system cycles. The signed audio boxcar's two
window lengths differ by one clock, giving less than 0.1% gain variation.

The captured diagnostic frame contains exactly 11,520 red and 11,520 green
pixels. It comes from actual simulated CPU writes to the VDP and its palette.
The actual rev4 Chisel/SDK generation also passes; all 53 external-module ports
match the implementation, and the generated display divider is 38. The SDK
generates 23,040×12 framebuffer banks for this 160×144 declaration.

Tool logs retain upstream JT89 width warnings and GHDL-generated AudioMix
combinational warnings. Passing simulation does not establish Vivado memory
inference, closure of the SDRAM I/O constraints, or physical-chip behavior.

## Build the FPGA bitstream

Install Vivado with Artix-7 `xc7a100tcsg324-1` support, Java 21, and the Python
dependencies `edalize==0.6.7` and optionally `heatshrink2`. Source Vivado's
`settings64.sh`, and make Java 21 available on `PATH`. The project uses the
installed Java toolchain; Mill and Maven dependencies must be reachable.
Obtain the pinned Gamebub framework at the revision listed above under its
own terms and place it at `framework/`; it is a local dependency and is not
part of this repository. Apply the current runtime viewport source patch to a **clean**
checkout of that pinned framework before generating Chisel RTL:

```bash
git apply --check patches/framework-video-runtime.patch
git apply patches/framework-video-runtime.patch
```

```bash
python3 scripts/prepare_sources.py
python3 scripts/generate_machine.py
./mill -i root.runMain platform.handheld.HandheldTop GameGearCore 4 --target-dir=build/chisel-generated
python3 scripts/build_core.py --target gamebub_rev4
```

Use this port's Python build entrypoint: it invokes the untouched framework
builder with an external **VHDL-2008** source setting. The pinned framework's
plain `root.buildCore` entrypoint labels VHDL with its default language version,
which is insufficient for the upstream engine's dynamic port expressions.

For an offline Vivado build from a locally generated RTL snapshot, the
repository also provides:

```bash
vivado -mode batch -source scripts/vivado_checkpoint.tcl
```

The earlier GG-only Tcl build ran in the x86-64 Docker Vivado environment on
this Mac. Set
`GG_GENERATED_RTL` to an alternate Chisel output directory and
`GG_VIVADO_OUTPUT` to an alternate reports/bitstream directory when building
a trial without overwriting the known-good snapshot. It
writes reports and a routed checkpoint under `build/vivado-checkpoint`, and
checks setup and hold timing before writing a `.bit`. The first routed pass
missed setup timing by 0.240 ns; `scripts/vivado_finish_route.tcl` used Vivado's
post-route physical optimization on the same checkpoint and wrote the bitstream
after setup and hold passed. Final WNS is +0.002 ns and WHS is +0.052 ns.
This margin is small, so the artifact is intended for a first diagnostic test.

The MMCM uses a 1 GHz VCO: system `/18.625 = 53,691,275.168 Hz`, SPI `/5 =
200 MHz`, and a display divider selected against both framework LCD bounds
(`/38` on rev4). CPU and pixel enables divide system frequency by 15 and 10.
Native frame frequency is approximately 59.9206 Hz. Only one SDRAM chip is used.

`rtl/platform/gg_sdram.xdc` supplies provisional SDRAM timing budgets. Verify
the fitted chip's data sheet, board skew, forwarded clock polarity, and CAS
capture position before hardware release. The routed report has no failed
timing endpoints and SDRAM I/O is constrained. The framework retains an HDMI
clock-routing critical DRC warning and unconstrained non-SDRAM I/O and HDMI
audio-clock paths. Review Vivado timing/DRC and actual RAMB18/RAMB36 use before
any broader release.
Inspect whether the portable RAMs infer block RAM, and verify framebuffer
allocation at the declared 160×144 size. Measure the ROM WAIT counter (`0x114`)
under normal play; optimize arbitration if stalls materially alter CPU pacing.

## Historical first test on the Bub

The test rev4 already has custom core-loading firmware. The known-good
baseline is packaged on BUB. To reproduce its package from the reviewed
bitstream:

```bash
python3 scripts/package_core.py --bitstream build/vivado-checkpoint/GameGearCore-gamebub_rev4.bit --output build/core-package
```

That first package was at `/Volumes/BUB/cores/GameGear.Alpha`; the diagnostic was at
`/Volumes/BUB/roms/GameGear/gamegear-diagnostic.gg`. Their SD copies were
verified byte for byte. Later public alpha releases use `GameGear.Dev`, so
check the package metadata before copying a new build to the SD card. For the
historical first test, eject BUB in macOS, then select the Game Gear
development core and this diagnostic ROM on the handheld.

1. Expect alternating red/green vertical bands, with a complete 160×144 image.
2. Hold Start: green bands become blue. Release: they return to green.
3. Hold either A or B: red bands become blue. Release: they return to red.
4. With stereo output, expect a tone in the left channel and a silent right
   channel. Open the firmware menu: sound should mute and game buttons should
   be masked. Return to the game: sound and controls should resume.
5. Exit through the firmware's normal menu rather than powering off. Mount BUB
   and check that `gamegear-diagnostic.sav` appeared beside the ROM. It should
   be 32,768 bytes, begin with `5A`, and have an `FF` tail. Relaunch the same
   ROM to check that the firmware imports the file. In the simulation's short
   imported save, bytes 1–3 deliberately remain `22 33 44`.
6. Use Reset game and reload the diagnostic; the image and controls should
   return. Then test a small Game Gear game you own, including Start, scrolling,
   stereo, repeated menu entry, and any cartridge save. Record its ROM CRC,
   mapper/region setting, firmware version, hardware revision, and symptoms.

For a ROM with a detected 512-byte copier header, create a separate normalized
copy before loading:

```bash
python3 scripts/prepare_rom.py original.gg normalized.gg
```

The tool also adds at most three `FF` alignment bytes and prints the CRC.
It leaves the supplied ROM unchanged and refuses to overwrite an existing
output. It does not change a game's region or turn an SMS title into a GG one.

## Selectable scaling in the implementation branch

The `Game Gear size` setting (ID 4, register `0x1c`) offers literal sharp 3×
(default, 480×432) and 2× (320×288). Old 4× value 2, old 3.5× value 3,
and any other invalid 32-bit value normalize to 3×; register readback reports
the effective choice. The framework patch keeps a coherent multi-bit CDC
handshake and applies the selected size at a display frame boundary. Each game
framebuffer has one read port. The SMS-only 3× crop path samples a 256×160
source viewport and centers it on LCD/HDMI output; L/R moves its vertical
source origin one pixel per stable press. There are no extra corner samples,
bilinear arithmetic, or fractional viewport calculations. The alpha.9 candidate
routed with +0.310 ns setup WNS and +0.047 ns hold WHS, zero failing constrained
endpoints, and zero DRC errors. The `sms-top-row-diagnostic.sms` ROM puts a
red line at native row zero and blue below it. The companion
`sms-crop-position-diagnostic.sms` uses red row zero, magenta rows 1–15,
green rows 16–31, yellow rows 32–47, and blue below. In 3× from a fresh
centered crop, 16 separate R taps should show red/magenta at the top;
16 separate L taps should show yellow. This distinguishes viewport motion
from a line fixed to the LCD edge. The device result is pending.

The SMS TV menu setting selects Auto, NTSC or PAL. The original 192, 224, and
240 line raster diagnostics should show a stable picture at both rates. The
next alpha's Map controls action prompts for ten commands, including
Start/Pause, crop up/down and optional Reset. Tap any physical D-pad, face,
shoulder, Start or Select button to bind; hold a button for one second to keep
its binding, or hold Start+Select to exit. This mapping lasts for the current
core session. The separate Swap A/B menu choice persists in settings. After
selecting Map controls, manually exit the core settings menu to see the
mapping prompt ([known issue #9](https://github.com/czarroland/gamegear-bub/issues/9)).
During an SMS game, Start acts as Pause after a stable press. Select has no
game action by default; the optional Hold 1s Reset choice enables a guarded
console reset. Verify these on a disposable save before treating a device
check as passed.

Use a clean copy of the pinned framework when applying the patch. A copy that
has already received an earlier scaling patch can retain obsolete logic even
if the patch file in this repository has changed. Verify the generated RTL and
routed RAM utilization before claiming hardware resource recovery. The alpha.9
candidate has positive timing slack in a new rev4 route.

### Superseded scaling hardware records

These results describe earlier packages, not the current 2×/3× target:

| Earlier trial | Bitstream SHA-256 | Reported setup WNS | Hardware result |
| --- | --- | --- | --- |
| 2×/3× | `43f5385af381ae2290b9a1587c892b83fbd138310a18977e0f55dfab59a297ba` | +0.005 ns | Both sizes confirmed on rev4 |
| 4× crop | `3735089578fbc3645522fa0f12079421cdc9830e7a6bb8a969d2c1f6a128ee2e` | +0.075 ns | Centered crop confirmed on rev4 |
| 3.5× bilinear | `2952f533f7f3d1a7ccbf7ffe04ebc804157bccedbb0a1440f36d9fdc4bdee567` | +0.008 ns | Smooth mode confirmed on rev4 |

The four-port fractional trial increased reported RAMB36 use from 41 to 113.
These are historical measurements; do not apply them to a new build without a
new routed report.

## Next engineering gates

1. Rebuild and simulate the 2×/3× source against the clean framework; check
   old setting values, readback, frame-boundary switching, overlay and LCD/HDMI
   geometry. Route one rev4 image and record resource/timing reports.
2. Refresh the pinned Sega source fixes and implement one runtime GG/SMS machine
   profile with 256-column SMS video, full SMS palette, Pause/Reset controls,
   a guarded ROM type hint and save-preserving mode transitions.
3. Include FM after its redistribution route is resolved, then qualify NTSC/PAL
   native timing, audio, SDRAM deadlines and long hardware sessions in the same
   bitstream. Keep unverified profiles and mappers explicit.
4. For each hardware-usable checkpoint, install a test package on the BUB SD
   card and publish an accurately labeled GitHub prerelease of the identical
   package after simulation and routed timing pass. The separate PAL trial
   received a positive device smoke report; the combined controls build still
   needs its own device test and must be labeled accordingly. Record the
   release tag, source and bitstream hashes, firmware identity, copied path,
   Bub test results and rollback package. Do not publish a timing-failing
   build as a usable community release.

Preserve original source notices and keep framework modifications as a
reviewable patch when preparing a release.
