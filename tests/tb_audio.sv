`timescale 1ns/1ps
module tb_audio;
    reg clk=0;always #10 clk=~clk;
    reg reset=1,mute=0,pal_mode=0;
    reg signed [15:0] raw_left=-1234,raw_right=2345;
    wire signed [15:0] left,right;
    wire sample_tick;
    gg_audio dut(.*);
    integer samples=0,i;
    initial begin
        repeat(3) @(negedge clk);reset=0;
        for(i=0;i<100000;i=i+1) begin
            @(negedge clk);
            if(sample_tick) begin
                samples=samples+1;
                if(left> -1234 || left< -1236 || right<2345 || right>2348)
                    $fatal(1,"Signed audio/gain mismatch %0d/%0d",left,right);
            end
        end
        if(samples!=89) $fatal(1,"48 kHz accumulator produced %0d samples",samples);
        mute=1;repeat(2) @(negedge clk);
        if(left!==0 || right!==0) $fatal(1,"Mute not silent");
        raw_left=0;raw_right=0;mute=0;repeat(3000) @(negedge clk);
        if(left!==0 || right!==0) $fatal(1,"Zero input has DC offset");
        raw_left=16'sh7fff;raw_right=16'sh8000;repeat(2500) @(negedge clk);
        if(left!==16'sh7fff || right!==16'sh8000) $fatal(1,"Audio clipping failed at signed limits");
        $display("PASS signed audio: fractional sample cadence, gain, stereo independence, mute, zero DC, clipping");
        $finish;
    end
endmodule
