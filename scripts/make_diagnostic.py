#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build an original, freely distributable GG diagnostic without an assembler."""
from pathlib import Path
import zlib
ROOT = Path(__file__).resolve().parents[1]
code = bytearray()
labels={};branches=[]
def emit(*values): code.extend(values)
def lda(value): emit(0x3e, value)
def out(port, value): lda(value); emit(0xd3, port)
def store(address): emit(0x32, address & 255, address >> 8)
def write(address, value): lda(value); store(address)
def vdp_address(address, mode=0x40):
    out(0xbf, address & 255); out(0xbf, (address >> 8) | mode)
def label(name):labels[name]=len(code)
def jr(opcode,name):emit(opcode,0);branches.append((len(code)-1,name))
emit(0xf3, 0x31, 0xf0, 0xdf)  # DI; LD SP,$DFF0
write(0xc000, 0x47); write(0xc001, 0x47)
# Exercise bank 3 through the standard Sega mapper.
write(0xffff, 3); emit(0x3a, 0x00, 0x80); store(0xc002)
write(0xffff, 2)
# Exercise cartridge RAM, then leave it mapped out.
write(0xfffc, 8); write(0x8000, 0x5a)
emit(0x3a, 0x00, 0x80); store(0xc003); write(0xfffc, 0)
# Mode 4, display enabled, name table $3800, sprites $3F00.
for register, value in enumerate([4, 0x40, 0x0e, 0xff, 0xff, 0x7e, 0, 0, 0, 0, 0xff]):
    out(0xbf, value); out(0xbf, 0x80 | register)
vdp_address(0x3f00); out(0xbe, 0xd0)  # Sprite terminator.
vdp_address(0, 0xc0)
for value in [0, 0, 0x0f, 0, 0xf0, 0, 0, 0x0f]: out(0xbe, value)
vdp_address(0)
for value in [0x0f, 0xf0, 0, 0] * 8: out(0xbe, value)
# Left-only PSG tone; the idle right channel must remain silent.
for value in [0x85, 0x08, 0x90, 0xbf, 0xdf, 0xff]: out(0x7f, value)
out(0x06, 0x10)
write(0xc005, 0xa5)  # Initialization completed.
loop = len(code)
emit(0xdb, 0x00); store(0xc004)  # GG Start lives in port 0, bit 7.
emit(0xe6,0x80);jr(0x20,'start_released')
vdp_address(4,0xc0);out(0xbe,0);out(0xbe,0x0f);jr(0x18,'after_start')
label('start_released');vdp_address(4,0xc0);out(0xbe,0xf0);out(0xbe,0)
label('after_start')
emit(0xdb, 0xdc); store(0xc006)  # Directions and fire buttons.
emit(0xe6,0x30,0xfe,0x30);jr(0x28,'fire_released')
vdp_address(2,0xc0);out(0xbe,0);out(0xbe,0x0f);jr(0x18,'after_fire')
label('fire_released');vdp_address(2,0xc0);out(0xbe,0x0f);out(0xbe,0)
label('after_fire')
emit(0xc3, loop & 255, loop >> 8)
for position,name in branches:
    displacement=labels[name]-(position+1)
    assert -128<=displacement<=127
    code[position]=displacement&255
rom = bytearray([0xff]) * 65536
rom[:len(code)] = code
rom[0x4000], rom[0x8000], rom[0xc000] = 0x11, 0x22, 0x33
rom[0x7ff0:0x7ff8] = b'TMR SEGA'
rom[0x7fff] = 0x6e  # Export GG, 64 KiB.
target = ROOT / 'diagnostics'
target.mkdir(exist_ok=True)
(target / 'gamegear-diagnostic.gg').write_bytes(rom)
(target / 'gamegear-diagnostic.hex').write_text(''.join(f'{b:02x}\n' for b in rom))
(target / 'diagnostic_crc.vh').write_text(f"localparam [31:0] DIAGNOSTIC_CRC=32'h{zlib.crc32(rom):08x};\n")
print(f'Built original {len(rom)}-byte GG diagnostic ({len(code)} program bytes)')
