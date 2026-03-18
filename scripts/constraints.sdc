
create_clock -name clk -period 10 [get_ports clk]

set_clock_transition -rise 0.1 [get_clocks "clk"]
set_clock_transition -fall 0.1 [get_clocks "clk"]
set_clock_uncertainty 0.01 [get_clocks clk]

set_input_delay  -max 1.0 -clock clk [remove_from_collection [all_inputs] [get_ports {clk rst_n}]]
set_output_delay -max 1.0 -clock clk [all_outputs]