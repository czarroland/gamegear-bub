// SPDX-License-Identifier: GPL-3.0-or-later
// The upstream SMS NMI is edge triggered. Hold its active-low input for one
// accepted Start press, and require a release after every context change.
module sms_pause_guard(
    input wire clk,reset,machine_sms,running,focus,freeze,console_reset,
    input wire start_pressed,
    output wire pause_pressed
);
    reg armed=0,accepted=0;
    wire eligible=machine_sms && running && focus && !freeze && !console_reset;
    assign pause_pressed=!reset && eligible && accepted;
    always @(posedge clk) begin
        if(reset || !eligible) begin
            armed<=0;
            accepted<=0;
        end else if(!start_pressed) begin
            armed<=1;
            accepted<=0;
        end else if(armed) accepted<=1;
    end
endmodule
