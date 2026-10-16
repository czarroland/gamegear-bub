#!/usr/bin/env python3
"""Source staging must leave upstream comments and VHDL literals intact."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from prepare_sources import rename_vhdl_identifiers


class RenameVhdlIdentifiersTest(unittest.TestCase):
    def test_code_only(self):
        source = (
            'signal DO, Reg, priority : std_logic; -- Do not change Reg priority\n'
            'report "DO -- Reg priority";\n'
            'DO <= Reg and priority;\n'
        )
        expected = (
            'signal z80_dout, z80_registers, bg_priority : std_logic; -- Do not change Reg priority\n'
            'report "DO -- Reg priority";\n'
            'z80_dout <= z80_registers and bg_priority;\n'
        )
        self.assertEqual(rename_vhdl_identifiers(source), expected)


if __name__ == '__main__':
    unittest.main()
