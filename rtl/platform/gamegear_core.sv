// SPDX-License-Identifier: GPL-3.0-or-later
module gamegear_core #(parameter integer DISPLAY_DIVIDER=38)(
    input wire clock,reset,clocks_clockIn50M,
    output wire clocks_clockOutSystem,clocks_clockOutDisplay,clocks_clockOutSpi,clocks_locked,
    output wire [3:0] video_data_r,video_data_g,video_data_b,
    output wire video_dataEnable,video_vblank,video_hblank,
    output wire [1:0] videoScale_mode,
    output wire [15:0] audio_left,audio_right,
    input wire [31:0] host_mem_address,host_mem_dataWrite,
    input wire host_mem_enable,host_mem_write,
    output wire [31:0] host_mem_dataRead,output wire host_mem_done,
    input wire host_commandHost_request,
    output wire host_commandHost_busy,host_commandHost_done,host_commandHost_error,
    output wire host_commandCore_request,
    input wire host_commandCore_busy,host_commandCore_done,host_commandCore_error,
    input wire input_buttons_a,input_buttons_b,input_buttons_x,input_buttons_y,
    input wire input_buttons_up,input_buttons_down,input_buttons_left,input_buttons_right,
    input wire input_buttons_l,input_buttons_r,input_buttons_start,input_buttons_select,
    output wire sdram_clock,sdram_cke,sdram_cs,sdram_ras,sdram_cas,sdram_we,
    output wire [1:0] sdram_dqm,sdram_bank,output wire [12:0] sdram_address,
    input wire [15:0] sdram_dataIn,output wire [15:0] sdram_dataOut,output wire sdram_dataDir);
    gg_clocks #(.DISPLAY_DIVIDER(DISPLAY_DIVIDER)) clocks(.clock_50m(clocks_clockIn50M),
        .system_clock(clocks_clockOutSystem),.display_clock(clocks_clockOutDisplay),
        .spi_clock(clocks_clockOutSpi),.locked(clocks_locked));
    wire system_reset=reset;
    ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT(1'b0),.SRTYPE("SYNC")) forward_sdram_clock(
        .C(clocks_clockOutSystem),.CE(1'b1),.D1(1'b0),.D2(1'b1),
        .R(1'b0),.S(1'b0),.Q(sdram_clock));
    wire request,write,ready,done,initialized;
    wire [24:0] address;
    wire [7:0] data_write,data_read;
    assign host_commandCore_request=1'b0;
    gamegear_soc soc(.clk(clocks_clockOutSystem),.reset(system_reset),
        .buttons({input_buttons_start,input_buttons_a,input_buttons_b,
                  input_buttons_right,input_buttons_left,input_buttons_down,input_buttons_up}),
        .select_button(input_buttons_select),
        .mem_enable(host_mem_enable),.mem_write(host_mem_write),.mem_address(host_mem_address),
        .mem_data_write(host_mem_dataWrite),.mem_done(host_mem_done),.mem_data_read(host_mem_dataRead),
        .command_request(host_commandHost_request),.command_busy(host_commandHost_busy),
        .command_done(host_commandHost_done),.command_error(host_commandHost_error),
        .memory_initialized(initialized),.memory_ready(ready),.memory_done(done),.memory_data_read(data_read),
        .memory_request(request),.memory_write(write),.memory_address(address),.memory_data_write(data_write),
        .red(video_data_r),.green(video_data_g),.blue(video_data_b),
        .data_enable(video_dataEnable),.hblank(video_hblank),.vblank(video_vblank),
        .display_scale_mode(videoScale_mode),
        .audio_left(audio_left),.audio_right(audio_right));
    gg_sdram memory(.clk(clocks_clockOutSystem),.reset(system_reset),
        .request(request),.write(write),.address(address),.data_write(data_write),
        .ready(ready),.done(done),.data_read(data_read),.initialized(initialized),
        .cke(sdram_cke),.cs(sdram_cs),.ras(sdram_ras),.cas(sdram_cas),.we(sdram_we),
        .dqm(sdram_dqm),.bank(sdram_bank),.sdram_address(sdram_address),
        .data_in(sdram_dataIn),.data_out(sdram_dataOut),.data_dir(sdram_dataDir));
endmodule
