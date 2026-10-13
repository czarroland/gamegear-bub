// SPDX-License-Identifier: GPL-3.0-or-later
module gg_video(input wire clk,reset,run,freeze,ce_pix,
    input wire [11:0] color,input wire native_hblank,native_vblank,
    output reg [3:0] red,green,blue,
    output reg data_enable,hblank,vblank);
    reg armed=0,seen_blank=0,last_vblank=1;
    always @(posedge clk) begin
        data_enable<=0;
        if(reset || !run) begin
            armed<=0; seen_blank<=0; last_vblank<=1;
            red<=0; green<=0; blue<=0; hblank<=1; vblank<=1;
        end else if(ce_pix && !freeze) begin
            last_vblank<=native_vblank;
            if(native_vblank) seen_blank<=1;
            if(seen_blank && last_vblank && !native_vblank) armed<=1;
            red<=color[3:0]; green<=color[7:4]; blue<=color[11:8];
            hblank<=native_hblank;
            vblank<=native_vblank || !armed;
            data_enable<=armed && !native_hblank && !native_vblank;
        end
    end
endmodule
