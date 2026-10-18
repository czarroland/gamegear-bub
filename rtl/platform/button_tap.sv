// SPDX-License-Identifier: GPL-3.0-or-later
// One event per stable press, after a stable release in the active context.
module button_tap #(parameter integer DEBOUNCE_CYCLES=268456)(
    input wire clk,reset,enable,raw,
    output reg tap=0
);
    localparam integer COUNT_WIDTH=(DEBOUNCE_CYCLES<2) ? 1 : $clog2(DEBOUNCE_CYCLES);
    reg sampled=0,synchronized=0,stable=0,armed=0;
    reg [COUNT_WIDTH-1:0] count=0;
    always @(posedge clk) begin
        sampled<=raw;
        synchronized<=sampled;
        tap<=0;
        if(reset || !enable) begin
            stable<=0;
            armed<=0;
            count<=0;
        end else if(synchronized==stable) begin
            if(!stable && !armed) begin
                if(count==DEBOUNCE_CYCLES-1) begin
                    armed<=1;
                    count<=0;
                end else count<=count+1'b1;
            end else count<=0;
        end
        else if(count==DEBOUNCE_CYCLES-1) begin
            stable<=synchronized;
            count<=0;
            if(synchronized) begin
                if(armed) tap<=1;
                armed<=0;
            end else armed<=1;
        end else count<=count+1'b1;
    end
endmodule
