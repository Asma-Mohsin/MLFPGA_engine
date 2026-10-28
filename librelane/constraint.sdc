current_design $::env(DESIGN_NAME)
set_units -time ns

create_clock -name clk_i -period $::env(CLOCK_PERIOD) [get_ports clk_i]
create_clock -name act_buffer_stage_clk3 -period $::env(CLOCK_PERIOD) \
    [get_pins {npu_inst.act_buffer_stage.gen_containers[3].container_inst/clk_o}]
create_generated_clock -name npu_compute_clk \
    -master_clock act_buffer_stage_clk3 \
    -source [get_pins {npu_inst.npu_compute_core.array_inst.cg_compute_inst.u_icg/CLK}] \
    -divide_by 1 \
    [get_pins {npu_inst.npu_compute_core.array_inst.cg_compute_inst.u_icg/GCLK}]

set_max_fanout $::env(MAX_FANOUT_CONSTRAINT) [current_design]
if { [info exists ::env(MAX_TRANSITION_CONSTRAINT)] } {
    set_max_transition $::env(MAX_TRANSITION_CONSTRAINT) [current_design]
}
if { [info exists ::env(MAX_CAPACITANCE_CONSTRAINT)] } {
    set_max_capacitance $::env(MAX_CAPACITANCE_CONSTRAINT) [current_design]
}

set_load [expr $::env(OUTPUT_CAP_LOAD) / 1000.0] [all_outputs]
set_clock_uncertainty $::env(CLOCK_UNCERTAINTY_CONSTRAINT) [all_clocks]
set_clock_transition $::env(CLOCK_TRANSITION_CONSTRAINT) [all_clocks]

set_timing_derate -early [expr 1 - $::env(TIME_DERATING_CONSTRAINT) / 100]
set_timing_derate -late [expr 1 + $::env(TIME_DERATING_CONSTRAINT) / 100]

if { [info exists ::env(OPENLANE_SDC_IDEAL_CLOCKS)] && $::env(OPENLANE_SDC_IDEAL_CLOCKS) } {
    unset_propagated_clock [all_clocks]
} else {
    set_propagated_clock [all_clocks]
}
