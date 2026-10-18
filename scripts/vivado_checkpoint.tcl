# Build the checked-in rev4 RTL snapshot. A routed pass may need post-route
# physical optimization with vivado_finish_route.tcl before writing a bitstream.
set root [file normalize [file join [file dirname [info script]] ..]]
set output [expr {[info exists ::env(GG_VIVADO_OUTPUT)] ? [file normalize $::env(GG_VIVADO_OUTPUT)] : [file join $root build vivado-checkpoint]}]
set generated [expr {[info exists ::env(GG_GENERATED_RTL)] ? [file normalize $::env(GG_GENERATED_RTL)] : [file join $root generated handheld_rev4]}]
set core_handle [open [file join $generated GameGearCore.sv] r]
set core_rtl [read $core_handle]
close $core_handle
if {[string first "videoScale_mode" $core_rtl] < 0} {
    error "Generated RTL is stale: regenerate HandheldTop with the videoScale interface."
}
if {[string first "videoViewport_activeWidth" $core_rtl] < 0 ||
    [string first "videoViewport_frameId" $core_rtl] < 0} {
    error "Generated RTL is stale: regenerate HandheldTop with the completed-frame viewport interface."
}
file mkdir $output
# The Apple Silicon Docker VM has 4 GiB of RAM; cap Vivado's Linux default
# thread count to avoid swapping heavily during synthesis and implementation.
set threads [expr {[info exists ::env(GG_VIVADO_THREADS)] ? $::env(GG_VIVADO_THREADS) : 2}]
if {$threads < 1 || $threads > 2} {error "GG_VIVADO_THREADS must be 1 or 2"}
set_param general.maxThreads $threads
create_project -in_memory -part xc7a100tcsg324-1
set_property XPM_LIBRARIES {XPM_CDC XPM_FIFO XPM_MEMORY} [current_project]
set_property verilog_define {BOARD_REV_4=1} [current_fileset]

set handle [open [file join $generated filelist.f] r]
foreach name [split [read $handle] \n] {
    if {[string trim $name] ne ""} {
        read_verilog -sv [file join $generated [string trim $name]]
    }
}
close $handle
foreach path [glob [file join $root rtl platform *.sv] [file join $root rtl generated jt89 *.v]] {
    read_verilog -sv $path
}
foreach name {handheld/top.sv handheld/pll_reset_generator.sv handheld/clk_wiz_hdmi.v picorv32.v} {
    read_verilog -sv [file join $root framework verilog $name]
}
foreach path [glob [file join $root framework verilog hdmi src *.sv]] {read_verilog -sv $path}
foreach name {
    portable/dpram.vhdl portable/spram.vhdl generated/jt89/jt89.vhdl
    generated/T80/T80_Reg.vhdl generated/T80/T80_MCode.vhdl generated/T80/T80_ALU.vhdl
    generated/T80/T80.vhdl generated/T80/T80s.vhdl generated/vdp_sprite_shifter.vhdl
    generated/vdp_background.vhdl generated/vdp_sprites.vhdl generated/vdp_main.vhdl
    generated/vdp_cram.vhdl generated/vdp.vhdl generated/io.vhdl generated/mapper_detect.vhdl
    generated/mapper_ctrl.vhdl generated/memory_decode.vhdl generated/memory_bus.vhdl
    generated/evolution_mapper.vhdl generated/evolution_rom_address.vhdl
    generated/eeprom_93c46.vhdl generated/cart_eeprom.vhdl generated/AudioMix.vhdl
    generated/video.vhdl generated/system.vhdl platform/gamegear_machine.vhdl
} {read_vhdl -vhdl2008 [file join $root rtl $name]}
read_xdc [file join $root framework verilog handheld rev_4.xdc]
read_xdc [file join $root framework verilog handheld common.xdc]
read_xdc [file join $root rtl platform gg_sdram.xdc]
read_xdc [file join $root rtl platform gg_pal_clocks.xdc]
synth_design -top top_handheld -part xc7a100tcsg324-1
report_utilization -hierarchical -file [file join $output utilization_synth.rpt]
opt_design
place_design
phys_opt_design
route_design
report_utilization -hierarchical -file [file join $output utilization.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $output timing.rpt]
report_drc -file [file join $output drc.rpt]
check_timing -verbose -file [file join $output check_timing.rpt]
write_checkpoint -force [file join $output routed.dcp]
foreach kind {max min} {
    set paths [get_timing_paths -delay_type $kind -max_paths 1]
    if {[llength $paths]==0 || [get_property SLACK $paths]<0} {
        error "Timing failed or no constrained paths; review reports. No bitstream written."
    }
}
write_bitstream -force [file join $output GameGearCore-gamebub_rev4.bit]
puts "Review all timing/DRC/clock reports and fitted SDRAM constraints before hardware testing."
