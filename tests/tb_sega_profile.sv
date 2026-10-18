`timescale 1ns/1ps
module tb_sega_profile;
    reg clk=0; always #10 clk=~clk;
    reg reset=1,load_start=0,load_end=0,reconfigure=0;
    reg setup_complete=0,rom_ready=0,memory_idle=1,save_busy=0,wram_busy=0;
    reg [1:0] selected_type=0;
    wire [1:0] active_type;
    wire ready,busy,error,clear_wram;
    sega_profile dut(.*);
    integer resets=0,i;
    always @(posedge clk) if(clear_wram) resets<=resets+1;
    initial begin
        repeat(3) @(negedge clk); reset=0;
        setup_complete=1;
        load_start=1; @(negedge clk); load_start=0;
        if(ready || active_type!=0) $fatal(1,"Old profile survived load start");
        selected_type=2; rom_ready=1; memory_idle=0; load_end=1;
        @(negedge clk); load_end=0;
        repeat(5) @(negedge clk);
        if(!busy || ready || active_type!=0 || resets!=0)
            $fatal(1,"SMS profile applied before ROM bus drained");
        memory_idle=1; save_busy=1;
        repeat(5) @(negedge clk);
        if(active_type!=0 || resets!=0) $fatal(1,"SMS profile applied during save transfer");
        save_busy=0;
        @(negedge clk);
        if(active_type!=2 || ready || !clear_wram)
            $fatal(1,"SMS profile did not enter cold restart");
        wram_busy=1;
        repeat(40) @(negedge clk);
        if(ready || resets!=1) $fatal(1,"Profile resumed before WRAM clear completed");
        wram_busy=0;
        @(negedge clk);
        if(!ready || active_type!=2 || error) $fatal(1,"SMS profile did not become ready");

        selected_type=1; memory_idle=0; reconfigure=1;
        @(negedge clk); reconfigure=0;
        if(ready || active_type!=2) $fatal(1,"GG override switched live before drain");
        repeat(4) @(negedge clk);
        if(active_type!=2) $fatal(1,"GG override changed mode with ROM bus active");
        memory_idle=1;
        @(negedge clk);
        if(active_type!=1 || ready || !clear_wram)
            $fatal(1,"GG override did not cold restart after drain");
        repeat(34) @(negedge clk);
        if(!ready || resets!=2) $fatal(1,"GG override did not complete");

        selected_type=0; reconfigure=1;
        @(negedge clk); reconfigure=0;
        repeat(3) @(negedge clk);
        if(!error || ready || active_type!=1 || resets!=2)
            $fatal(1,"Unresolved Auto did not halt without changing profile");
        selected_type=2; reconfigure=1;
        @(negedge clk); reconfigure=0;
        repeat(35) @(negedge clk);
        if(!ready || active_type!=2 || error || resets!=3)
            $fatal(1,"Explicit SMS override did not recover unresolved Auto");

        load_start=1; rom_ready=0;
        @(negedge clk); load_start=0;
        if(ready || active_type!=0) $fatal(1,"New ROM retained the previous active profile");
        $display("PASS profile: drained GG/SMS switches, WRAM wait, unresolved Auto, override recovery, load epoch");
        $finish;
    end
    initial begin #100000; $fatal(1,"Profile test timed out"); end
endmodule
