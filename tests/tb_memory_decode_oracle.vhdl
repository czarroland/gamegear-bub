-- SPDX-License-Identifier: GPL-3.0-or-later
-- Compare the pinned, pristine MiSTer decoder with the staged Gamebub copy.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library upstream;

entity tb_memory_decode_oracle is end entity;

architecture test of tb_memory_decode_oracle is
  signal gg, mapper_evolution, gg_bios_en, bios_en, ext_bios_sel : std_logic := '0';
  signal ext_bios_loaded, ext_gg_bios_loaded, mapper_dahjee_a : std_logic := '0';
  signal use_zem, mapper_4pak, mapper_codies, systeme, sc3000_en : std_logic := '0';
  signal sc_multicart_en, mapper_linear, mapper_janggun : std_logic := '0';
  signal dbr, bootloader_n : std_logic := '1';
  signal A : std_logic_vector(15 downto 0) := (others => '0');
  signal media_control : std_logic_vector(7 downto 5) := (others => '0');
  signal bank0 : std_logic_vector(7 downto 0) := x"00";
  signal bank1 : std_logic_vector(7 downto 0) := x"01";
  signal bank2 : std_logic_vector(7 downto 0) := x"02";
  signal bank3 : std_logic_vector(7 downto 0) := x"03";
  signal nem_bank0 : std_logic_vector(7 downto 0) := (others => '0');
  signal rom_bank : std_logic_vector(3 downto 0) := (others => '0');
  signal sc_multicart_page : std_logic_vector(6 downto 0) := (others => '0');
  signal jang_bank1, jang_bank2, jang_bank3, jang_bank4 : std_logic_vector(5 downto 0) := (others => '0');
  signal reference_precedence, reference_selected, reference_dahjee : std_logic;
  signal staged_precedence, staged_selected, staged_dahjee : std_logic;
  signal reference_address, staged_address : std_logic_vector(21 downto 0);
begin
  reference : entity upstream.memory_decode
    port map (
      gg => gg, mapper_evolution => mapper_evolution, gg_bios_en => gg_bios_en,
      bios_en => bios_en, ext_bios_sel => ext_bios_sel,
      ext_bios_loaded => ext_bios_loaded, dbr => dbr,
      bootloader_n => bootloader_n, ext_gg_bios_loaded => ext_gg_bios_loaded,
      mapper_dahjee_a => mapper_dahjee_a, use_zem => use_zem,
      mapper_4pak => mapper_4pak, mapper_codies => mapper_codies,
      systeme => systeme, sc3000_en => sc3000_en,
      sc_multicart_en => sc_multicart_en, mapper_linear => mapper_linear,
      mapper_janggun => mapper_janggun, A => A,
      media_control => media_control, bank0 => bank0, bank1 => bank1,
      bank2 => bank2, bank3 => bank3, nem_bank0 => nem_bank0,
      rom_bank => rom_bank, sc_multicart_page => sc_multicart_page,
      jang_bank1 => jang_bank1, jang_bank2 => jang_bank2,
      jang_bank3 => jang_bank3, jang_bank4 => jang_bank4,
      cart_precedence_out => reference_precedence,
      cart_memory_selected_out => reference_selected,
      dahjee_cart_access_out => reference_dahjee,
      rom_a_i_out => reference_address);

  staged : entity work.memory_decode
    port map (
      gg => gg, mapper_evolution => mapper_evolution, gg_bios_en => gg_bios_en,
      bios_en => bios_en, ext_bios_sel => ext_bios_sel,
      ext_bios_loaded => ext_bios_loaded, dbr => dbr,
      bootloader_n => bootloader_n, ext_gg_bios_loaded => ext_gg_bios_loaded,
      mapper_dahjee_a => mapper_dahjee_a, use_zem => use_zem,
      mapper_4pak => mapper_4pak, mapper_codies => mapper_codies,
      systeme => systeme, sc3000_en => sc3000_en,
      sc_multicart_en => sc_multicart_en, mapper_linear => mapper_linear,
      mapper_janggun => mapper_janggun, A => A,
      media_control => media_control, bank0 => bank0, bank1 => bank1,
      bank2 => bank2, bank3 => bank3, nem_bank0 => nem_bank0,
      rom_bank => rom_bank, sc_multicart_page => sc_multicart_page,
      jang_bank1 => jang_bank1, jang_bank2 => jang_bank2,
      jang_bank3 => jang_bank3, jang_bank4 => jang_bank4,
      cart_precedence_out => staged_precedence,
      cart_memory_selected_out => staged_selected,
      dahjee_cart_access_out => staged_dahjee,
      rom_a_i_out => staged_address);

  stimulus : process
    procedure compare(constant label_text : string) is
    begin
      wait for 1 ns;
      assert reference_precedence = staged_precedence
        report label_text & ": cartridge precedence differs" severity failure;
      assert reference_selected = staged_selected
        report label_text & ": cartridge selection differs" severity failure;
      assert reference_dahjee = staged_dahjee
        report label_text & ": DahJee access differs" severity failure;
      assert reference_address = staged_address
        report label_text & ": physical ROM address differs" severity failure;
    end procedure;
  begin
    A <= x"8000";
    compare("SMS power-on");
    assert reference_selected = '1' report "SMS cartridge absent at power-on" severity failure;
    assert reference_address = std_logic_vector(to_unsigned(2 * 16384, 22))
      report "SMS bank 2 address incorrect" severity failure;

    -- $3E can disable/re-enable a cartridge without a BIOS. This is the
    -- October upstream fix; it must survive source staging unchanged.
    media_control <= "010";
    compare("SMS $3E cartridge disable without BIOS");
    assert reference_selected = '0' report "SMS cartridge did not disable" severity failure;
    media_control <= "000";
    compare("SMS $3E cartridge re-enable without BIOS");
    assert reference_selected = '1' report "SMS cartridge did not re-enable" severity failure;

    -- The same $3E bit is not a Game Gear cartridge switch.
    gg <= '1'; media_control <= "010";
    compare("GG $3E control");
    assert reference_selected = '1' report "GG cartridge unexpectedly disabled" severity failure;
    gg <= '0'; mapper_evolution <= '1';
    compare("Evolution cartridge policy");
    assert reference_selected = '1' report "Evolution selection changed" severity failure;
    mapper_evolution <= '0'; media_control <= "000";

    dbr <= '0';
    compare("disabled ROM bus");
    assert reference_selected = '0' report "disabled ROM bus selected cartridge" severity failure;
    dbr <= '1';

    -- Exercise all 16 KiB banks, both machine modes, and the $3E state.
    for mode_index in 0 to 1 loop
      if mode_index = 0 then gg <= '0'; else gg <= '1'; end if;
      for page_index in 0 to 255 loop
        A <= std_logic_vector(to_unsigned(page_index * 257, 16));
        bank0 <= std_logic_vector(to_unsigned(page_index, 8));
        bank1 <= std_logic_vector(to_unsigned((page_index + 1) mod 256, 8));
        bank2 <= std_logic_vector(to_unsigned((page_index + 2) mod 256, 8));
        if page_index mod 2 = 0 then media_control <= "000";
        else media_control <= "010"; end if;
        compare("bank/selection sweep");
      end loop;
    end loop;
    report "PASS native upstream versus staged memory decode: SMS $3E, GG, bank address" severity note;
    wait;
  end process;
end architecture;
