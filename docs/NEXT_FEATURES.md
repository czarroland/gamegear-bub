# Unified Sega 8-bit core roadmap

The diagnostic ROM and Sonic Triple Trouble now run on hardware. Preserve the
current bitstream and core package as the known-good Game Gear baseline.
The target is one Gamebub rev4 core entry, ROM picker and bitstream for Game
Gear and Master System (NTSC/PAL), including FM sound. A feature is complete
only after simulation, a routed build and a named hardware test. Publish each
usable test checkpoint as a GitHub prerelease and install the identical package
on the Bub SD card. Keep the existing Game Gear release as a rollback baseline.

| Upstream feature | Gamebub port status |
| --- | --- |
| Native Game Gear, stereo PSG, Sega mapper | Runs diagnostic and Sonic Triple Trouble on rev4; broader compatibility pending |
| Battery-backed cartridge RAM | Export verified on hardware; import marker test pending |
| Persistent save states | Outside this implementation slice |
| Master System | GG/SMS NTSC alpha.4 trial fails on hardware; alpha.5 received an initial successful rev4 play check. Alpha.6 retains its bitstream with the **GG and SMS Bub** menu name; broader compatibility remains open |
| System Auto and ROM picker | The current firmware provides no extension hint, so some community-tested `.sms` games require a forced Master System setting. One picker remembers one last ROM folder. A source-only firmware hint patch exists; no Bub firmware build has been installed or verified |
| Selectable scaling and display options | Sharp 2×/3× rev4 build published as `v0.1.0-alpha.3` and installed on BUB; hardware smoke testing passed. Individual ROM/scale results remain to be recorded |
| Region and mapper override | Exposed; only some mapper paths tested |
| SG-1000, SC-3000, System E, Evolution/Noza | Upstream logic present; no Gamebub packages or mode adapters |
| PAL timing and FM sound | Planned in the same unified bitstream; not yet connected |
| Extra sprites, extended GG resolution, Z80 turbo | Outside the normal-speed parity profile |
| BIOS loading, cheats, EEPROM cartridges | Not integrated |
| Advanced controllers and Gear-to-Gear link | Gamebub controls/physical connectivity need separate evaluation |

## 1. Battery-backed game saves

The current GG core already imports and exports a 32 KiB cartridge RAM image as
`<ROM name>.sav`. The firmware loads that file on entry and writes it on normal
exit or power-off preparation. The diagnostic ROM writes `5A` to the first
byte of this RAM. Normal exit on hardware has created a 32,768-byte
`gamegear-diagnostic.sav` with first byte `5A`. A backed-up copy was marked
at bytes 1–3 and the final byte; relaunch and exit must preserve those markers
to verify import. Then test a retail title that actually uses battery-backed RAM.
Only change the bitstream if this test exposes a defect. EEPROM cartridges
will need a separate save format and implementation.

## 2. Save states (later work)

The MiSTer engine exposes snapshot and restore ports for CPU, VDP, sound,
mapper, IO, VRAM, and cartridge EEPROM state. They are currently unconnected
in the Gamebub wrapper. A complete state must also include Gamebub-side work
RAM and cartridge RAM, emulator timing and SDRAM arbitration state, a version,
and ROM identity. Restore must be atomic while the engine is frozen.

The current firmware's third-party core file API imports files at launch and
exports them on exit. It has no general in-game state file transaction. A
state that can be saved and loaded during play therefore needs either a
firmware UI/API extension or a deliberately limited exit-and-relaunch flow.
Choose the intended user flow before implementing the serialization protocol.

## 3. Selectable display scaling

