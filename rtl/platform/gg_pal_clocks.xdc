# The NTSC and PAL MMCM outputs meet only at the BUFGMUX system-clock input.
# Downstream registers run from one selected output at a time. Treat the two
# mux alternatives as physically exclusive; still time each mode against its
# own system clock and retain the SDRAM and display-domain constraints.
create_generated_clock -name gg_sdram_clk_pal -add -master_clock raw_pal \
    -source [get_pins -hier -filter {NAME =~ */forward_sdram_clock/C}] \
    -divide_by 1 -invert [get_ports sdram_clk]
set_clock_groups -name exclusive_sms_ntsc_pal -physically_exclusive \
    -group [get_clocks {raw_system gg_sdram_clk}] \
    -group [get_clocks {raw_pal gg_sdram_clk_pal}]
# The SDRAM output and input budgets apply to both selected system clocks.
set_output_delay -clock gg_sdram_clk_pal -max 2.0 -add_delay \
    [get_ports {sdram_a[*] sdram_bs[*] sdram_ras_n sdram_cas_n sdram_we_n sdram_cs_n[0] sdram_cke[0] sdram_ldqm sdram_udqm sdram_dq[*]}]
set_output_delay -clock gg_sdram_clk_pal -min -1.0 -add_delay \
    [get_ports {sdram_a[*] sdram_bs[*] sdram_ras_n sdram_cas_n sdram_we_n sdram_cs_n[0] sdram_cke[0] sdram_ldqm sdram_udqm sdram_dq[*]}]
set_input_delay -clock gg_sdram_clk_pal -max 7.0 -add_delay [get_ports {sdram_dq[*]}]
set_input_delay -clock gg_sdram_clk_pal -min 1.0 -add_delay [get_ports {sdram_dq[*]}]
