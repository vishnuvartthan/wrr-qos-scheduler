`timescale 1ns/1ps

module scheduler_top import scheduler_pkg::*; #(
  parameter int unsigned NUM_REQ       = 4,
  parameter int unsigned REQ_W         = 32,
  parameter int unsigned FIFO_DEPTH    = 4,
  parameter int unsigned WEIGHT_W      = 4,
  parameter int unsigned AGE_W         = 8,
  parameter int unsigned COUNTER_W     = 32,
  parameter int unsigned ADDR_W        = 8,
  parameter int unsigned DATA_W        = 32,
  parameter int unsigned FIFO_CNT_W    = (FIFO_DEPTH <= 1) ? 1 : $clog2(FIFO_DEPTH + 1),
  parameter int unsigned REQ_IDX_W     = (NUM_REQ <= 1) ? 1 : $clog2(NUM_REQ)
) (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic [NUM_REQ-1:0]    in_valid_i,
  input  logic [REQ_W-1:0]      in_data_i [NUM_REQ],
  output logic [NUM_REQ-1:0]    in_ready_o,
  output logic                  out_valid_o,
  output logic [REQ_W-1:0]      out_data_o,
  output logic [REQ_IDX_W-1:0]  out_src_idx_o,
  input  logic                  out_ready_i,
  input  logic                  csr_write_i,
  input  logic                  csr_read_i,
  input  logic [ADDR_W-1:0]     csr_addr_i,
  input  logic [DATA_W-1:0]     csr_wdata_i,
  output logic [DATA_W-1:0]     csr_rdata_o,
  output logic                  csr_ready_o
);

  logic [NUM_REQ-1:0]           fifo_push;
  logic [NUM_REQ-1:0]           fifo_pop;
  logic [REQ_W-1:0]             fifo_head_data [NUM_REQ];
  logic [NUM_REQ-1:0]           fifo_full;
  logic [NUM_REQ-1:0]           fifo_empty;
  logic [FIFO_CNT_W-1:0]        fifo_count [NUM_REQ];
  logic [NUM_REQ-1:0]           fifo_valid;

  logic [WEIGHT_W-1:0]          weight   [NUM_REQ];
  logic [AGE_W-1:0]             aging_threshold;
  logic [COUNTER_W-1:0]         grant_count [NUM_REQ];
  logic [COUNTER_W-1:0]         stall_count;
  logic [COUNTER_W-1:0]         starve_hit_count;

  logic [AGE_W-1:0]             age      [NUM_REQ];
  logic [NUM_REQ-1:0]           starved;
  logic                         wrr_grant_valid;
  logic [REQ_IDX_W-1:0]         wrr_grant_idx;
  logic [NUM_REQ-1:0]           wrr_grant_onehot;

  logic [NUM_REQ-1:0]           pending;
  logic [NUM_REQ-1:0]           serve;
  logic [NUM_REQ-1:0]           wrr_eligible;
  logic                         wrr_advance;

  logic                         selected_from_age_override;
  logic                         fire;
  //logic                         age_override_selected;
  logic                         age_override_fire;




  for (genvar g = 0; g < NUM_REQ; g++) begin : gen_input_side
    assign in_ready_o[g] = !fifo_full[g];
    assign fifo_push[g]  = in_valid_i[g] && in_ready_o[g];
    assign fifo_valid[g] = !fifo_empty[g];
  end


  for (genvar g = 0; g < NUM_REQ; g++) begin : gen_req_fifo
    req_fifo #(
      .WIDTH (REQ_W),
      .DEPTH (FIFO_DEPTH),
      .CNT_W (FIFO_CNT_W)
    ) u_req_fifo (
      .clk      (clk),
      .rst_n    (rst_n),
      .push     (fifo_push[g]),
      .push_data(in_data_i[g]),
      .pop      (fifo_pop[g]),
      .pop_data (fifo_head_data[g]),
      .full     (fifo_full[g]),
      .empty    (fifo_empty[g]),
      .count    (fifo_count[g])
    );
  end


  age_tracker #(
    .NUM_REQ (NUM_REQ),
    .AGE_W   (AGE_W)
  ) u_age_tracker (
    .clk                (clk),
    .rst_n              (rst_n),
    .pending_i          (pending),
    .serve_i            (serve),
    .aging_threshold_i  (aging_threshold),
    .age_o              (age),
    .starved_o          (starved)
  );


  wrr_arbiter #(
    .NUM_REQ   (NUM_REQ),
    .WEIGHT_W  (WEIGHT_W),
    .REQ_IDX_W (REQ_IDX_W)
  ) u_wrr_arbiter (
    .clk            (clk),
    .rst_n          (rst_n),
    .eligible_i     (wrr_eligible),
    .weight_i       (weight),
    .advance_i      (wrr_advance),
    .grant_valid_o  (wrr_grant_valid),
    .grant_idx_o    (wrr_grant_idx),
    .grant_onehot_o (wrr_grant_onehot)
  );

  scheduler_core #(
    .NUM_REQ   (NUM_REQ),
    .REQ_W     (REQ_W),
    .AGE_W     (AGE_W),
    .REQ_IDX_W (REQ_IDX_W)
  ) u_scheduler_core (
    .clk                (clk),
    .rst_n              (rst_n),
    .fifo_valid_i       (fifo_valid),
    .fifo_data_i        (fifo_head_data),
    .starved_i          (starved),
    .age_i              (age),
    .wrr_grant_valid_i  (wrr_grant_valid),
    .wrr_grant_idx_i    (wrr_grant_idx),
    .wrr_grant_onehot_i (wrr_grant_onehot),
    .out_ready_i        (out_ready_i),
    .out_valid_o        (out_valid_o),
    .out_data_o         (out_data_o),
    .out_src_idx_o      (out_src_idx_o),
    .fifo_pop_o         (fifo_pop),
    .serve_o            (serve),
    .pending_o          (pending),
    .wrr_eligible_o     (wrr_eligible),
    .wrr_advance_o      (wrr_advance),
    .selected_from_age_override_o (selected_from_age_override)
  );

  assign fire = out_valid_o && out_ready_i;

  // assign age_override_selected = fire && starved[out_src_idx_o];
  assign age_override_fire = fire && selected_from_age_override;


  status_counters #(
    .NUM_REQ   (NUM_REQ),
    .COUNTER_W (COUNTER_W),
    .REQ_IDX_W (REQ_IDX_W)
  ) u_status_counters (
    .clk                 (clk),
    .rst_n               (rst_n),
    .fire_i              (fire),
    .serve_i             (serve),
    .out_valid_i         (out_valid_o),
    .out_ready_i         (out_ready_i),
    .age_override_fire_i (age_override_fire),
    .grant_count_o       (grant_count),
    .stall_count_o       (stall_count),
    .starve_hit_count_o  (starve_hit_count)
  );


  csr_regs #(
    .NUM_REQ   (NUM_REQ),
    .WEIGHT_W  (WEIGHT_W),
    .AGE_W     (AGE_W),
    .COUNTER_W (COUNTER_W),
    .ADDR_W    (ADDR_W),
    .DATA_W    (DATA_W)
  ) u_csr_regs (
    .clk                 (clk),
    .rst_n               (rst_n),
    .csr_write_i         (csr_write_i),
    .csr_read_i          (csr_read_i),
    .csr_addr_i          (csr_addr_i),
    .csr_wdata_i         (csr_wdata_i),
    .csr_rdata_o         (csr_rdata_o),
    .csr_ready_o         (csr_ready_o),
    .weight_o            (weight),
    .aging_threshold_o   (aging_threshold),
    .fifo_full_i         (fifo_full),
    .fifo_empty_i        (fifo_empty),
    .grant_count_i       (grant_count),
    .stall_count_i       (stall_count),
    .starve_hit_count_i  (starve_hit_count)
  );

endmodule : scheduler_top