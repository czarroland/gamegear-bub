`timescale 1ns/1ps
module tb_sms_top_row;
    reg clk=0; always #10 clk=~clk;
    reg reset_n=0,clear_wram=0,load_we=0;
    reg [23:0] load_address=0;
    reg [7:0] load_data=0;
    wire ce_cpu,ce_vdp,ce_pix,ce_sp,rom_read,hblank,vblank,wram_busy;
    wire [23:0] rom_address;
    wire [11:0] color;
    wire [7:0] save_q,debug_wram_q;
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
        .machine_sms(1'b1),.tv_pal(1'b0),.fm_enabled(1'b0),.pause_pressed(1'b0),
        .console_reset(1'b0),.ce_cpu(ce_cpu),.ce_vdp(ce_vdp),.ce_pix(ce_pix),.ce_sp(ce_sp),
        .rom_wait_n(1'b1),.buttons(7'd0),.region(1'b0),.mapper(4'd1),
        .load_we(load_we),.load_address(load_address),.load_data(load_data),
        .rom_read(rom_read),.rom_address(rom_address),.rom_data(rom_data),
        .color(color),.hblank(hblank),.vblank(vblank),
        .audio_left(audio_left),.audio_right(audio_right),
        .save_host_address(15'd0),.save_host_data(8'd0),.save_host_we(1'b0),.save_host_q(save_q),
        .debug_wram_address(13'd0),.debug_wram_q(debug_wram_q),.wram_busy(wram_busy),
        .debug_cpu(debug_cpu),.debug_vdp(debug_vdp),.debug_cram(debug_cram),
        .debug_io(debug_io),.debug_mapper(debug_mapper));

    integer frames=0,row=0,column=0,red=0,blue=0,wrong=0;
    reg previous_hblank=1,previous_vblank=1;
    always @(posedge clk) if(reset_n) begin
        if(previous_vblank && !vblank) begin row=0; column=0; end
        if(ce_pix && !hblank && !vblank) begin
            if(frames>=1 && row==0) begin
                if(color==12'h00f) red=red+1;
                else wrong=wrong+1;
            end
            if(frames>=1 && row>=1 && row<=2) begin
                if(color==12'hf00) blue=blue+1;
                else wrong=wrong+1;
            end
            column=column+1;
        end
        if(!previous_hblank && hblank && column!=0) begin row=row+1; column=0; end
        if(!previous_vblank && vblank) frames=frames+1;
        previous_hblank=hblank;
        previous_vblank=vblank;
    end

    integer i;
    initial begin
        $readmemh("diagnostics/sms-top-row-diagnostic.hex",rom);
        repeat(20) @(negedge clk);
        clear_wram=1; @(negedge clk); clear_wram=0;
        for(i=0;i<32768;i=i+1) begin
            load_we=1; load_address=i; load_data=rom[i]; @(negedge clk);
        end
        load_we=0;
        repeat(20) @(negedge clk); reset_n=1;
        wait(frames>=3);
        if(red<200 || blue<400)
            $fatal(1,"SMS diagnostic colors: red=%0d blue=%0d wrong=%0d",red,blue,wrong);
        $display("PASS SMS top-row diagnostic: native row zero red, following rows blue (wrong=%0d)",wrong);
        $finish;
    end
    initial begin #100000000; $fatal(1,"SMS top-row diagnostic timed out"); end
endmodule
