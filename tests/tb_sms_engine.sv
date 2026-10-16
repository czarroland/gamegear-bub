`timescale 1ns/1ps
module tb_sms_engine;
    reg clk=0; always #10 clk=~clk;
    reg reset_n=0,clear_wram=0,load_we=0,pause_pressed=0,console_reset=0;
    wire ce_cpu,ce_vdp,ce_pix,ce_sp,rom_read,hblank,vblank,wram_busy;
    reg [23:0] load_address=0;
    reg [7:0] load_data=0;
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
    wire frame_complete,frame_valid,completed_machine_sms,completed_tv_pal;
    wire [8:0] active_width,active_height;
    wire [7:0] completed_epoch;
    wire [15:0] frame_id;
    reg [7:0] rom[0:32767];
    wire [7:0] rom_data=rom[rom_address[14:0]];
    gg_enables enables(clk,1'b0,ce_cpu,ce_vdp,ce_pix,ce_sp);
    gamegear_machine dut(.clk(clk),.reset_n(reset_n),.clear_wram(clear_wram),.freeze(1'b0),
        .machine_sms(1'b1),.tv_pal(1'b0),.pause_pressed(pause_pressed),
        .console_reset(console_reset),
        .ce_cpu(ce_cpu),.ce_vdp(ce_vdp),.ce_pix(ce_pix),.ce_sp(ce_sp),.rom_wait_n(1'b1),
        .buttons(7'd0),.region(1'b0),.mapper(4'd1),
        .load_we(load_we),.load_address(load_address),.load_data(load_data),
        .rom_read(rom_read),.rom_address(rom_address),.rom_data(rom_data),
        .color(color),.hblank(hblank),.vblank(vblank),.audio_left(audio_left),.audio_right(audio_right),
        .save_host_address(15'd0),.save_host_data(8'd0),.save_host_we(1'b0),.save_host_q(save_q),
        .debug_wram_address(debug_wram_address),.debug_wram_q(debug_wram_q),.wram_busy(wram_busy),
        .debug_cpu(debug_cpu),.debug_vdp(debug_vdp),.debug_cram(debug_cram),
        .debug_io(debug_io),.debug_mapper(debug_mapper));
    gg_video viewport(.clk(clk),.reset(!reset_n),.run(reset_n && !wram_busy),
        .freeze(1'b0),.ce_pix(ce_pix),.machine_sms(1'b1),.tv_pal(1'b0),.epoch(8'd1),
        .color(color),.native_hblank(hblank),.native_vblank(vblank),
        .red(),.green(),.blue(),.data_enable(),.hblank(),.vblank(),
        .frame_complete(frame_complete),.frame_valid(frame_valid),
        .active_width(active_width),.active_height(active_height),
        .completed_epoch(completed_epoch),.completed_machine_sms(completed_machine_sms),
        .completed_tv_pal(completed_tv_pal),.frame_id(frame_id));
    task automatic check_ram(input [12:0] address,input [7:0] expected);
        begin
            @(negedge clk); debug_wram_address=address;
            repeat(3) @(negedge clk);
            if(debug_wram_q!==expected)
                $fatal(1,"SMS WRAM[%h]=%h expected %h CPU=%h",address,debug_wram_q,expected,debug_cpu);
        end
    endtask
    integer active_pixels=0,active_rows=0,line_pixels=0,complete_frames=0;
    reg previous_hblank=1,previous_vblank=1,frame_started=0;
    always @(posedge clk) if(reset_n) begin
        if(previous_vblank && !vblank) frame_started=1;
        if(frame_started && ce_pix && !hblank && !vblank) begin
            active_pixels=active_pixels+1;
            line_pixels=line_pixels+1;
        end
        if(frame_started && hblank && !previous_hblank && line_pixels!=0) begin
            if(line_pixels!=256 && complete_frames>0)
                $fatal(1,"SMS raster line has %0d pixels",line_pixels);
            line_pixels=0;
            active_rows=active_rows+1;
        end
        if(frame_started && vblank && !previous_vblank) begin
            // The first frame after release from reset starts mid-raster.
            if(complete_frames>0 && (active_rows!=192 || active_pixels!=256*192))
                $fatal(1,"SMS frame has %0d rows, %0d pixels",active_rows,active_pixels);
            complete_frames=complete_frames+1;
            active_rows=0;
            active_pixels=0;
        end
        previous_hblank=hblank;
        previous_vblank=vblank;
    end
    integer i;
    initial begin
        $readmemh("diagnostics/sms-pause-diagnostic.hex",rom);
        repeat(20) @(negedge clk);
        clear_wram=1; @(negedge clk); clear_wram=0;
        for(i=0;i<32768;i=i+1) begin
            load_we=1; load_address=i; load_data=rom[i]; @(negedge clk);
        end
        load_we=0;
        repeat(20) @(negedge clk); reset_n=1;
        repeat(100000) @(negedge clk);
        check_ram(0,8'd0);
        check_ram(1,8'h10); // Released console Reset reads high at $DD bit 4.
        pause_pressed=1;
        repeat(10000) @(negedge clk);
        check_ram(0,8'd1);
        repeat(100000) @(negedge clk);
        check_ram(0,8'd1); // A held NMI line causes no repeat.
        pause_pressed=0;
        repeat(10000) @(negedge clk);
        pause_pressed=1;
        repeat(10000) @(negedge clk);
        check_ram(0,8'd2);
        pause_pressed=0;
        console_reset=1;
        repeat(10000) @(negedge clk);
        check_ram(1,8'h00);
        check_ram(0,8'd2); // Console Reset is not a CPU reset.
        console_reset=0;
        repeat(10000) @(negedge clk);
        check_ram(1,8'h10);
        repeat(1800000) @(negedge clk);
        if(complete_frames<2) $fatal(1,"No complete SMS active raster observed");
        if(!frame_valid || active_width!==9'd256 || active_height!==9'd192 ||
           completed_epoch!==8'd1 || !completed_machine_sms || completed_tv_pal || frame_id==0)
            $fatal(1,"SMS viewport descriptor invalid: %b %d x %d epoch=%d mode=%b/%b id=%d",
                frame_valid,active_width,active_height,completed_epoch,
                completed_machine_sms,completed_tv_pal,frame_id);
        $display("PASS real SMS engine: Pause NMI under DI, hold/repress, console Reset port, 256x192 native raster");
        $finish;
    end
    initial begin #100000000; $fatal(1,"SMS engine test timed out"); end
endmodule
