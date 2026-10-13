# MiSTer feature parity roadmap after the first rev4 Game Gear run

The diagnostic ROM and Sonic Triple Trouble now run on hardware. Preserve the
current bitstream and core package as the known-good Game Gear baseline.
The target is the [MiSTer SMS/Game Gear core's documented feature set](https://github.com/MiSTer-devel/SMS_MiSTer)
where Gamebub hardware and firmware permit it, with the user's four requested
features first. A feature is complete only after a hardware test, not just
because its upstream logic is present in the source tree.

| Upstream feature | Gamebub port status |
| --- | --- |
| Native Game Gear, stereo PSG, Sega mapper | Runs diagnostic and Sonic Triple Trouble on rev4; broader compatibility pending |
| Battery-backed cartridge RAM | Export verified on hardware; import marker test pending |
| Persistent save states | Not connected to Gamebub frontend |
| Master System | Engine present, Gamebub mode and video wrapper absent |
| Selectable scaling and display options | 2×/3×, 4× crop, and 3.5× bilinear confirmed on rev4; 3.5× is the preferred size but looks blurry |
| Region and mapper override | Exposed; only some mapper paths tested |
| SG-1000, SC-3000, System E, Evolution/Noza | Upstream logic present; no Gamebub packages or mode adapters |
| PAL timing, FM sound, extra sprites, extended GG resolution, Z80 turbo | Disabled or fixed to NTSC/native settings |
| BIOS loading, cheats, EEPROM cartridges | Not integrated |
| Advanced controllers and Gear-to-Gear link | Gamebub controls/physical connectivity need separate evaluation |

## 1. Battery-backed game saves

The current core already imports and exports a 32 KiB cartridge RAM image as
`<ROM name>.sav`. The firmware loads that file on entry and writes it on normal
exit or power-off preparation. The diagnostic ROM writes `5A` to the first
byte of this RAM. Normal exit on hardware has created a 32,768-byte
`gamegear-diagnostic.sav` with first byte `5A`. A backed-up copy was marked
at bytes 1–3 and the final byte; relaunch and exit must preserve those markers
to verify import. Then test a retail title that actually uses battery-backed RAM.
Only change the bitstream if this test exposes a defect. EEPROM cartridges
will need a separate save format and implementation.

## 2. Save states

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

The rev4 LCD scales 160×144 to 480×432 at the default sharp integer 3×. The
Screen size setting also selects sharp 2× (320×288) and 4× zoom (640×576);
the user confirmed all three on rev4 hardware. The 4× choice crops 12 native
lines at each vertical edge. The source now includes a 3.5× bilinear choice
that renders 560×504 and crops about 3–4 source lines at each edge. It blends
four neighboring framebuffer pixels using exact sevenths in both axes. The
panel's display offset compensates for its physical alignment. The optional
framework interface sends the scale mode through a multi-bit clock-domain
handshake and applies it at a frame boundary. The framework change is kept as
`patches/framework-video-scale.patch` against the pinned framework. The user
confirmed that 3.5× works on hardware and is the preferred image size, but its
bilinear interpolation is visibly blurry. Develop and compare a sharper
fractional filter while keeping all four selectable sizes. The current 3.5×
bitstream passes post-route timing with only +0.008 ns setup margin.

## 4. Master System

The upstream system supports SMS mode, but the current wrapper ties the Game
Gear mode inputs high and declares a 160×144 video framebuffer. SMS needs
mode-appropriate controls, 256×192 video (and later 224-line support), ROM
extensions, region timing, and mode-aware package metadata. Deliver SMS first
as a separate selectable core, because the framework currently fixes the
framebuffer size when the bitstream is built. Verify an SMS diagnostic and
Pause input before retail games. A later unified core needs a way to select
the video dimensions and report the ROM type to the FPGA. The final user
experience should match the MiSTer core's multi-system behavior as closely as
practical.

Community testing of the GG-only build found that simply admitting `.sms`
files is insufficient: some titles need SMS Pause, while SMS palette and
256×192 pixels appear incorrectly in the 160×144 GG framebuffer. These are
specific acceptance checks for the SMS adapter; reports so far are short
sessions rather than long-run compatibility tests.
