#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build an original SMS ROM with a red native row zero and blue rows 1-191."""
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
code = bytearray()


def emit(*values):
    code.extend(values)


def out(port, value):
    emit(0x3E, value, 0xD3, port)  # LD A,value; OUT (port),A


def vdp_address(address, command=0x40):
    out(0xBF, address & 0xFF)
    out(0xBF, (address >> 8) | command)


def vdp_register(register, value):
    out(0xBF, value)
    out(0xBF, 0x80 | register)


emit(0xF3, 0x31, 0xF0, 0xDF)  # DI; LD SP,$DFF0.
# Mode 4, 192 lines, name table at $3800, sprites at $3F00.
for register, value in enumerate((0x04, 0x00, 0x0E, 0xFF, 0xFF, 0x7E, 0, 0, 0, 0, 0xFF)):
    vdp_register(register, value)

# SMS CRAM entries: black, red, blue. Each channel has two bits.
vdp_address(0, 0xC0)
for value in (0x00, 0x03, 0x30) + (0x00,) * 29:
    out(0xBE, value)

# Tile 0 has a red first scanline and seven blue scanlines. Tile 1 is blue
# throughout. Only the first name-table row uses tile 0.
vdp_address(0)
for row in range(8):
    for value in ((0xFF, 0, 0, 0) if row == 0 else (0, 0xFF, 0, 0)):
        out(0xBE, value)
for _ in range(8):
    for value in (0, 0xFF, 0, 0):
        out(0xBE, value)

vdp_address(0x3800)
for row in range(28):
    for _ in range(32):
        out(0xBE, 0 if row == 0 else 1)
        out(0xBE, 0)
vdp_address(0x3F00)
out(0xBE, 0xD0)  # No sprites.
vdp_register(1, 0x40)  # Display on.
idle = len(code)
emit(0xC3, idle & 0xFF, idle >> 8)  # JP idle.

rom = bytearray([0xFF]) * 32768
assert len(code) < 0x7FF0
rom[: len(code)] = code
rom[0x7FF0:0x7FF8] = b"TMR SEGA"
rom[0x7FFF] = 0x4C  # Export SMS, 32 KiB.
target = ROOT / "diagnostics"
target.mkdir(exist_ok=True)
(target / "sms-top-row-diagnostic.sms").write_bytes(rom)
(target / "sms-top-row-diagnostic.hex").write_text(
    "".join(f"{value:02x}\n" for value in rom)
)
print(f"Built original SMS top-row diagnostic ({len(code)} program bytes)")
