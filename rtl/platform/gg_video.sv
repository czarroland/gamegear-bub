// SPDX-License-Identifier: GPL-3.0-or-later
module gg_video(input wire clk,reset,run,freeze,ce_pix,machine_sms,tv_pal,
    input wire [7:0] epoch,
    input wire [11:0] color,input wire native_hblank,native_vblank,
    output reg [3:0] red,green,blue,
    output reg data_enable,hblank,vblank,
    output reg frame_complete,frame_valid,
    output reg [8:0] active_width,active_height,
    output reg [7:0] completed_epoch,
    output reg completed_machine_sms,completed_tv_pal,
    output reg [15:0] frame_id);
    reg armed=0,seen_blank=0,last_vblank=1,last_hblank=1;
    reg capturing=0,line_bad=0;
    reg [8:0] line_pixels=0,frame_rows=0;
    reg [7:0] last_epoch=0;
    reg frame_machine_sms=0,frame_tv_pal=0;
    wire [8:0] expected_width=machine_sms ? 9'd256 : 9'd160;
    wire valid_height=machine_sms ?
        (frame_rows==9'd192 || frame_rows==9'd224 || frame_rows==9'd240) :
        frame_rows==9'd144;
    always @(posedge clk) begin
        data_enable<=0;
        frame_complete<=0;
        if(reset || !run || epoch!=last_epoch) begin
            armed<=0; seen_blank<=0; last_vblank<=1; last_hblank<=1;
            capturing<=0; line_bad<=0; line_pixels<=0; frame_rows<=0;
            frame_valid<=0; active_width<=0; active_height<=0;
            completed_epoch<=epoch; completed_machine_sms<=0; completed_tv_pal<=0;
            frame_id<=0; last_epoch<=epoch;
            red<=0; green<=0; blue<=0; hblank<=1; vblank<=1;
        end else if(ce_pix && !freeze) begin
            last_vblank<=native_vblank;
            last_hblank<=native_hblank;
            if(native_vblank) seen_blank<=1;
            if(seen_blank && last_vblank && !native_vblank) begin
                armed<=1;
                capturing<=1;
                line_bad<=0;
                line_pixels<=0;
                frame_rows<=0;
                frame_machine_sms<=machine_sms;
                frame_tv_pal<=tv_pal;
            end else if(capturing) begin
                if(!native_hblank && !native_vblank) line_pixels<=line_pixels+1'b1;
                if(!last_hblank && native_hblank && line_pixels!=0) begin
                    if(line_pixels!=expected_width) line_bad<=1;
                    line_pixels<=0;
                    frame_rows<=frame_rows+1'b1;
                end
                if(!last_vblank && native_vblank) begin
                    capturing<=0;
                    if(!line_bad && line_pixels==0 && valid_height &&
                       frame_machine_sms==machine_sms && frame_tv_pal==tv_pal) begin
                        active_width<=expected_width;
                        active_height<=frame_rows;
                        completed_epoch<=epoch;
                        completed_machine_sms<=machine_sms;
                        completed_tv_pal<=tv_pal;
                        frame_id<=frame_id+1'b1;
                        frame_valid<=1;
                        frame_complete<=1;
                    end
                end
            end
            red<=color[3:0]; green<=color[7:4]; blue<=color[11:8];
            hblank<=native_hblank;
            vblank<=native_vblank || !armed;
            data_enable<=armed && !native_hblank && !native_vblank;
        end
    end
endmodule
