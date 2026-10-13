# Provisional SDRAM I/O budgets. Verify against the fitted SDRAM and PCB skew
# before hardware release; do not mark these paths false or ignore timing.
create_generated_clock -name gg_sdram_clk -source [get_pins -hier -filter {NAME =~ */forward_sdram_clock/C}] -divide_by 1 -invert [get_ports sdram_clk]
set_output_delay -clock gg_sdram_clk -max 2.0 [get_ports {sdram_a[*] sdram_bs[*] sdram_ras_n sdram_cas_n sdram_we_n sdram_cs_n[0] sdram_cke[0] sdram_ldqm sdram_udqm sdram_dq[*]}]
set_output_delay -clock gg_sdram_clk -min -1.0 [get_ports {sdram_a[*] sdram_bs[*] sdram_ras_n sdram_cas_n sdram_we_n sdram_cs_n[0] sdram_cke[0] sdram_ldqm sdram_udqm sdram_dq[*]}]
set_input_delay -clock gg_sdram_clk -max 7.0 [get_ports {sdram_dq[*]}]
set_input_delay -clock gg_sdram_clk -min 1.0 [get_ports {sdram_dq[*]}]
