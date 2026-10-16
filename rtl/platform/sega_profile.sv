// SPDX-License-Identifier: GPL-3.0-or-later
// Apply a requested machine only while the engine is halted and the ROM bus is
// drained. The loaded ROM and cartridge SRAM remain in place across restarts.
module sega_profile(
    input wire clk,reset,
    input wire load_start,load_end,reconfigure,
    input wire setup_complete,rom_ready,memory_idle,save_busy,wram_busy,
    input wire [1:0] selected_type,
    output reg [1:0] active_type=0,
    output wire ready,busy,error,
    output reg clear_wram=0
);
    localparam [2:0] P_EMPTY=0,P_WAIT_SETUP=1,P_DRAIN=2,
                     P_WARMUP=3,P_READY=4,P_ERROR=5;
    reg [2:0] state=P_EMPTY;
    reg [5:0] warmup_count=0;
    assign ready=state==P_READY;
    assign busy=state==P_WAIT_SETUP || state==P_DRAIN || state==P_WARMUP;
    assign error=state==P_ERROR;

    always @(posedge clk) begin
        clear_wram<=0;
        if(reset || load_start) begin
            state<=reset ? P_EMPTY : P_WAIT_SETUP;
            active_type<=0;
            warmup_count<=0;
        end else if(reconfigure && rom_ready) begin
            state<=P_DRAIN;
            warmup_count<=0;
        end else begin
            case(state)
                P_WAIT_SETUP: if(load_end || (setup_complete && rom_ready))
                    state<=setup_complete ? P_DRAIN : P_WAIT_SETUP;
                P_DRAIN: if(rom_ready && setup_complete && memory_idle &&
                            !save_busy && !wram_busy) begin
                    if(selected_type==2'd1 || selected_type==2'd2) begin
                        active_type<=selected_type;
                        clear_wram<=1;
                        warmup_count<=6'd32;
                        state<=P_WARMUP;
                    end else state<=P_ERROR;
                end
                P_WARMUP: begin
                    if(warmup_count!=0) warmup_count<=warmup_count-1'b1;
                    else if(!wram_busy) state<=P_READY;
                end
                default: ;
            endcase
        end
    end
endmodule
