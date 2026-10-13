// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps
// Byte transactions on one 32 MiB x16 SDRAM. Commands are registered on the
// core rising edge; the forwarded SDRAM clock samples them half a cycle later.
module gg_sdram #(parameter integer INIT_CYCLES=10739,REFRESH_CYCLES=360)(
    input wire clk,reset,
    input wire request,write,input wire [24:0] address,input wire [7:0] data_write,
    output wire ready,output reg done,output reg [7:0] data_read,
    output reg initialized,
    output wire cke,cs,output reg ras,cas,we,
    output reg [1:0] dqm,bank,output reg [12:0] sdram_address,
    input wire [15:0] data_in,output reg [15:0] data_out,output reg data_dir);
    localparam POWER=0,PRE=1,INIT_REFRESH=2,MODE=3,IDLE=4,
               ACTIVE=5,COLUMN=6,READ_WAIT=7,RECOVER=8,REFRESH=9;
    reg [3:0] state=POWER;
    // The SDRAM data appears after the forwarded clock's rising edge. Capture
    // it on the following system falling edge, then use the registered value
    // on a later rising edge. This gives the input path a full clock period.
    reg [15:0] data_sample=0;
    always @(negedge clk) data_sample<=data_in;
    localparam [15:0] INITIAL_DELAY=16'(INIT_CYCLES);
    localparam [9:0] REFRESH_LIMIT=10'(REFRESH_CYCLES);
    reg [15:0] delay_count=INITIAL_DELAY;
    reg [9:0] refresh_age=0;
    reg [3:0] init_refresh_count=0;
    reg [24:0] latched_address;
    reg [7:0] latched_data;
    reg latched_write;
    assign cke=1'b1;
    assign cs=1'b0;
    assign ready=initialized && state==IDLE && refresh_age<REFRESH_LIMIT;
    always @(posedge clk) begin
        ras<=1; cas<=1; we<=1; dqm<=0; data_dir<=0; done<=0;
        if(reset) begin
            state<=POWER; delay_count<=INITIAL_DELAY; initialized<=0;
            refresh_age<=0; init_refresh_count<=0; bank<=0;
            sdram_address<=0; data_out<=0; data_read<=0;
        end else begin
            if(initialized && refresh_age<1023) refresh_age<=refresh_age+1'b1;
            case(state)
                POWER: if(delay_count==0) begin
                    // PRECHARGE ALL
                    ras<=0; we<=0; sdram_address<=13'h400;
                    delay_count<=2; state<=PRE;
                end else delay_count<=delay_count-1'b1;
                PRE: if(delay_count==0) begin
                    ras<=0; cas<=0; delay_count<=4;
                    init_refresh_count<=1; state<=INIT_REFRESH;
                end else delay_count<=delay_count-1'b1;
                INIT_REFRESH: if(delay_count==0) begin
                    if(init_refresh_count==8) begin
                        // Sequential, burst length 1, CAS 2, single write.
                        ras<=0; cas<=0; we<=0; bank<=0;
                        sdram_address<=13'h220; delay_count<=2; state<=MODE;
                    end else begin
                        ras<=0; cas<=0; delay_count<=4;
                        init_refresh_count<=init_refresh_count+1'b1;
                    end
                end else delay_count<=delay_count-1'b1;
                MODE: if(delay_count==0) begin
                    initialized<=1; refresh_age<=0; state<=IDLE;
                end else delay_count<=delay_count-1'b1;
                IDLE: if(refresh_age>=REFRESH_LIMIT) begin
                    ras<=0; cas<=0; delay_count<=4; refresh_age<=0; state<=REFRESH;
                end else if(request) begin
                    latched_address<=address; latched_data<=data_write; latched_write<=write;
                    bank<=address[24:23]; sdram_address<=address[22:10];
                    ras<=0; delay_count<=1; state<=ACTIVE;
                end
                ACTIVE: if(delay_count==0) state<=COLUMN;
                    else delay_count<=delay_count-1'b1;
                COLUMN: begin
                    bank<=latched_address[24:23];
                    sdram_address<={2'b00,1'b1,1'b0,latched_address[9:1]};
                    cas<=0;
                    if(latched_write) begin
                        we<=0; data_dir<=1; data_out<={latched_data,latched_data};
                        dqm<=latched_address[0] ? 2'b01 : 2'b10;
                        delay_count<=4; state<=RECOVER;
                    end else begin delay_count<=3; state<=READ_WAIT; end
                end
                READ_WAIT: if(delay_count==0) begin
                    data_read<=latched_address[0] ? data_sample[15:8] : data_sample[7:0];
                    delay_count<=1; state<=RECOVER;
                end else delay_count<=delay_count-1'b1;
                RECOVER: if(delay_count==0) begin done<=1; state<=IDLE; end
                    else delay_count<=delay_count-1'b1;
                REFRESH: if(delay_count==0) state<=IDLE;
                    else delay_count<=delay_count-1'b1;
                default: state<=POWER;
            endcase
        end
    end
endmodule
