`timescale 1ns/1ps
module tb_sdram;
    reg clk=0; always #10 clk=~clk;
    reg reset=1,request=0,write=0;
    reg [24:0] address=0;
    reg [7:0] data_write=0;
    wire ready,done,initialized,cke,cs,ras,cas,we,data_dir;
    wire [1:0] dqm,bank;
    wire [12:0] sa;
    wire [15:0] data_in,data_out;
    wire [7:0] data_read;
    wire [31:0] refreshes;
    gg_sdram #(.INIT_CYCLES(20)) dut(clk,reset,request,write,address,data_write,
        ready,done,data_read,initialized,cke,cs,ras,cas,we,dqm,bank,sa,data_in,data_out,data_dir);
    sdram_model model(~clk,cke,cs,ras,cas,we,bank,dqm,sa,data_out,data_dir,data_in,refreshes);
    task access(input wr,input [24:0] a,input [7:0] value);
        integer timeout;
        begin
            @(negedge clk); request=1; write=wr; address=a; data_write=value; timeout=0;
            while(!ready) begin @(negedge clk); timeout=timeout+1; if(timeout>100) $fatal(1,"SDRAM ready timeout"); end
            @(negedge clk); request=0;
            timeout=0;
            while(!done) begin @(negedge clk); timeout=timeout+1; if(timeout>100) $fatal(1,"SDRAM transaction timeout"); end
            if(!wr && data_read!==value) $fatal(1,"SDRAM[%h]=%h expected %h",a,data_read,value);
        end
    endtask
    integer i;
    initial begin
        repeat(3) @(negedge clk); reset=0;
        wait(initialized); @(negedge clk);
        // Both byte lanes, column/row boundaries, and all four banks.
        access(1,0,8'h12); access(1,1,8'h34); access(0,0,8'h12); access(0,1,8'h34);
        access(1,1023,8'h56); access(1,1024,8'h78);
        access(0,1023,8'h56); access(0,1024,8'h78);
        for(i=0;i<4;i=i+1) access(1,(i<<23)+32,8'ha0+i);
        for(i=0;i<4;i=i+1) access(0,(i<<23)+32,8'ha0+i);
        repeat(3000) @(negedge clk);
        if(refreshes<15) $fatal(1,"No idle refresh");
        $display("PASS SDRAM protocol: initialization, byte masks, rows, banks, CAS latency, idle refresh (%0d)",refreshes);
        $finish;
    end
    initial begin #1000000; $fatal(1,"SDRAM test timeout"); end
endmodule
