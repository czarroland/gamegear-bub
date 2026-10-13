library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
entity tb_memory is end;
architecture test of tb_memory is
  signal clk:std_logic:='0';
  signal a,b:std_logic_vector(3 downto 0):=(others=>'0');
  signal da,db,qa,qb,qa_reg,qb_reg:std_logic_vector(7 downto 0):=(others=>'0');
  signal wa,wb:std_logic:='0';
begin
  clk<=not clk after 10 ns;
  dut:entity work.dpram generic map(widthad_a=>4,init_file=>"ff")
    port map(a,b,clk,clk,da,db,wa,wb,qa,qb);
  pipelined:entity work.dpram generic map(widthad_a=>4,init_file=>"ff",outdata_reg_a=>"CLOCK0",outdata_reg_b=>"CLOCK1")
    port map(a,b,clk,clk,da,db,wa,wb,qa_reg,qb_reg);
  process
    procedure tick is begin wait until rising_edge(clk);wait for 1 ns;end;
  begin
    tick;
    assert qa=x"ff" and qb=x"ff" report "RAM initialization/read latency" severity failure;
    a<=x"3";b<=x"3";da<=x"5a";wa<='1';tick;
    assert qa=x"5a" and qb=x"ff" report "Own-port forwarding/cross-port old data" severity failure;
    wa<='0';tick;
    assert qa=x"5a" and qb=x"5a" and qa_reg=x"5a" and qb_reg=x"ff" report "Registered output latency" severity failure;
    tick;
    assert qb_reg=x"5a" report "Second read pipeline cycle" severity failure;
    a<=x"4";b<=x"4";da<=x"12";wa<='1';tick;
    assert qa=x"12" and qb=x"ff" report "Port A write and port B old-data read" severity failure;
    wa<='0';tick;
    assert qa=x"12" and qb=x"12" report "Port B read after port A write" severity failure;
    a<=x"5";b<=x"4";da<=x"34";wa<='1';tick;
    assert qa=x"34" and qb=x"12" report "Independent read and write addresses" severity failure;
    wa<='0';a<=x"4";b<=x"5";tick;
    assert qa=x"12" and qb=x"34" report "Two-read, one-write storage" severity failure;
    report "PASS portable memory: initialization, read latency, forwarding, cross-port old data, and two reads with one write";
    stop;
    wait;
  end process;
end;
