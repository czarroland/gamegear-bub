# Sega 8-bit development core ABI (SEG2)

This describes the unified GG/SMS NTSC/PAL development bitstream. The public
Game Gear alpha.3 package retains its earlier `GGB1` ABI and core ID.

| Offset | Access | Meaning |
| --- | --- | --- |
| `0x00` | Read | `0x53454732` (`SEG2`) |
| `0x04` | Read | `0x00020000` ABI version |
| `0x08` | Read | Capability bits: 0 GG, 1 stereo, 2 cartridge SRAM, 3 diagnostics, 4 SMS, 5 PAL |
| `0x0c` | Read | Active machine: 0 none, 1 GG, 2 SMS |
| `0x10` / `0x14` | Read/write | Region and mapper, retained setting IDs 1 and 2 |
| `0x18` | Read | Fixed storage capacity: width 256, height 240 |
| `0x1c` | Read/write | GG size: 0 sharp 3× (default), 1 sharp 2×; other values normalize to 0 |
| `0x20` | Write | Nonzero bit 0 requests a cold game restart; setting ID 3 |
| `0x28` | Read | Latest completed active width/height; zero when the frame tracker is invalid |
| `0x2c` | Read/write | Requested System: 0 Auto, 1 GG, 2 SMS; setting ID 6 |
| `0x30` | Read/write | Loader type hint: 0 unknown, 1 GG, 2 SMS; write only after ROM load start and before its first byte |
| `0x38` | Read/write | SMS size: 1 sharp 2× (default), 0 sharp 3× crop; the former 4× value and other values normalize to 1; setting ID 8 |
| `0x3c` | Read/write | SMS TV: 0 Auto (default), 1 PAL, 2 NTSC; setting ID 9. Auto selects PAL only for exact known ROM images and otherwise uses NTSC. Changes restart the machine profile |
| `0x40` | Write/read | Write 1 to open the ten-step on-screen press-to-bind mapper; write 2 to restore default bindings. Read active in bit 4 and current step in bits 3:0. Setting IDs 10 and 12 |
| `0x44` | Read/write | SMS Select: 0 disabled (default), 1 hold for one second to pulse console Reset. Setting ID 11 |
| `0x48` | Read/write | Swap mapped A/B: 0 normal (default), 1 swapped. Setting ID 13 |
| `0x110` | Read | Last host error, or 8 while System Auto has unresolved ROM type |
| `0x118` | Read | Type evidence: selected type bits 1:0, source bits 3:2 (1 override, 2 hint, 3 header), header bits 5:4, header-conflict bit 6 |
| `0x120` | Read | Last completed frame's valid, TV, system, epoch and frame ID (development diagnostic) |
| `0x124` | Read | Profile diagnostic: selected type bits 1:0, active type bits 3:2, ready bit 4, busy bit 5, error bit 6 |

The current Auto TV list recognizes the exact Alien 3 (Europe, Brazil) image
with CRC-32 `B618B144`. The Sega ROM header has an export-region code but no
PAL/NTSC field, so other games use NTSC unless PAL is selected manually.

The ROM and save windows remain `0x30000000` and `0x40000000`. ROM bytes are
committed in order before machine type is applied. `SETUP_COMPLETE` schedules
the profile transaction after initial settings arrive. The engine halts while
the ROM bus drains, applies the selected mode, clears work RAM, and waits for
the clear to finish. Cartridge SRAM and the loaded ROM are retained. `CORE_RUN`
is accepted only after the profile reports ready; the ordinary firmware
status values remain 2 during preparation, 3 when halted and ready, and 4
while running. A machine/region/mapper change or the restart action uses the
same transaction. A size change does not restart the game and is attached to
a completed frame before crossing to the display clock.

System Auto uses the current load's extension hint first, then a consistent
`TMR SEGA` header. It does not guess from ROM size. The optional hint metadata
is ignored by the pinned older firmware; under that firmware a headerless ROM
needs a forced System setting. Unresolved Auto remains halted, with profile
error and code 8 available for diagnostics. The PAL profile selects an
approximately 53.205128 MHz system clock and a 313-line native frame for SMS.
PAL ROMs and the included raster diagnostics have been played on the separate
local PAL trial. The next combined build still requires its own hardware test.
FM synthesis is not offered by this ABI or package yet. SMS 3× displays a
256×160 source viewport and crops eight source columns on each side of
720-pixel HDMI. In 3× crop, the default L and R bindings move the picture up
and down one source pixel, with bounds set by the current native height.

The next alpha's on-screen mapper captures one physical button for each of
Up, Down, Left, Right, A, B, Start/Pause, crop up, crop down and optional SMS
Reset. A short press of any D-pad, A/B/X/Y, L/R, Start or Select button binds
on release. Hold one button for one second to keep the current binding; hold
Start and Select together for one second to exit. The mapper waits for a clean
release after the firmware menu closes so the action-confirm button is not
captured. The crop commands act only in SMS 3x mode, and Reset still requires
the separate Hold 1s Reset setting. The current firmware leaves its core
settings menu open after Map controls is selected; manually exit the menu to
see the prompt ([known issue #9](https://github.com/czarroland/gamegear-bub/issues/9)).
It suspends gameplay controls while visible. Its bindings are
session state and reset at core power-up. The separate Swap A/B menu setting
is stored by the firmware. SMS Start is debounced before reaching Pause, and
Select has no reset action unless the one-second option is explicitly chosen;
that command follows the Reset binding when enabled.

The firmware's dependent `.sav` path replaces the ROM extension. GG and SMS
files with the same basename in the same directory therefore share a save
path: keep them in separate directories and back up saves before testing.
