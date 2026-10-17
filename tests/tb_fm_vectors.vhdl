-- SPDX-License-Identifier: GPL-3.0-or-later
-- Original deterministic bus stimuli for a locally staged VM2413 reference.
-- SCENARIO 1: preset instruments, key on/off.
-- SCENARIO 2: user instrument, all melodic channels, key release and reset.
-- SCENARIO 3: rhythm entry, simultaneous percussion, partial release, exit.
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity tb_fm_vectors is
    generic (SCENARIO : integer := 1);
end entity;

architecture sim of tb_fm_vectors is
    signal xin : std_logic := '0';
    signal d : std_logic_vector(7 downto 0) := (others => '0');
    signal a : std_logic := '0';
    signal cs_n : std_logic := '1';
    signal we_n : std_logic := '1';
    signal ic_n : std_logic := '0';
    signal mixout : std_logic_vector(13 downto 0);

    procedure write_reg(
        signal clk : in std_logic;
        signal data_bus : out std_logic_vector(7 downto 0);
        signal addr_bit : out std_logic;
        signal cs : out std_logic;
        signal wr : out std_logic;
        constant reg_addr : in integer;
        constant reg_data : in integer
    ) is
    begin
        wait until falling_edge(clk);
        data_bus <= conv_std_logic_vector(reg_addr, 8);
        addr_bit <= '0';
        cs <= '0';
        wr <= '0';
        wait until falling_edge(clk);
        cs <= '1';
        wr <= '1';
        wait until falling_edge(clk);
        data_bus <= conv_std_logic_vector(reg_data, 8);
        addr_bit <= '1';
        cs <= '0';
        wr <= '0';
        -- Two complete 72-enable OPLL frames between register pairs.
        for i in 0 to 143 loop
            wait until rising_edge(clk);
        end loop;
    end procedure;

    procedure capture(
        signal clk : in std_logic;
        signal output_sample : in std_logic_vector(13 downto 0);
        constant scenario_number : in integer;
        constant phase_number : in integer;
        constant sample_count : in integer
    ) is
    begin
        for cycle in 0 to sample_count * 72 - 1 loop
            wait until rising_edge(clk);
            if cycle mod 72 = 0 then
                report "vector " & integer'image(scenario_number) & " " &
                    integer'image(phase_number) & " " & integer'image(cycle) & " " &
                    integer'image(conv_integer(output_sample));
            end if;
        end loop;
    end procedure;
begin
    xin <= not xin after 5 ns;

    dut : entity work.opll
        port map (
            xin => xin, xout => open, xena => '1', d => d, a => a,
            cs_n => cs_n, we_n => we_n, ic_n => ic_n, mixout => mixout
        );

    process
    begin
        assert SCENARIO >= 1 and SCENARIO <= 3
            report "SCENARIO must be 1, 2, or 3" severity failure;
        for i in 0 to 31 loop
            wait until rising_edge(xin);
        end loop;
        wait until falling_edge(xin);
        ic_n <= '1';

        if SCENARIO = 1 then
            for preset in 1 to 15 loop
                write_reg(xin, d, a, cs_n, we_n, 16#30#, preset * 16);
                write_reg(xin, d, a, cs_n, we_n, 16#10#, (16#70# + preset * 5) mod 256);
                write_reg(xin, d, a, cs_n, we_n, 16#20#, 16#15#);
                capture(xin, mixout, SCENARIO, preset * 2, 40);
                write_reg(xin, d, a, cs_n, we_n, 16#20#, 16#05#);
                capture(xin, mixout, SCENARIO, preset * 2 + 1, 24);
            end loop;
        elsif SCENARIO = 2 then
            -- Program the user instrument before assigning it to nine voices.
            write_reg(xin, d, a, cs_n, we_n, 16#00#, 16#31#);
            write_reg(xin, d, a, cs_n, we_n, 16#01#, 16#21#);
            write_reg(xin, d, a, cs_n, we_n, 16#02#, 16#1E#);
            write_reg(xin, d, a, cs_n, we_n, 16#03#, 16#07#);
            write_reg(xin, d, a, cs_n, we_n, 16#04#, 16#F0#);
            write_reg(xin, d, a, cs_n, we_n, 16#05#, 16#F0#);
            write_reg(xin, d, a, cs_n, we_n, 16#06#, 16#0F#);
            write_reg(xin, d, a, cs_n, we_n, 16#07#, 16#0F#);
            for channel in 0 to 8 loop
                write_reg(xin, d, a, cs_n, we_n, 16#30# + channel, channel mod 4);
                write_reg(xin, d, a, cs_n, we_n, 16#10# + channel, 16#60# + channel * 13);
                write_reg(xin, d, a, cs_n, we_n, 16#20# + channel, 16#15#);
            end loop;
            capture(xin, mixout, SCENARIO, 0, 160);
            for channel in 0 to 8 loop
                if channel mod 2 = 0 then
                    write_reg(xin, d, a, cs_n, we_n, 16#20# + channel, 16#05#);
                end if;
            end loop;
            capture(xin, mixout, SCENARIO, 1, 80);
            ic_n <= '0';
            capture(xin, mixout, SCENARIO, 2, 40);
        else
            for channel in 6 to 8 loop
                write_reg(xin, d, a, cs_n, we_n, 16#10# + channel, 16#90# + channel * 3);
                write_reg(xin, d, a, cs_n, we_n, 16#20# + channel, 16#15#);
                write_reg(xin, d, a, cs_n, we_n, 16#30# + channel, 16#11#);
            end loop;
            write_reg(xin, d, a, cs_n, we_n, 16#0E#, 16#20#);
            write_reg(xin, d, a, cs_n, we_n, 16#0E#, 16#3F#);
            capture(xin, mixout, SCENARIO, 0, 160);
            write_reg(xin, d, a, cs_n, we_n, 16#0E#, 16#2A#);
            capture(xin, mixout, SCENARIO, 1, 80);
            write_reg(xin, d, a, cs_n, we_n, 16#0E#, 16#00#);
            capture(xin, mixout, SCENARIO, 2, 40);
        end if;
        report "vector_done " & integer'image(SCENARIO) severity note;
        wait;
    end process;
end architecture;
