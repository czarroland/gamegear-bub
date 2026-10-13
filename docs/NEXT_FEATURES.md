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
| Selectable scaling and display options | Fixed sharp 3× Game Gear image; options absent |
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

The rev4 framework currently scales 160×144 to 480×432, centered on its
800×480 LCD: sharp integer 3× nearest-neighbor pixels. A 2× choice would be
320×288. A screen-filling choice would be noninteger and needs a pixel filter
to avoid uneven steps. The existing core settings can expose the choice, but
the framework's scale factor is fixed when generated. Implement a core-specific
display-scale interface in the local framework and synchronize the setting
into the LCD clock domain. Keep 3× as the default until the alternate modes
have been verified on hardware.

## 4. Master System

The upstream system supports SMS mode, but the current wrapper ties the Game
Gear mode inputs high and declares a 160×144 video framebuffer. SMS needs
mode-appropriate controls, 256×192 video (and later 224-line support), ROM
extensions, region timing, and mode-aware package metadata. Develop SMS mode
alongside the known-good GG package, verify an SMS diagnostic before retail
games, then expose both systems through a unified Gamebub core if the firmware
can identify the selected ROM type reliably. The final user experience should
match the MiSTer core's multi-system behavior as closely as practical.
