// SPDX-License-Identifier: GPL-3.0-or-later
module gg_clocks #(parameter integer DISPLAY_DIVIDER=38)(
    input wire clock_50m,output wire system_clock,display_clock,spi_clock,locked);
    wire feedback,feedback_buffered,raw_system,raw_display,raw_spi;
    MMCME2_BASE #(.BANDWIDTH("OPTIMIZED"),.CLKIN1_PERIOD(20.0),
        .CLKFBOUT_MULT_F(20.0),.DIVCLK_DIVIDE(1),.CLKOUT0_DIVIDE_F(18.625),
        .CLKOUT1_DIVIDE(DISPLAY_DIVIDER),.CLKOUT2_DIVIDE(5),.STARTUP_WAIT("FALSE"))
    mmcm(.CLKIN1(clock_50m),.CLKFBIN(feedback_buffered),.CLKFBOUT(feedback),
        .CLKOUT0(raw_system),.CLKOUT1(raw_display),.CLKOUT2(raw_spi),
        .LOCKED(locked),.PWRDWN(1'b0),.RST(1'b0));
    BUFG feedback_buf(.I(feedback),.O(feedback_buffered));
    BUFG system_buf(.I(raw_system),.O(system_clock));
    // The framework's DPI/HDMI BUFGMUX supplies the final display buffer.
    assign display_clock=raw_display;
    BUFG spi_buf(.I(raw_spi),.O(spi_clock));
endmodule
