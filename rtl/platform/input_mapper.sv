// SPDX-License-Identifier: GPL-3.0-or-later
// Ten commands can each use any physical Gamebub button. A short single-button
// press binds on release; holding one button keeps the current binding, and
// holding Start+Select exits. The hold gestures leave every single button
// available for capture. Bindings last until core power-off or Restore controls.
module input_mapper #(parameter integer DEBOUNCE_CYCLES=268456,
                      parameter integer HOLD_CYCLES=53691275)(
    input wire clk,reset,begin_mapping,reset_mapping,running,focus,
    input wire [11:0] physical, // Up Down Left Right A B X Y L R Start Select
    output reg active=0,
    output reg [3:0] step=0,
    output wire [9:0] mapped // Up Down Left Right A B Start CropUp CropDown Reset
);
    localparam integer COUNT_WIDTH=(DEBOUNCE_CYCLES<2) ? 1 : $clog2(DEBOUNCE_CYCLES+1);
    localparam integer HOLD_WIDTH=(HOLD_CYCLES<2) ? 1 : $clog2(HOLD_CYCLES+1);
    localparam [11:0] EXIT_BUTTONS=12'hc00;
    reg [3:0] binding[0:9];
    reg [11:0] sampled=0,stable_buttons=0,pressed_buttons=0;
    reg [COUNT_WIDTH-1:0] stable_count=0;
    reg [HOLD_WIDTH-1:0] hold_count=0;
    reg armed=0,handled=0;
    function automatic one_button(input [11:0] mask);
        one_button=mask!=0 && (mask & (mask-12'd1))==0;
    endfunction
    function automatic [3:0] physical_index(input [11:0] mask);
        begin
            physical_index=0;
            for(integer k=0;k<12;k=k+1)
                if(mask[k]) physical_index=k[3:0];
        end
    endfunction
    genvar i;
    generate for(i=0;i<10;i=i+1) begin: outputs
        assign mapped[i]=physical[binding[i]];
    end endgenerate
    always @(posedge clk) begin
        if(reset || reset_mapping) begin
            for(integer j=0;j<6;j=j+1) binding[j]<=j[3:0];
            binding[6]<=4'd10; // Start/Pause
            binding[7]<=4'd8;  // SMS crop up: L
            binding[8]<=4'd9;  // SMS crop down: R
            binding[9]<=4'd11; // Optional SMS Reset: Select
            active<=0;step<=0;sampled<=0;stable_buttons<=0;
            pressed_buttons<=0;stable_count<=0;hold_count<=0;
            armed<=0;handled<=0;
        end else if(begin_mapping) begin
            active<=1;step<=0;sampled<=0;stable_buttons<=0;
            pressed_buttons<=0;stable_count<=0;hold_count<=0;
            armed<=0;handled<=0;
        end else if(active) begin
            if(!running || !focus) begin
                sampled<=0;stable_buttons<=0;pressed_buttons<=0;
                stable_count<=0;hold_count<=0;armed<=0;handled<=0;
            end else if(physical!=sampled) begin
                sampled<=physical;
                stable_count<=0;
            end else if(stable_count<DEBOUNCE_CYCLES) begin
                stable_count<=stable_count+1'b1;
            end else if(stable_buttons!=physical) begin
                stable_buttons<=physical;
                stable_count<=0;
                hold_count<=0;
                if(physical==0) begin
                    if(armed && !handled && one_button(pressed_buttons)) begin
                        binding[step]<=physical_index(pressed_buttons);
                        if(step==9) active<=0;
                        else step<=step+1'b1;
                    end
                    pressed_buttons<=0;
                    armed<=1;
                    handled<=0;
                end else if(armed && !handled) begin
                    pressed_buttons<=physical;
                end
            end else if(physical==0 && !armed) begin
                armed<=1;
            end else if(armed && physical!=0 && !handled) begin
                if(hold_count<HOLD_CYCLES) hold_count<=hold_count+1'b1;
                else begin
                    handled<=1;
                    if(physical==EXIT_BUTTONS) active<=0;
                    else if(one_button(physical)) begin
                        if(step==9) active<=0;
                        else step<=step+1'b1;
                    end
                end
            end
        end
    end
endmodule
