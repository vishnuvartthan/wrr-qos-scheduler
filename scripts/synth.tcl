
set_db init_lib_search_path ref/models
set_db library saed32hvt_tt1p05v25c.lib

set_db init_hdl_search_path {. ./rtl }

read_hdl {scheduler_pkg.sv req_fifo.sv age_tracker.sv wrr_arbiter.sv scheduler_core.sv csr_regs.sv status_counters.sv scheduler_top.sv }

elaborate scheduler_top
read_sdc .scripts/constraints.sdc

syn_generic
syn_map
syn_opt

report_timing > synth/reports/timing.rpt
report_timing -max_paths 10 > synth/reports/timing.rpt
report_area > synth/reports/area.rpt
report_power > synth/reports/power.rpt
report_qor > synth/reports/qor.rpt

write_hdl > synth/netlist/scheduler_top_syn.v
write_sdc > synth/netlist/scheduler_top_syn.sdc


exit