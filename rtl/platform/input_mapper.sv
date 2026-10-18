// SPDX-License-Identifier: GPL-3.0-or-later
// MiSTer-style in-game capture: each prompt accepts one physical button.
// Start exits; Select keeps the current binding and advances. The BUB menu
// opens this overlay with a guarded host action, so firmware changes are not
// needed. Bindings are session state; firmware settings persist the A/B swap.
module input_mapper #(parameter integer DEBOUNCE_CYCLES=268456)(
    input wire clk,reset,begin_mapping,reset_mapping,running,focus,
    input wire [7:0] physical, // Up, Down, Left, Right, A, B, X, Y
    input wire start_button,select_button,
    output reg active=0,
    output reg [2:0] step=0,
    output wire [5:0] mapped // Up, Down, Left, Right, A, B
);
    localparam integer COUNT_WIDTH=(DEBOUNCE_CYCLES<2) ? 1 : $clog2(DEBOUNCE_CYCLES+1);
    reg [2:0] binding[0:5];
    reg [9:0] sampled=0;
    reg [COUNT_WIDTH-1:0] stable_count=0;
    reg armed=0;
    wire [9:0] candidate={select_button,start_button,physical};
    wire one_physical=physical!=0 && (physical & (physical-8'd1))==0;
    function automatic [2:0] physical_index(input [7:0] mask);
        case(mask)
            8'h01: physical_index=0;
            8'h02: physical_index=1;
            8'h04: physical_index=2;
            8'h08: physical_index=3;
            8'h10: physical_index=4;
            8'h20: physical_index=5;
            8'h40: physical_index=6;
            default: physical_index=7;
        endcase
    endfunction
    genvar i;
    generate for(i=0;i<6;i=i+1) begin: outputs
        assign mapped[i]=physical[binding[i]];
    end endgenerate
    always @(posedge clk) begin
        if(reset || reset_mapping) begin
            for(integer j=0;j<6;j=j+1) binding[j]<=j[2:0];
            active<=0;
            step<=0;
            sampled<=0;
            stable_count<=0;
            armed<=0;
        end else if(begin_mapping) begin
            active<=1;
            step<=0;
            sampled<=0;
            stable_count<=0;
            armed<=0;
        end else if(active) begin
            if(!running || !focus) begin
                sampled<=0;
                stable_count<=0;
                armed<=0;
            end else if(candidate!=sampled) begin
                sampled<=candidate;
                stable_count<=0;
            end else if(stable_count<DEBOUNCE_CYCLES) begin
                stable_count<=stable_count+1'b1;
            end else if(candidate==0) armed<=1;
            else if(armed) begin
                armed<=0;
                if(start_button && !select_button && physical==0) active<=0;
                else if(select_button && !start_button && physical==0) begin
                    if(step==5) active<=0;
                    else step<=step+1'b1;
                end else if(!start_button && !select_button && one_physical) begin
                    binding[step]<=physical_index(physical);
                    if(step==5) active<=0;
                    else step<=step+1'b1;
                end
            end
        end
    end
endmodule
