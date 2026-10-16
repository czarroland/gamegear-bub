# Sega 8-bit development core ABI (SEG2)

This describes the unified GG/SMS NTSC development bitstream. The public
Game Gear alpha.3 package retains its earlier `GGB1` ABI and core ID.

| Offset | Access | Meaning |
| --- | --- | --- |
| `0x00` | Read | `0x53454732` (`SEG2`) |
| `0x04` | Read | `0x00020000` ABI version |
| `0x08` | Read | Capability bits: 0 GG, 1 stereo, 2 cartridge SRAM, 3 diagnostics, 4 SMS NTSC |
| `0x0c` | Read | Active machine: 0 none, 1 GG, 2 SMS |
| `0x10` / `0x14` | Read/write | Region and mapper, retained setting IDs 1 and 2 |
| `0x18` | Read | Fixed storage capacity: width 256, height 240 |
| `0x1c` | Read/write | GG size: 0 sharp 3× (default), 1 sharp 2×; other values normalize to 0 |
| `0x20` | Write | Nonzero bit 0 requests a cold game restart; setting ID 3 |
| `0x28` | Read | Latest completed active width/height; zero when the frame tracker is invalid |
| `0x2c` | Read/write | Requested System: 0 Auto, 1 GG, 2 SMS; setting ID 6 |
| `0x30` | Read/write | Loader type hint: 0 unknown, 1 GG, 2 SMS; write only after ROM load start and before its first byte |
| `0x38` | Read/write | SMS size: 1 sharp 2× (default), 0 sharp 3× crop; other values normalize to 1; setting ID 8 |
| `0x110` | Read | Last host error, or 8 while System Auto has unresolved ROM type |
| `0x118` | Read | Type evidence: selected type bits 1:0, source bits 3:2 (1 override, 2 hint, 3 header), header bits 5:4, header-conflict bit 6 |
| `0x120` | Read | Last completed frame's valid, TV, system, epoch and frame ID (development diagnostic) |
| `0x124` | Read | Profile diagnostic: selected type bits 1:0, active type bits 3:2, ready bit 4, busy bit 5, error bit 6 |

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
error and code 8 available for diagnostics. The current image has **SMS NTSC
only**. PAL clock selection and FM synthesis are not offered by this ABI or
package yet. SMS 3× intentionally crops the top and bottom on the LCD and
also crops eight source columns on each side of 720-pixel HDMI output.

The firmware's dependent `.sav` path replaces the ROM extension. GG and SMS
files with the same basename in the same directory therefore share a save
path: keep them in separate directories and back up saves before testing.
