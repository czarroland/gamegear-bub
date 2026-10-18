// SPDX-License-Identifier: GPL-3.0-or-later
module gg_clocks #(parameter integer DISPLAY_DIVIDER=38)(
    input wire clock_50m,pal_mode,
    output wire system_clock,display_clock,spi_clock,locked);
    wire feedback,feedback_buffered,raw_system,raw_display,raw_spi;
    wire pal_feedback,pal_feedback_buffered,raw_pal,ntsc_locked,pal_locked;
    MMCME2_BASE #(.BANDWIDTH("OPTIMIZED"),.CLKIN1_PERIOD(20.0),
        .CLKFBOUT_MULT_F(20.0),.DIVCLK_DIVIDE(1),.CLKOUT0_DIVIDE_F(18.625),
        .CLKOUT1_DIVIDE(DISPLAY_DIVIDER),.CLKOUT2_DIVIDE(5),.STARTUP_WAIT("FALSE"))
    mmcm(.CLKIN1(clock_50m),.CLKFBIN(feedback_buffered),.CLKFBOUT(feedback),
        .CLKOUT0(raw_system),.CLKOUT1(raw_display),.CLKOUT2(raw_spi),
        .LOCKED(ntsc_locked),.PWRDWN(1'b0),.RST(1'b0));
    // 50 MHz * 20.75 / 19.5 = 53.205128 MHz, within 33 ppm of
    // MiSTer's 53.203424 MHz PAL master clock. Both MMCMs stay locked;
    // the global mux selects at a safe low phase during a profile restart.
    MMCME2_BASE #(.BANDWIDTH("OPTIMIZED"),.CLKIN1_PERIOD(20.0),
        .CLKFBOUT_MULT_F(20.75),.DIVCLK_DIVIDE(1),.CLKOUT0_DIVIDE_F(19.5),
        .STARTUP_WAIT("FALSE")) pal_mmcm(
        .CLKIN1(clock_50m),.CLKFBIN(pal_feedback_buffered),.CLKFBOUT(pal_feedback),
        .CLKOUT0(raw_pal),.LOCKED(pal_locked),.PWRDWN(1'b0),.RST(1'b0));
    BUFG feedback_buf(.I(feedback),.O(feedback_buffered));
    BUFG pal_feedback_buf(.I(pal_feedback),.O(pal_feedback_buffered));
    BUFGMUX #(.CLK_SEL_TYPE("SYNC")) system_mux(
        .I0(raw_system),.I1(raw_pal),.S(pal_mode),.O(system_clock));
    assign locked=ntsc_locked && pal_locked;
    // The framework's DPI/HDMI BUFGMUX supplies the final display buffer.
    assign display_clock=raw_display;
    BUFG spi_buf(.I(raw_spi),.O(spi_clock));
endmodule
