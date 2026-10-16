#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Generate original SMS ROMs selecting the native 224/240-line VDP modes."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
target = ROOT / "diagnostics"
target.mkdir(exist_ok=True)
for height, register_one in ((224, 0x50), (240, 0x48)):
    rom = bytearray([0xff]) * 32768
    # DI; LD SP,$DFF0. Register 0 bit 1 enables M2 and bit 2 enables M4.
    code = bytes.fromhex("f3 31 f0 df 3e 06 d3 bf 3e 80 d3 bf")
    # Register 1 bit 4 selects 224 lines; bit 3 selects 240 lines.
    code += bytes((0x3e, register_one, 0xd3, 0xbf, 0x3e, 0x81, 0xd3, 0xbf))
    code += bytes.fromhex("c3 14 00")  # Idle after initializing the VDP.
    rom[:len(code)] = code
    rom[0x7ff0:0x7ff8] = b"TMR SEGA"
    rom[0x7fff] = 0x4c
    (target / f"sms-raster-{height}.hex").write_text("".join(f"{value:02x}\n" for value in rom))
    print(f"Built original SMS {height}-line raster diagnostic")
