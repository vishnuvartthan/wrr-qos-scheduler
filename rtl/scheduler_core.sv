`timescale 1ns/1ps

module scheduler_core import scheduler_pkg::*; #(
  parameter int unsigned NUM_REQ   = 4,
  parameter int unsigned REQ_W     = 32,
  parameter int unsigned AGE_W     = 8,
  parameter int unsigned REQ_IDX_W = (NUM_REQ <= 1) ? 1 : $clog2(NUM_REQ)
) (
  input  logic                         clk,
  input  logic                         rst_n,
  input  logic [NUM_REQ-1:0]           fifo_valid_i,
  input  logic [REQ_W-1:0]             fifo_data_i [NUM_REQ],
  input  logic [NUM_REQ-1:0]           starved_i,
  input  logic [AGE_W-1:0]             age_i [NUM_REQ],
  input  logic                         wrr_grant_valid_i,
  input  logic [REQ_IDX_W-1:0]         wrr_grant_idx_i,
  input  logic [NUM_REQ-1:0]           wrr_grant_onehot_i,
  input  logic                         out_ready_i,
  output logic                         out_valid_o,
  output logic [REQ_W-1:0]             out_data_o,
  output logic [REQ_IDX_W-1:0]         out_src_idx_o,
  output logic [NUM_REQ-1:0]           fifo_pop_o,
  output logic [NUM_REQ-1:0]           serve_o,
  output logic [NUM_REQ-1:0]           pending_o,
  output logic [NUM_REQ-1:0]           wrr_eligible_o,
  output logic                         wrr_advance_o,
  output logic                         selected_from_age_override_o
);

  logic                         hold_q, hold_n;
  logic [REQ_W-1:0]             hold_data_q, hold_data_n;
  logic [REQ_IDX_W-1:0]         hold_idx_q, hold_idx_n;
  logic                         hold_from_wrr_q, hold_from_wrr_n;
  logic                         sel_valid;
  logic [REQ_W-1:0]             sel_data;
  logic [REQ_IDX_W-1:0]         sel_idx;
  logic [NUM_REQ-1:0]           sel_onehot;
  logic                         sel_from_wrr;
  logic                         age_override_valid;
  logic [REQ_IDX_W-1:0]         age_override_idx;
  logic [NUM_REQ-1:0]           age_override_onehot;
  logic [REQ_W-1:0]             age_override_data;
  logic                         fire;

  assign pending_o      = fifo_valid_i;
  assign wrr_eligible_o = fifo_valid_i;


  always_comb begin : age_override_comb   // oldest starved selection
    age_override_valid  = 1'b0;
    age_override_idx    = '0;
    age_override_onehot = '0;
    age_override_data   = '0;

    for (int i = 0; i < NUM_REQ; i++) begin
      if (fifo_valid_i[i] && starved_i[i]) begin
        if (!age_override_valid) begin
          age_override_valid           = 1'b1;
          age_override_idx             = req_idx_t'(i);
          age_override_onehot[i]       = 1'b1;
          age_override_data            = fifo_data_i[i];
        end else if (age_i[i] > age_i[age_override_idx]) begin
          age_override_idx             = req_idx_t'(i);
          age_override_onehot          = '0;
          age_override_onehot[i]       = 1'b1;
          age_override_data            = fifo_data_i[i];
        end
      end
    end
  end


  always_comb begin : select_comb
    sel_valid    = 1'b0;
    sel_data     = '0;
    sel_idx      = '0;
    sel_onehot   = '0;
    sel_from_wrr = 1'b0;

    if (age_override_valid) begin
      sel_valid    = 1'b1;
      sel_data     = age_override_data;
      sel_idx      = age_override_idx;
      sel_onehot   = age_override_onehot;
      sel_from_wrr = 1'b0;
    end else if (wrr_grant_valid_i) begin
      sel_valid    = 1'b1;
      sel_data     = fifo_data_i[wrr_grant_idx_i];
      sel_idx      = wrr_grant_idx_i;
      sel_onehot   = wrr_grant_onehot_i;
      sel_from_wrr = 1'b1;
    end
  end


  assign out_valid_o                  = hold_q ? 1'b1       : sel_valid;
  assign out_data_o                   = hold_q ? hold_data_q : sel_data;
  assign out_src_idx_o                = hold_q ? hold_idx_q  : sel_idx;
  assign selected_from_age_override_o = hold_q ? !hold_from_wrr_q : (sel_valid && !sel_from_wrr);
  
  assign fire = out_valid_o && out_ready_i;



  always_comb begin : handshake_comb
    fifo_pop_o     = '0;
    serve_o        = '0;
    wrr_advance_o  = 1'b0;

    if (fire) begin
      if (hold_q) begin
        fifo_pop_o[out_src_idx_o] = 1'b1;
        serve_o[out_src_idx_o]    = 1'b1;
        wrr_advance_o             = hold_from_wrr_q;
      end else begin
        fifo_pop_o[sel_idx]       = sel_valid;
        serve_o[sel_idx]          = sel_valid;
        wrr_advance_o             = sel_valid && sel_from_wrr;
      end
    end
  end


  always_comb begin : hold_next_comb
    hold_n          = hold_q;
    hold_data_n     = hold_data_q;
    hold_idx_n      = hold_idx_q;
    hold_from_wrr_n = hold_from_wrr_q;

    if (hold_q) begin
      if (out_ready_i) begin
        hold_n          = 1'b0;
        hold_data_n     = '0;
        hold_idx_n      = '0;
        hold_from_wrr_n = 1'b0;
      end
    end else begin
      if (sel_valid && !out_ready_i) begin
        hold_n          = 1'b1;
        hold_data_n     = sel_data;
        hold_idx_n      = sel_idx;
        hold_from_wrr_n = sel_from_wrr;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin : hold_ff
    if (!rst_n) begin
      hold_q          <= 1'b0;
      hold_data_q     <= '0;
      hold_idx_q      <= '0;
      hold_from_wrr_q <= 1'b0;
    end else begin
      hold_q          <= hold_n;
      hold_data_q     <= hold_data_n;
      hold_idx_q      <= hold_idx_n;
      hold_from_wrr_q <= hold_from_wrr_n;
    end
  end

endmodule : scheduler_core