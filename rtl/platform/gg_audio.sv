// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps
module gg_audio #(parameter integer CLOCK_HZ=53691275,
                  parameter integer PAL_CLOCK_HZ=53205128)(
    input wire clk,reset,mute,pal_mode,
    input wire signed [15:0] raw_left,raw_right,
    output reg signed [15:0] left,right,
    output reg sample_tick);
    localparam integer MEAN_CYCLES=(CLOCK_HZ>PAL_CLOCK_HZ ? CLOCK_HZ : PAL_CLOCK_HZ)/48000;
    wire [31:0] active_clock_hz=pal_mode ? PAL_CLOCK_HZ : CLOCK_HZ;
    localparam integer ACC_WIDTH=16+$clog2(MEAN_CYCLES+2);
    localparam integer REM_WIDTH=$clog2(MEAN_CYCLES+1)+1;
    localparam integer COUNT_WIDTH=$clog2(ACC_WIDTH+1);
    reg [31:0] phase=0;
    // The 48 kHz phase accumulator yields either MEAN_CYCLES or one more
    // input clock per window. Use the actual count for its signed mean.
    reg [REM_WIDTH-1:0] window_count=0;
    reg [REM_WIDTH-1:0] window_divisor=REM_WIDTH'(MEAN_CYCLES);
    reg signed [ACC_WIDTH-1:0] sum_left=0,sum_right=0;
    wire signed [ACC_WIDTH-1:0] next_left=sum_left+$signed({{(ACC_WIDTH-16){raw_left[15]}},raw_left});
    wire signed [ACC_WIDTH-1:0] next_right=sum_right+$signed({{(ACC_WIDTH-16){raw_right[15]}},raw_right});
    reg signed [ACC_WIDTH-1:0] window_left=0,window_right=0;
    reg signed [16:0] quotient_left=0,quotient_right=0;
    reg window_valid=0,quotient_valid=0;
    // The mean has over a thousand clocks to finish. Divide one bit per
    // clock instead of putting two signed constant dividers on the 53 MHz
    // audio path. Magnitude division followed by sign restoration keeps the
    // same truncation toward zero as SystemVerilog signed division.
    reg divide_active=0;
    reg [COUNT_WIDTH-1:0] bits_left=0;
    reg negative_left=0,negative_right=0;
    reg [ACC_WIDTH-1:0] dividend_left=0,dividend_right=0;
    reg [ACC_WIDTH-1:0] quotient_shift_left=0,quotient_shift_right=0;
    reg [REM_WIDTH-1:0] remainder_left=0,remainder_right=0;
    wire [REM_WIDTH-1:0] trial_left={remainder_left[REM_WIDTH-2:0],dividend_left[ACC_WIDTH-1]};
    wire [REM_WIDTH-1:0] trial_right={remainder_right[REM_WIDTH-2:0],dividend_right[ACC_WIDTH-1]};
    wire take_left=trial_left>=window_divisor;
    wire take_right=trial_right>=window_divisor;
    wire [ACC_WIDTH-1:0] quotient_next_left={quotient_shift_left[ACC_WIDTH-2:0],take_left};
    wire [ACC_WIDTH-1:0] quotient_next_right={quotient_shift_right[ACC_WIDTH-2:0],take_right};
    function automatic signed [15:0] clip(input signed [31:0] sample);
        if(sample>32767) clip=16'sh7fff;
        else if(sample< -32768) clip=16'sh8000;
        else clip=sample[15:0];
    endfunction
    always @(posedge clk) begin
        if(reset) begin
            phase<=0; window_count<=0; window_divisor<=REM_WIDTH'(MEAN_CYCLES);
            sum_left<=0; sum_right<=0; left<=0; right<=0;
            window_left<=0; window_right<=0; quotient_left<=0; quotient_right<=0;
            window_valid<=0; quotient_valid<=0; sample_tick<=0;
            divide_active<=0; bits_left<=0; negative_left<=0; negative_right<=0;
            dividend_left<=0; dividend_right<=0;
            quotient_shift_left<=0; quotient_shift_right<=0;
            remainder_left<=0; remainder_right<=0;
        end else begin
            window_valid<=0;
            quotient_valid<=0;
            sample_tick<=quotient_valid;
            if(window_valid) begin
                divide_active<=1;
                bits_left<=COUNT_WIDTH'(ACC_WIDTH);
                negative_left<=window_left[ACC_WIDTH-1];
                negative_right<=window_right[ACC_WIDTH-1];
                dividend_left<=window_left[ACC_WIDTH-1] ? -window_left : window_left;
                dividend_right<=window_right[ACC_WIDTH-1] ? -window_right : window_right;
                quotient_shift_left<=0; quotient_shift_right<=0;
                remainder_left<=0; remainder_right<=0;
            end else if(divide_active) begin
                dividend_left<={dividend_left[ACC_WIDTH-2:0],1'b0};
                dividend_right<={dividend_right[ACC_WIDTH-2:0],1'b0};
                remainder_left<=take_left ? trial_left-window_divisor : trial_left;
                remainder_right<=take_right ? trial_right-window_divisor : trial_right;
                quotient_shift_left<=quotient_next_left;
                quotient_shift_right<=quotient_next_right;
                bits_left<=bits_left-1'b1;
                if(bits_left==1) begin
                    divide_active<=0;
                    quotient_left<=negative_left ? -$signed(quotient_next_left[16:0]) :
                        $signed(quotient_next_left[16:0]);
                    quotient_right<=negative_right ? -$signed(quotient_next_right[16:0]) :
                        $signed(quotient_next_right[16:0]);
                    quotient_valid<=1;
                end
            end
            if(quotient_valid) begin
                left<=mute ? 16'sd0 : clip(quotient_left);
                right<=mute ? 16'sd0 : clip(quotient_right);
            end
            if(phase>=active_clock_hz-48000) begin
                phase<=phase+48000-active_clock_hz;
                window_divisor<=window_count+1'b1;
                window_count<=0;
                sum_left<=0; sum_right<=0;
                window_left<=next_left; window_right<=next_right;
                window_valid<=1;
            end else begin
                phase<=phase+48000;
                window_count<=window_count+1'b1;
                sum_left<=mute ? 0 : next_left;
                sum_right<=mute ? 0 : next_right;
            end
            if(mute) begin left<=0; right<=0; end
        end
    end
endmodule
