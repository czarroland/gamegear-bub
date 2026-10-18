# Try timing optimization on a fully routed checkpoint without weakening XDC.
set root [file normalize [file join [file dirname [info script]] ..]]
set output [expr {[info exists ::env(GG_VIVADO_OUTPUT)] ? [file normalize $::env(GG_VIVADO_OUTPUT)] : [file join $root build vivado-checkpoint]}]
set threads [expr {[info exists ::env(GG_VIVADO_THREADS)] ? $::env(GG_VIVADO_THREADS) : 2}]
if {$threads < 1 || $threads > 2} {error "GG_VIVADO_THREADS must be 1 or 2"}
set_param general.maxThreads $threads
open_checkpoint [file join $output routed.dcp]
read_xdc [file join $root rtl platform gg_pal_clocks.xdc]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $output timing_exclusive_clocks.rpt]
phys_opt_design -directive Explore
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $output timing_postroute.rpt]
report_drc -file [file join $output drc_postroute.rpt]
check_timing -verbose -file [file join $output check_timing_postroute.rpt]
foreach kind {max min} {
    set paths [get_timing_paths -delay_type $kind -max_paths 1]
    if {[llength $paths]==0 || [get_property SLACK $paths]<0} {
        error "Post-route timing failed; review reports. No bitstream written."
    }
}
write_checkpoint -force [file join $output routed-physopt.dcp]
write_bitstream -force [file join $output GameGearCore-gamebub_rev4.bit]
