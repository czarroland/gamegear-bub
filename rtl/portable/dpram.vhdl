-- SPDX-License-Identifier: GPL-3.0-or-later
-- Two-read, one-write common-clock memory used by the GG VDP and save memory.
-- Host save imports are multiplexed onto port A while the engine is frozen.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity dpram is
  generic(init_file:string:=" "; widthad_a:natural; width_a:natural:=8;
          mixed_port_rdwr:string:="DONT_CARE";
          outdata_reg_a:string:="UNREGISTERED"; outdata_reg_b:string:="UNREGISTERED");
  port(address_a,address_b:in std_logic_vector(widthad_a-1 downto 0);
       clock_a,clock_b:in std_logic; data_a,data_b:in std_logic_vector(width_a-1 downto 0);
       wren_a,wren_b:in std_logic:='1'; q_a,q_b:out std_logic_vector(width_a-1 downto 0));
end;
architecture portable of dpram is
  type ram_t is array(0 to 2**widthad_a-1) of std_logic_vector(width_a-1 downto 0);
  function initial_ram return ram_t is variable r:ram_t:=(others=>(others=>'0'));
  begin
    if init_file="ff" then r:=(others=>(others=>'1'));
    else assert init_file=" " or init_file="none" or init_file="" report "dpram: unsupported initialization asset" severity failure;
    end if;
    return r;
  end function;
  signal ram:ram_t:=initial_ram;
  signal a0,a1,b0,b1:std_logic_vector(width_a-1 downto 0):=(others=>'0');
begin
  process(clock_a) begin
    if rising_edge(clock_a) then
      assert clock_b='1' report "dpram requires a common clock" severity failure;
      a0<=ram(to_integer(unsigned(address_a)));
      if wren_a='1' then ram(to_integer(unsigned(address_a)))<=data_a; a0<=data_a; end if;
      a1<=a0;
    end if;
  end process;
  process(clock_b) begin
    if rising_edge(clock_b) then
      assert wren_b='0' report "dpram port B is read-only" severity failure;
      b0<=ram(to_integer(unsigned(address_b)));
      b1<=b0;
    end if;
  end process;
  q_a<=a0 when outdata_reg_a="UNREGISTERED" else a1;
  q_b<=b0 when outdata_reg_b="UNREGISTERED" else b1;
end;
