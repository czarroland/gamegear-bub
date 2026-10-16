`timescale 1ns/1ps
module tb_audio_division;
    reg clk=0; always #10 clk=~clk;
    reg reset=1,mute=0;
    reg signed [15:0] raw_left=0,raw_right=0;
    wire signed [15:0] left,right;
    wire sample_tick;
    gg_audio dut(.*);
    localparam integer DIVISOR=53691275/48000;
    integer expected_left=0,expected_right=0;
    integer samples=0,i;
    reg [31:0] random_state=32'h23b5a11d;
    initial begin
        repeat(3) @(negedge clk); reset=0;
        for(i=0;i<120000;i=i+1) begin
            @(negedge clk);
            if(dut.window_valid) begin
                expected_left=$signed(dut.window_left)/DIVISOR;
                expected_right=$signed(dut.window_right)/DIVISOR;
            end
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
        $display("PASS exact signed audio division across %0d varying windows",samples);
        $finish;
    end
endmodule
