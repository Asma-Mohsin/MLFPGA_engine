###############################################################################
# Created by write_sdc
###############################################################################
current_design act_bank_container
###############################################################################
# Timing Constraints
###############################################################################
create_clock -name clk_i -period 10.0000 [get_ports {clk_i}]
set_clock_transition 0.1500 [get_clocks {clk_i}]
set_clock_uncertainty 0.2500 clk_i
set_propagated_clock [get_clocks {clk_i}]
###############################################################################
# Environment
###############################################################################
set_load -pin_load 0.0060 [get_ports {clk_o}]
set_load -pin_load 0.0060 [get_ports {weight_shift_en_east}]
set_load -pin_load 0.0060 [get_ports {act_rdata_east[7]}]
set_load -pin_load 0.0060 [get_ports {act_rdata_east[6]}]
set_load -pin_load 0.0060 [get_ports {act_rdata_east[5]}]
set_load -pin_load 0.0060 [get_ports {act_rdata_east[4]}]
set_load -pin_load 0.0060 [get_ports {act_rdata_east[3]}]
set_load -pin_load 0.0060 [get_ports {act_rdata_east[2]}]
set_load -pin_load 0.0060 [get_ports {act_rdata_east[1]}]
set_load -pin_load 0.0060 [get_ports {act_rdata_east[0]}]
set_load -pin_load 0.0060 [get_ports {act_rdata_west[7]}]
set_load -pin_load 0.0060 [get_ports {act_rdata_west[6]}]
set_load -pin_load 0.0060 [get_ports {act_rdata_west[5]}]
set_load -pin_load 0.0060 [get_ports {act_rdata_west[4]}]
set_load -pin_load 0.0060 [get_ports {act_rdata_west[3]}]
set_load -pin_load 0.0060 [get_ports {act_rdata_west[2]}]
set_load -pin_load 0.0060 [get_ports {act_rdata_west[1]}]
set_load -pin_load 0.0060 [get_ports {act_rdata_west[0]}]
set_load -pin_load 0.0060 [get_ports {out_act_west[7]}]
set_load -pin_load 0.0060 [get_ports {out_act_west[6]}]
set_load -pin_load 0.0060 [get_ports {out_act_west[5]}]
set_load -pin_load 0.0060 [get_ports {out_act_west[4]}]
set_load -pin_load 0.0060 [get_ports {out_act_west[3]}]
set_load -pin_load 0.0060 [get_ports {out_act_west[2]}]
set_load -pin_load 0.0060 [get_ports {out_act_west[1]}]
set_load -pin_load 0.0060 [get_ports {out_act_west[0]}]
set_load -pin_load 0.0060 [get_ports {weight_in_east[7]}]
set_load -pin_load 0.0060 [get_ports {weight_in_east[6]}]
set_load -pin_load 0.0060 [get_ports {weight_in_east[5]}]
set_load -pin_load 0.0060 [get_ports {weight_in_east[4]}]
set_load -pin_load 0.0060 [get_ports {weight_in_east[3]}]
set_load -pin_load 0.0060 [get_ports {weight_in_east[2]}]
set_load -pin_load 0.0060 [get_ports {weight_in_east[1]}]
set_load -pin_load 0.0060 [get_ports {weight_in_east[0]}]
set_load -pin_load 0.0060 [get_ports {xbar_sel_east[3]}]
set_load -pin_load 0.0060 [get_ports {xbar_sel_east[2]}]
set_load -pin_load 0.0060 [get_ports {xbar_sel_east[1]}]
set_load -pin_load 0.0060 [get_ports {xbar_sel_east[0]}]
set_timing_derate -early 0.9500
set_timing_derate -late 1.0500
###############################################################################
# Design Rules
###############################################################################
set_max_fanout 10.0000 [current_design]
