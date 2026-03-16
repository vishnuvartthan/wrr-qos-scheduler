`timescale 1ns/1ps

module status_counters import qos_sched_pkg::*; #(
  parameter int unsigned NUM_REQ    = 4,
  parameter int unsigned COUNTER_W  = 32,
  parameter int unsigned REQ_IDX_W  = (NUM_REQ <= 1) ? 1 : $clog2(NUM_REQ)
) (
  input  logic                         clk,
  input  logic                         rst_n,
  input  logic                         fire_i,
  input  logic [NUM_REQ-1:0]           serve_i,
  input  logic                         out_valid_i,
  input  logic                         out_ready_i,
  input  logic                         age_override_fire_i,

  output logic [COUNTER_W-1:0]         grant_count_o [NUM_REQ],
  output logic [COUNTER_W-1:0]         stall_count_o,
  output logic [COUNTER_W-1:0]         starve_hit_count_o
);

  logic [COUNTER_W-1:0] grant_count_q [NUM_REQ];
  logic [COUNTER_W-1:0] stall_count_q;
  logic [COUNTER_W-1:0] starve_hit_count_q;

  function automatic logic [COUNTER_W-1:0] sat_inc (
    input logic [COUNTER_W-1:0] val
  );
    if (&val) sat_inc = val;
    else      sat_inc = val + 1'b1;
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin : counter_ff
    if (!rst_n) begin
      for (int i = 0; i < NUM_REQ; i++) begin
        grant_count_q[i] <= '0;
      end
      stall_count_q      <= '0;
      starve_hit_count_q <= '0;
    end else begin
    
      for (int i = 0; i < NUM_REQ; i++) begin
        if (fire_i && serve_i[i]) begin
          grant_count_q[i] <= sat_inc(grant_count_q[i]);
        end
      end

      // Count where output blocked by downstream backpressure
      if (out_valid_i && !out_ready_i) begin
        stall_count_q <= sat_inc(stall_count_q);
      end

      // count success happened due to aging override
      if (age_override_fire_i) begin
        starve_hit_count_q <= sat_inc(starve_hit_count_q);
      end
    end
  end

  for (genvar g = 0; g < NUM_REQ; g++) begin : gen_grant_out
    assign grant_count_o[g] = grant_count_q[g];
  end

  assign stall_count_o      = stall_count_q;
  assign starve_hit_count_o = starve_hit_count_q;

endmodule : status_counters