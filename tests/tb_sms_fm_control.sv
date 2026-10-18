`timescale 1ns/1ps
module tb_sms_fm_control;
    parameter integer EXPECT_FM_SOUND=0;
    reg clk=0; always #10 clk=~clk;
    reg reset_n=0,clear_wram=0;
    wire ce_cpu,ce_vdp,ce_pix,ce_sp,rom_read,hblank,vblank,wram_busy;
    reg [12:0] debug_wram_address=0;
    wire [7:0] debug_wram_q,save_q;
    wire [23:0] rom_address;
    wire [11:0] color;
    wire [15:0] audio_left,audio_right;
    wire [229:0] debug_cpu;
    wire [127:0] debug_vdp;
    wire [383:0] debug_cram;
    wire [31:0] debug_io;
    wire [63:0] debug_mapper;
    reg [7:0] rom[0:32767];
    wire [7:0] rom_data=rom[rom_address[14:0]];
    gg_enables enables(clk,1'b0,ce_cpu,ce_vdp,ce_pix,ce_sp);
    gamegear_machine dut(.clk(clk),.reset_n(reset_n),.clear_wram(clear_wram),.freeze(1'b0),
        .machine_sms(1'b1),.tv_pal(1'b0),.fm_enabled(1'b1),
        .pause_pressed(1'b0),.console_reset(1'b0),
        .ce_cpu(ce_cpu),.ce_vdp(ce_vdp),.ce_pix(ce_pix),.ce_sp(ce_sp),.rom_wait_n(1'b1),
        .buttons(7'd0),.region(1'b0),.mapper(4'd1),
        .load_we(1'b0),.load_address(24'd0),.load_data(8'd0),
        .rom_read(rom_read),.rom_address(rom_address),.rom_data(rom_data),
        .color(color),.hblank(hblank),.vblank(vblank),.audio_left(audio_left),.audio_right(audio_right),
        .save_host_address(15'd0),.save_host_data(8'd0),.save_host_we(1'b0),.save_host_q(save_q),
        .debug_wram_address(debug_wram_address),.debug_wram_q(debug_wram_q),.wram_busy(wram_busy),
        .debug_cpu(debug_cpu),.debug_vdp(debug_vdp),.debug_cram(debug_cram),
        .debug_io(debug_io),.debug_mapper(debug_mapper));
    task automatic check_ram(input [12:0] address,input [7:0] expected);
        begin
            @(negedge clk); debug_wram_address=address;
            repeat(3) @(negedge clk);
            if(debug_wram_q!==expected)
                $fatal(1,"SMS FM WRAM[%h]=%h expected %h CPU=%h",
                    address,debug_wram_q,expected,debug_cpu);
        end
    endtask
    integer i,minimum,maximum;
    initial begin
        $readmemh("diagnostics/sms-fm-control.hex",rom);
        repeat(20) @(negedge clk);
        clear_wram=1; @(negedge clk); clear_wram=0;
        wait(!wram_busy);
        repeat(20) @(negedge clk); reset_n=1;
        repeat(350000) @(negedge clk);
        check_ram(8,8'ha5);
        for(i=0;i<8;i=i+1) check_ram(i,8'hf8 | i[7:0]);
        if(EXPECT_FM_SOUND) begin
            minimum=32767; maximum=-32768;
            repeat(100000) begin
                @(negedge clk);
                if($signed(audio_left)<minimum) minimum=$signed(audio_left);
                if($signed(audio_left)>maximum) maximum=$signed(audio_left);
            end
            if(maximum-minimum<16)
                $fatal(1,"Private SMS FM tone did not reach mixed audio: min=%0d max=%0d",
                    minimum,maximum);
            $display("PASS private SMS FM tone reaches mixed audio: min=%0d max=%0d",minimum,maximum);
        end
        $display("PASS real SMS CPU/FM control: $F2 writes and readback for all control bits, $F0/$F1 writes");
        $finish;
    end
    initial begin #100000000; $fatal(1,"SMS FM control test timed out"); end
endmodule
