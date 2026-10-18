#!/usr/bin/env python3
"""Source staging must leave upstream comments and VHDL literals intact."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from prepare_sources import rename_vhdl_identifiers, patch_video


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

    def test_pal_240_counter_patch(self):
        source = (Path(__file__).resolve().parents[1] /
                  'vendor/sms_mister/rtl/video.vhd').read_text()
        patched = patch_video(source)
        self.assertEqual(patched.count('conv_std_logic_vector(466, 9)'), 2)
        self.assertEqual(patched.count('conv_std_logic_vector(466,9)'), 2)
        self.assertIn('elsif vcount = 466 then', patched)
        self.assertIn('elsif vcount = 469 then', patched)


if __name__ == '__main__':
    unittest.main()
