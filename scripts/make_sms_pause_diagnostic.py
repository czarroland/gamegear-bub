#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build an original SMS ROM that counts native NMI presses in work RAM."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
rom = bytearray([0xff]) * 32768
# DI; LD SP,$DFF0; XOR A; LD ($C000),A. Maskable IRQs stay disabled.
rom[:8] = bytes.fromhex("f3 31 f0 df af 32 00 c0")
# Poll console Reset on port $DD bit 4 into $C001; loop forever.
rom[8:18] = bytes.fromhex("db dd e6 10 32 01 c0 c3 08 00")
# $0066: PUSH AF; INC ($C000) through A; POP AF; RETN.
rom[0x66:0x70] = bytes.fromhex("f5 3a 00 c0 3c 32 00 c0 f1 ed")
rom[0x70] = 0x45
rom[0x7ff0:0x7ff8] = b"TMR SEGA"
rom[0x7fff] = 0x4c  # Export SMS, 32 KiB.
target = ROOT / "diagnostics"
target.mkdir(exist_ok=True)
(target / "sms-pause-diagnostic.sms").write_bytes(rom)
(target / "sms-pause-diagnostic.hex").write_text("".join(f"{value:02x}\n" for value in rom))
print("Built original 32 KiB SMS Pause/Reset diagnostic")
