// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps
module gg_audio #(parameter integer CLOCK_HZ=53691275)(
    input wire clk,reset,mute,
    input wire signed [15:0] raw_left,raw_right,
    output reg signed [15:0] left,right,
    output reg sample_tick);
    localparam integer MEAN_CYCLES=CLOCK_HZ/48000;
    localparam integer ACC_WIDTH=16+$clog2(MEAN_CYCLES+2);
    localparam signed [ACC_WIDTH-1:0] DIVISOR=ACC_WIDTH'(MEAN_CYCLES);
    reg [31:0] phase=0;
    reg signed [ACC_WIDTH-1:0] sum_left=0,sum_right=0;
    wire signed [ACC_WIDTH-1:0] next_left=sum_left+$signed({{(ACC_WIDTH-16){raw_left[15]}},raw_left});
    wire signed [ACC_WIDTH-1:0] next_right=sum_right+$signed({{(ACC_WIDTH-16){raw_right[15]}},raw_right});
    reg signed [ACC_WIDTH-1:0] window_left=0,window_right=0;
    reg signed [16:0] quotient_left=0,quotient_right=0;
    reg window_valid=0,quotient_valid=0;
    // A constant divisor keeps the boxcar practical to synthesize. The two
    // window lengths differ by one cycle; their gain difference is <0.1%.
    wire signed [16:0] mean_left=window_left/DIVISOR;
    wire signed [16:0] mean_right=window_right/DIVISOR;
    function automatic signed [15:0] clip(input signed [31:0] sample);
        if(sample>32767) clip=16'sh7fff;
        else if(sample< -32768) clip=16'sh8000;
        else clip=sample[15:0];
    endfunction
    always @(posedge clk) begin
        if(reset) begin
            phase<=0; sum_left<=0; sum_right<=0; left<=0; right<=0;
            window_left<=0; window_right<=0; quotient_left<=0; quotient_right<=0;
            window_valid<=0; quotient_valid<=0; sample_tick<=0;
        end else begin
            window_valid<=0;
            quotient_valid<=window_valid;
            sample_tick<=quotient_valid;
            if(window_valid) begin
                quotient_left<=mean_left;
                quotient_right<=mean_right;
            end
            if(quotient_valid) begin
                left<=mute ? 16'sd0 : clip(quotient_left);
                right<=mute ? 16'sd0 : clip(quotient_right);
            end
            if(phase>=CLOCK_HZ-48000) begin
                phase<=phase+48000-CLOCK_HZ;
                sum_left<=0; sum_right<=0;
                window_left<=next_left; window_right<=next_right;
                window_valid<=1;
            end else begin
                phase<=phase+48000;
                sum_left<=mute ? 0 : next_left;
                sum_right<=mute ? 0 : next_right;
            end
            if(mute) begin left<=0; right<=0; end
        end
    end
endmodule
