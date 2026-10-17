-- SPDX-License-Identifier: GPL-3.0-or-later
-- Original test stimulus for the locally fetched, pinned MiSTer VM2413 source.
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity tb_fm_oracle is
end entity;

architecture sim of tb_fm_oracle is
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
        for i in 0 to 143 loop
            wait until rising_edge(clk);
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
        for i in 0 to 31 loop
            wait until rising_edge(xin);
        end loop;
        wait until falling_edge(xin);
        ic_n <= '1';
        write_reg(xin, d, a, cs_n, we_n, 16#30#, 16#10#);
        write_reg(xin, d, a, cs_n, we_n, 16#10#, 16#AA#);
        write_reg(xin, d, a, cs_n, we_n, 16#20#, 16#15#);
        for i in 0 to 9999 loop
            wait until rising_edge(xin);
            if i mod 72 = 0 and i >= 1000 then
                report "sample " & integer'image(i) & " " & integer'image(conv_integer(mixout));
            end if;
        end loop;
        report "done" severity note;
        wait;
    end process;
end architecture;
