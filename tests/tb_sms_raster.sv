`timescale 1ns/1ps
module tb_sms_raster;
    parameter integer HEIGHT=224;
    parameter integer PAL=0;
    reg clk=0; always #10 clk=~clk;
    reg reset_n=0,clear_wram=0,load_we=0;
    reg [23:0] load_address=0;
    reg [7:0] load_data=0;
    wire ce_cpu,ce_vdp,ce_pix,ce_sp,rom_read,hblank,vblank,wram_busy;
    wire [23:0] rom_address;
    wire [11:0] color;
    wire [15:0] audio_left,audio_right;
    wire [7:0] save_q,debug_wram_q;
    wire [229:0] debug_cpu;
    wire [127:0] debug_vdp;
    wire [383:0] debug_cram;
    wire [31:0] debug_io;
    wire [63:0] debug_mapper;
    reg [7:0] rom[0:32767];
    wire [7:0] rom_data=rom[rom_address[14:0]];
    wire frame_complete,frame_valid,completed_machine_sms,completed_tv_pal;
    wire [8:0] active_width,active_height;
    wire [7:0] completed_epoch;
    wire [15:0] frame_id;
    gg_enables enables(clk,1'b0,ce_cpu,ce_vdp,ce_pix,ce_sp);
    gamegear_machine dut(.clk(clk),.reset_n(reset_n),.clear_wram(clear_wram),.freeze(1'b0),
        .machine_sms(1'b1),.tv_pal(PAL[0]),.fm_enabled(1'b0),.pause_pressed(1'b0),.console_reset(1'b0),
        .ce_cpu(ce_cpu),.ce_vdp(ce_vdp),.ce_pix(ce_pix),.ce_sp(ce_sp),.rom_wait_n(1'b1),
        .buttons(7'd0),.region(1'b0),.mapper(4'd1),
        .load_we(load_we),.load_address(load_address),.load_data(load_data),
        .rom_read(rom_read),.rom_address(rom_address),.rom_data(rom_data),
        .color(color),.hblank(hblank),.vblank(vblank),.audio_left(audio_left),.audio_right(audio_right),
        .save_host_address(15'd0),.save_host_data(8'd0),.save_host_we(1'b0),.save_host_q(save_q),
        .debug_wram_address(13'd0),.debug_wram_q(debug_wram_q),.wram_busy(wram_busy),
        .debug_cpu(debug_cpu),.debug_vdp(debug_vdp),.debug_cram(debug_cram),
        .debug_io(debug_io),.debug_mapper(debug_mapper));
    gg_video viewport(.clk(clk),.reset(!reset_n),.run(reset_n && !wram_busy),
        .freeze(1'b0),.ce_pix(ce_pix),.machine_sms(1'b1),.tv_pal(PAL[0]),.epoch(8'd1),
        .overlay_active(1'b0),.overlay_step(3'd0),
        .color(color),.native_hblank(hblank),.native_vblank(vblank),
        .red(),.green(),.blue(),.data_enable(),.hblank(),.vblank(),
        .frame_complete(frame_complete),.frame_valid(frame_valid),
        .active_width(active_width),.active_height(active_height),
        .completed_epoch(completed_epoch),.completed_machine_sms(completed_machine_sms),
        .completed_tv_pal(completed_tv_pal),.frame_id(frame_id));

    integer active_pixels=0,active_rows=0,line_pixels=0,complete_frames=0;
    integer system_cycles=0,last_frame_cycle=0;
    // PAL 240-line mode uses the staged 266->466 correction (D2-FF) so all
    // PAL modes have 313 lines; the vendored MiSTer snapshot is unchanged.
    localparam integer FRAME_LINES=PAL ? 313 : 262;
    reg previous_hblank=1,previous_vblank=1,frame_started=0;
    always @(posedge clk) if(reset_n) begin
        system_cycles=system_cycles+1;
        if(previous_vblank && !vblank) frame_started=1;
        if(frame_started && ce_pix && !hblank && !vblank) begin
            active_pixels=active_pixels+1;
            line_pixels=line_pixels+1;
        end
        if(frame_started && hblank && !previous_hblank && line_pixels!=0) begin
            if(complete_frames>0 && line_pixels!=256)
                $fatal(1,"SMS %0d-line mode: line has %0d pixels",HEIGHT,line_pixels);
            line_pixels=0;
            active_rows=active_rows+1;
        end
        if(frame_started && vblank && !previous_vblank) begin
            if(complete_frames>0 && (active_rows!=HEIGHT || active_pixels!=256*HEIGHT))
                $fatal(1,"SMS %0d-line mode: frame has %0d rows/%0d pixels",
                    HEIGHT,active_rows,active_pixels);
            if(last_frame_cycle!=0 && system_cycles-last_frame_cycle!=342*FRAME_LINES*10)
                $fatal(1,"SMS %0d-line PAL=%0d cadence was %0d clocks",
                    HEIGHT,PAL,system_cycles-last_frame_cycle);
            last_frame_cycle=system_cycles;
            complete_frames=complete_frames+1;
            active_rows=0;
            active_pixels=0;
        end
        previous_hblank=hblank;
        previous_vblank=vblank;
    end
    integer i;
    initial begin
        if(HEIGHT==192) $readmemh("diagnostics/sms-raster-192.hex",rom);
        else if(HEIGHT==224) $readmemh("diagnostics/sms-raster-224.hex",rom);
        else if(HEIGHT==240) $readmemh("diagnostics/sms-raster-240.hex",rom);
        else $fatal(1,"Unsupported test height %0d",HEIGHT);
        repeat(20) @(negedge clk);
        clear_wram=1; @(negedge clk); clear_wram=0;
        for(i=0;i<32768;i=i+1) begin
            load_we=1; load_address=i; load_data=rom[i]; @(negedge clk);
        end
        load_we=0;
        repeat(20) @(negedge clk); reset_n=1;
        repeat(PAL ? 2750000 : 2200000) @(negedge clk);
        if(complete_frames<2 || !frame_valid || active_width!==9'd256 ||
           active_height!==HEIGHT || completed_epoch!==8'd1 ||
           !completed_machine_sms || completed_tv_pal!==PAL[0] || frame_id==0)
            $fatal(1,"SMS %0d-line PAL=%0d viewport failed: frames=%0d valid=%b %0dx%0d",
                HEIGHT,PAL,complete_frames,frame_valid,active_width,active_height);
        $display("PASS real SMS %0d-line PAL=%0d native raster and completed viewport",HEIGHT,PAL);
        $finish;
    end
    initial begin #100000000; $fatal(1,"SMS raster test timed out"); end
endmodule
