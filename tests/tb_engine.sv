`timescale 1ns/1ps
module tb_engine;
    reg clk=0; always #10 clk=~clk;
    reg reset_n=0, clear_wram=0, load_we=0;
    wire ce_cpu,ce_vdp,ce_pix,ce_sp;
    reg [6:0] buttons=0;
    reg [23:0] load_address=0;
    reg [7:0] load_data=0;
    reg [12:0] debug_wram_address=0;
    wire [7:0] debug_wram_q,save_q;
    wire [23:0] rom_address;
    wire rom_read,hblank,vblank,wram_busy;
    wire [11:0] color;
    wire [15:0] audio_left,audio_right;
    wire [229:0] debug_cpu;
    wire [127:0] debug_vdp;
    wire [383:0] debug_cram;
    wire [31:0] debug_io;
    wire [63:0] debug_mapper;
    reg [7:0] rom [0:65535];
    wire [7:0] rom_data=rom[rom_address[15:0]];
    gg_enables enables(clk,1'b0,ce_cpu,ce_vdp,ce_pix,ce_sp);
    gamegear_machine dut(.clk(clk),.reset_n(reset_n),.clear_wram(clear_wram),.freeze(1'b0),
        .machine_sms(1'b0),.tv_pal(1'b0),
        .pause_pressed(buttons[6]),.console_reset(1'b0),
        .ce_cpu(ce_cpu),.ce_vdp(ce_vdp),.ce_pix(ce_pix),.ce_sp(ce_sp),.rom_wait_n(1'b1),
        .buttons(buttons),.region(1'b0),.mapper(4'd1),.load_we(load_we),.load_address(load_address),.load_data(load_data),
        .rom_read(rom_read),.rom_address(rom_address),.rom_data(rom_data),
        .color(color),.hblank(hblank),.vblank(vblank),.audio_left(audio_left),.audio_right(audio_right),
        .save_host_address(15'd0),.save_host_data(8'd0),.save_host_we(1'b0),.save_host_q(save_q),
        .debug_wram_address(debug_wram_address),.debug_wram_q(debug_wram_q),.wram_busy(wram_busy),
        .debug_cpu(debug_cpu),.debug_vdp(debug_vdp),.debug_cram(debug_cram),.debug_io(debug_io),.debug_mapper(debug_mapper));
    integer i,active_pixels=0,red_pixels=0,green_pixels=0,left_changes=0;
    reg [15:0] last_left=0;
    reg checking=0;
    always @(posedge clk) if(checking) begin
        if(ce_pix && !hblank && !vblank) begin
            active_pixels=active_pixels+1;
            if(color==12'h00f) red_pixels=red_pixels+1;
            if(color==12'h0f0) green_pixels=green_pixels+1;
        end
        if(audio_left!==last_left) left_changes=left_changes+1;
        last_left=audio_left;
        if(audio_right!==16'd0) $fatal(1,"Left-only stereo leaked right: %h",audio_right);
    end
    task check_ram(input [12:0] address,input [7:0] expected);
        begin
            @(negedge clk); debug_wram_address=address;
            repeat(3) @(negedge clk);
            if(debug_wram_q!==expected) $fatal(1,"WRAM[%h]=%h expected %h CPU=%h",address,debug_wram_q,expected,debug_cpu);
        end
    endtask
    initial begin
        $readmemh("diagnostics/gamegear-diagnostic.hex",rom);
        repeat(20) @(negedge clk);
        clear_wram=1; @(negedge clk); clear_wram=0;
        for(i=0;i<65536;i=i+1) begin
            load_we=1; load_address=i; load_data=rom[i]; @(negedge clk);
        end
        load_we=0;
        repeat(20) @(negedge clk); reset_n=1;
        repeat(400000) @(negedge clk);
        check_ram(0,8'h47); check_ram(1,8'h47); check_ram(2,8'h33);
        check_ram(3,8'h5a); check_ram(5,8'ha5); check_ram(4,8'hff); check_ram(6,8'hff);
        if(save_q!==8'h5a) $fatal(1,"Save RAM did not receive diagnostic write");
        checking=1;
        repeat(1000000) @(negedge clk);
        checking=0;
        if(red_pixels<1000 || green_pixels<1000) $fatal(1,"Missing GG colors: red=%0d green=%0d total=%0d hb=%b vb=%b m1=%b m2=%b m3=%b m4=%b x=%h y=%h regs=%h",red_pixels,green_pixels,active_pixels,hblank,vblank,dut.m1,dut.m2,dut.m3,dut.m4,dut.x,dut.y,debug_vdp);
        if(left_changes<20) $fatal(1,"PSG tone did not run: %0d changes",left_changes);
        buttons=7'b1100001;
        repeat(10000) @(negedge clk);
        check_ram(4,8'h7f); check_ram(6,8'hde);
        $display("PASS real GG engine: bank switching, WRAM, save RAM, Start, buttons, color crop, stereo PSG (%0d red, %0d green)",red_pixels,green_pixels);
        $finish;
    end
    initial begin #40000000; $fatal(1,"Engine simulation timed out"); end
endmodule
