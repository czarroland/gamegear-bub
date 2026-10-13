-- SPDX-License-Identifier: GPL-3.0-or-later
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity spram is
  generic(init_file:string:="none"; widthad_a:natural; width_a:natural:=8;
          outdata_reg_a:string:="UNREGISTERED");
  port(address:in std_logic_vector(widthad_a-1 downto 0); clock:in std_logic;
       data:in std_logic_vector(width_a-1 downto 0); wren:in std_logic;
       q:out std_logic_vector(width_a-1 downto 0));
end;
architecture portable of spram is
  type ram_t is array(0 to 2**widthad_a-1) of std_logic_vector(width_a-1 downto 0);
  signal ram:ram_t:=(others=>(others=>'0'));
  signal first_q,second_q:std_logic_vector(width_a-1 downto 0):=(others=>'0');
begin
  assert init_file="none" or init_file="" or init_file=" "
    report "spram: unsupported initialization asset" severity failure;
  process(clock) begin
    if rising_edge(clock) then
      first_q<=ram(to_integer(unsigned(address)));
      if wren='1' then
        ram(to_integer(unsigned(address)))<=data; first_q<=data;
      end if;
      second_q<=first_q;
    end if;
  end process;
  q<=first_q when outdata_reg_a="UNREGISTERED" else second_q;
end;
