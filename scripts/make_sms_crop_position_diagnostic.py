#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build an original SMS ROM whose colored bands identify the 3x crop origin."""
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
code = bytearray()


def emit(*values):
    code.extend(values)


def out(port, value):
    emit(0x3E, value, 0xD3, port)  # LD A,value; OUT (port),A.


def vdp_address(address, command=0x40):
    out(0xBF, address & 0xFF)
    out(0xBF, (address >> 8) | command)


def vdp_register(register, value):
    out(0xBF, value)
    out(0xBF, 0x80 | register)


emit(0xF3, 0x31, 0xF0, 0xDF)  # DI; LD SP,$DFF0.
for register, value in enumerate((0x04, 0x00, 0x0E, 0xFF, 0xFF, 0x7E, 0, 0, 0, 0, 0xFF)):
    vdp_register(register, value)

# Palette indices 0-5: black, red, magenta, green, yellow, blue.
vdp_address(0, 0xC0)
for value in (0x00, 0x03, 0x33, 0x0C, 0x0F, 0x30) + (0x00,) * 26:
    out(0xBE, value)

# One-pixel row zero is red. Rows 1-15 are magenta, 16-31 green,
# 32-47 yellow, and the remaining active rows blue.
vdp_address(0)
for tile in range(5):
    for row in range(8):
        palette_index = (1 if row == 0 else 2) if tile == 0 else (2, 3, 4, 5)[tile - 1]
        for plane in range(4):
            out(0xBE, 0xFF if palette_index & (1 << plane) else 0)

vdp_address(0x3800)
for tile_row in range(28):
    tile = 0 if tile_row == 0 else 1 if tile_row == 1 else \
        2 if tile_row < 4 else 3 if tile_row < 6 else 4
    for _ in range(32):
        out(0xBE, tile)
        out(0xBE, 0)
vdp_address(0x3F00)
out(0xBE, 0xD0)  # No sprites.
vdp_register(1, 0x40)  # Display on.
idle = len(code)
emit(0xC3, idle & 0xFF, idle >> 8)

rom = bytearray([0xFF]) * 32768
assert len(code) < 0x7FF0
rom[: len(code)] = code
rom[0x7FF0:0x7FF8] = b"TMR SEGA"
rom[0x7FFF] = 0x4C  # Export SMS, 32 KiB.
target = ROOT / "diagnostics"
target.mkdir(exist_ok=True)
(target / "sms-crop-position-diagnostic.sms").write_bytes(rom)
(target / "sms-crop-position-diagnostic.hex").write_text(
    "".join(f"{value:02x}\n" for value in rom)
)
print(f"Built original SMS crop-position diagnostic ({len(code)} program bytes)")
