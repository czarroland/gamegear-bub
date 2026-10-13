// SPDX-License-Identifier: GPL-3.0-or-later
module gg_enables(input wire clk, input wire reset,
    output reg ce_cpu=0, ce_vdp=0, ce_pix=0, ce_sp=0);
    reg [4:0] phase = 0;
    always @(negedge clk) begin
        if (reset) begin
            phase <= 0;
            ce_cpu <= 0; ce_vdp <= 0; ce_pix <= 0; ce_sp <= 0;
        end else begin
            phase <= phase == 29 ? 0 : phase + 1'b1;
            ce_vdp <= phase == 4 || phase == 9 || phase == 14 ||
                      phase == 19 || phase == 24 || phase == 29;
            ce_pix <= phase == 9 || phase == 19 || phase == 29;
            ce_cpu <= phase == 9 || phase == 24;
            ce_sp <= phase[0];
        end
    end
endmodule