Only sharp integer 3× and 2× remain selectable. On Game Gear's 160×144 image
they produce 480×432 and 320×288 respectively. The framework patch retains
its multi-bit clock-domain handshake and applies a scale change at an output
frame boundary, with one read port per framebuffer. Legacy stored values 2
(4×) and 3 (3.5×) normalize to the Game Gear default of 3×. The prior 4× and
3.5× packages were hardware trials and remain documented as historical results
in `docs/BUILD_AND_TEST.md`; they are not the target display roadmap. The new
2×/3× branch passed Chisel generation, the host regression suite and rev4
post-route timing. The public
[`v0.1.0-alpha.3`](https://github.com/czarroland/gamegear-bub/releases/tag/v0.1.0-alpha.3)
package was installed under the separate `GameGear.Scale23` ID and verified
against the public ZIP hash. Hardware smoke testing passed; the precise ROM,
scale and duration are not yet recorded.

## 4. Master System and FM in the same core

The GG-only alpha.3 wrapper fixes Game Gear mode and declares a 160×144 framebuffer.
The unified alpha.4 wrapper selects GG or SMS NTSC at runtime. Its framework patch
allocates one pair of 256×240 framebuffers, publishes completed-frame
geometry/epoch/buffer ownership coherently, and addresses pixels with a fixed
256-column stride. The LCD/HDMI output applies the native dimensions at a
display frame boundary with literal sharp 2×/3× sampling, including the
specified SMS crop. Captures are dropped rather than overwriting a buffer
being scanned; host readback masks storage outside the completed viewport.
This framebuffer path generated Chisel RTL and the ownership revision
passed a rev4 route with +0.168 ns setup and +0.049 ns hold slack. The later
alpha.4 package passed timing and was installed, but games stalled on their
first screen in hardware tests. The alpha.5 package changes the LCD handoff
and capture edge, passed timing, and is published and installed. An initial
rev4 play check reports it working well; exact ROMs/settings are not recorded.
The first native-versus-staged MiSTer decoder fixture passes in GHDL for
cartridge selection and bank addressing, including the `$3E` no-BIOS SMS fix.
This is a narrow oracle, not a claim of full engine parity. A real-engine SMS
diagnostic also passes in simulation: Pause reaches the Z80 NMI handler with
maskable interrupts disabled, a held press does not repeat, console Reset
appears at port `$DD`, and the native raster produces a full 256×192 frame.
Separate real-engine diagnostics also confirm 256×224 and 256×240 frame
boundaries and their completed descriptors. These are NTSC simulation cases;
PAL clock behavior and on-device presentation remain unverified.
The ROM type resolver accepts a load-epoch hint and falls back to a validated
Sega header; its host transaction path passes the integrated SoC test. The
video adapter now records dimensions, mode and epoch after a complete frame;
synthetic tests cover GG 160×144 and SMS 256×192/224/240, plus a malformed
line and epoch flush. The next working SoC revision now applies the selected
GG/SMS profile after the ROM bus drains and a cold restart completes. It is
passing integrated simulation and rev4 timing. The alpha.4 GG/SMS hardware
package is a diagnostic prerelease and is not playable. The alpha.5 trial
has an initial successful on-device report but no broad compatibility result.
The loader must convey a
guarded `.gg`/`.sms` type hint, with System Auto and a manual override. SMS
requires its full palette, 256-column raster with 192/224/240-line modes,
Pause NMI and console Reset semantics. Runtime PAL/NTSC timing and a shared FM
synthesizer must fit in that same bitstream. FM redistribution requires the
licensing gate described in the implementation plan before any public build.
The current [FM implementation gate](FM_IMPLEMENTATION_GATE.md) records the
pinned source's restrictions, candidate alternatives, and private tool checks.

`patches/firmware-load-type-hint.patch` is a companion source patch against the
pinned core-loading firmware. It adds an optional, guarded extension hint and
case-insensitive picker matching. The patch has not been compiled into or
installed as firmware; the current GG package does not use it.

Community testing of the GG-only build found that simply admitting `.sms`
files is insufficient: some titles need SMS Pause, while SMS palette and
256×192 pixels appear incorrectly in the 160×144 GG framebuffer. These are
specific acceptance checks for the SMS adapter; reports so far are short
sessions rather than long-run compatibility tests.
