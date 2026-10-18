// SPDX-License-Identifier: GPL-3.0-or-later
// The upstream SMS NMI is edge triggered. Hold its active-low input for one
// accepted Start press, and require a release after every context change.
module sms_pause_guard #(parameter integer DEBOUNCE_CYCLES=268456)(
    input wire clk,reset,machine_sms,running,focus,freeze,console_reset,
    input wire start_pressed,
    output wire pause_pressed
);
    localparam integer COUNT_WIDTH=(DEBOUNCE_CYCLES<2) ? 1 : $clog2(DEBOUNCE_CYCLES);
    reg armed=0,accepted=0,sampled=0,synchronized=0,stable=0;
    reg [COUNT_WIDTH-1:0] change_count=0;
    wire eligible=machine_sms && running && focus && !freeze && !console_reset;
    assign pause_pressed=!reset && eligible && accepted;
    always @(posedge clk) begin
        sampled<=start_pressed;
        synchronized<=sampled;
        if(reset || !eligible) begin
            armed<=0;
            accepted<=0;
            stable<=0;
            change_count<=0;
        end else if(synchronized==stable) begin
            // Arm on a stable idle release after entering the SMS profile.
            // Without this, an initially released Start never becomes armed.
            if(!stable && !armed) begin
                if(change_count==DEBOUNCE_CYCLES-1) begin
                    armed<=1;
                    change_count<=0;
                end else change_count<=change_count+1'b1;
            end else change_count<=0;
        end else if(change_count==DEBOUNCE_CYCLES-1) begin
            stable<=synchronized;
            change_count<=0;
            if(synchronized) begin
                if(armed) accepted<=1;
            end else begin
                armed<=1;
                accepted<=0;
            end
        end else change_count<=change_count+1'b1;
    end
endmodule
