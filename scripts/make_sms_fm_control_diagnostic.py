#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build an original SMS ROM exercising YM2413 control-port readback."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
rom = bytearray([0xff]) * 32768
code = bytearray(bytes.fromhex("f3 31 f0 df"))  # DI; LD SP,$DFF0
for value in range(8):
    # LD A,value; OUT ($F2),A; IN A,($F2); LD ($C000+value),A
    code += bytes((0x3e, value, 0xd3, 0xf2, 0xdb, 0xf2,
                   0x32, value, 0xc0))
# Key on one preset tone through the SMS $F0/$F1 bus ports. The ordinary
# control regression checks only CPU/port behavior; the private VM2413 probe
# additionally checks for changing mixed audio from this ROM.
for address, value in ((0x30, 0x10), (0x10, 0xaa), (0x20, 0x15)):
    code += bytes((0x3e, address, 0xd3, 0xf0))
    # The upstream OPLL samples each address/data phase only once per chip
    # frame. Hold both phases long enough to cross two complete frames.
    code += bytes((0x06, 80, 0x10, 0xfe))  # LD B,80; DJNZ self
    code += bytes((0x3e, value, 0xd3, 0xf1))
    code += bytes((0x06, 80, 0x10, 0xfe))
code += bytes((0x3e, 0xa5, 0x32, 0x08, 0xc0))  # Completion marker.
loop = len(code)
code += bytes((0xc3, loop & 0xff, loop >> 8))
rom[:len(code)] = code
rom[0x7ff0:0x7ff8] = b"TMR SEGA"
rom[0x7fff] = 0x4c
target = ROOT / "diagnostics"
target.mkdir(exist_ok=True)
(target / "sms-fm-control.sms").write_bytes(rom)
(target / "sms-fm-control.hex").write_text("".join(f"{value:02x}\n" for value in rom))
print("Built original SMS FM control-port diagnostic")
