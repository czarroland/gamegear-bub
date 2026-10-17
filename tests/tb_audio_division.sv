`timescale 1ns/1ps
module tb_audio_division;
    reg clk=0; always #10 clk=~clk;
    reg reset=1,mute=0;
    reg signed [15:0] raw_left=0,raw_right=0;
    wire signed [15:0] left,right;
    wire sample_tick;
    gg_audio dut(.*);
    localparam integer CLOCK_HZ=53691275;
    integer expected_left=0,expected_right=0;
    integer sum_left=0,sum_right=0,window_cycles=0,phase=0;
    integer samples=0,i,short_windows=0,long_windows=0;
    reg [31:0] random_state=32'h23b5a11d;
    always @(posedge clk) if(!reset) begin
        sum_left=sum_left+$signed(raw_left);
        sum_right=sum_right+$signed(raw_right);
        window_cycles=window_cycles+1;
        if(phase>=CLOCK_HZ-48000) begin
            expected_left=sum_left/window_cycles;
            expected_right=sum_right/window_cycles;
            if(window_cycles==1118) short_windows=short_windows+1;
            else if(window_cycles==1119) long_windows=long_windows+1;
            else $fatal(1,"Unexpected audio window length %0d",window_cycles);
            phase=phase+48000-CLOCK_HZ;
            sum_left=0;sum_right=0;window_cycles=0;
        end else phase=phase+48000;
    end
    initial begin
        repeat(3) @(negedge clk); reset=0;
        for(i=0;i<120000;i=i+1) begin
            @(negedge clk);
            if(sample_tick) begin
                samples=samples+1;
                if(left!==expected_left || right!==expected_right)
                    $fatal(1,"Audio mean %0d mismatch: got %0d/%0d expected %0d/%0d",
                        samples,left,right,expected_left,expected_right);
            end
            random_state={random_state[30:0],
                random_state[31]^random_state[21]^random_state[1]^random_state[0]};
            raw_left=$signed(random_state[15:0]);
            raw_right=$signed(random_state[31:16]);
        end
        if(samples<100) $fatal(1,"Too few audio samples: %0d",samples);
        if(short_windows==0 || long_windows==0)
            $fatal(1,"Missing fractional window sizes %0d/%0d",short_windows,long_windows);
        $display("PASS exact signed audio division across %0d varying windows (%0d/%0d cycles)",
            samples,short_windows,long_windows);
        $finish;
    end
endmodule
