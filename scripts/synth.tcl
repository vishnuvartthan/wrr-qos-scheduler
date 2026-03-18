set_db init_lib_search_path <USER_LIB_PATH>
set_db init_hdl_search_path <USER_HDL_PATH>

read_libs read_libs <USER_STD_CELL_LIB>

read_hdl -sv {scheduler_pkg.sv req_fifo.sv age_tracker.sv wrr_arbiter.sv scheduler_core.sv csr_regs.sv status_counters.sv scheduler_top.sv }

elaborate scheduler_top
read_sdc ../scripts/constraints.sdc

syn_generic
syn_map
syn_opt

report_timing > reports/timing.rpt
report_area > reports/area.rpt
report_power > reports/power.rpt
report_qor > reports/qor.rpt

write_hdl > outputs/scheduler_netlist.v
write_sdc > outputs/scheduler_sdc.sdc
write_sdf -timescale ns -nonegchecks -recrem split -edges check_edge -setuphold split > outputs/delays.sdf

exit