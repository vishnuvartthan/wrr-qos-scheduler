`timescale 1ns/1ps
module wrr_arbiter import qos_sched_pkg::*; #(
  parameter int unsigned NUM_REQ   = 4,
  parameter int unsigned WEIGHT_W  = 4,
  parameter int unsigned REQ_IDX_W = (NUM_REQ <= 1) ? 1 : $clog2(NUM_REQ)
) (
  input  logic                         clk,
  input  logic                         rst_n,
  input  logic [NUM_REQ-1:0]           eligible_i,
  input  logic [WEIGHT_W-1:0]          weight_i [NUM_REQ],
  input  logic                         advance_i,

  output logic                         grant_valid_o,
  output logic [REQ_IDX_W-1:0]         grant_idx_o,
  output logic [NUM_REQ-1:0]           grant_onehot_o
);

  logic [REQ_IDX_W-1:0] wrr_ptr_q, wrr_ptr_n;
  logic [WEIGHT_W-1:0] quota_q [NUM_REQ];
  logic [WEIGHT_W-1:0] quota_n [NUM_REQ];
  logic [NUM_REQ-1:0] has_quota;
  logic [NUM_REQ-1:0] effective_quota_mask;
  logic                    reload_needed;
  logic                    sel_valid;
  logic [REQ_IDX_W-1:0]    sel_idx;
  logic [NUM_REQ-1:0]      sel_onehot;
  logic [REQ_IDX_W-1:0]    search_idx;
  logic                    found;


  always_comb begin : quota_mask_comb
    for (int i = 0; i < NUM_REQ; i++) begin
      has_quota[i] = (quota_q[i] != '0);
    end
  end

  assign effective_quota_mask = eligible_i & has_quota;
  assign reload_needed        = (effective_quota_mask == '0);


  // use current round quota if any eligible requester still has quota
  // otherwise act as if quotas are reloaded from weight_i for this decision

  always_comb begin : select_comb

    int unsigned tmp_idx;
    sel_valid  = 1'b0;
    sel_idx    = '0;
    sel_onehot = '0;
    found      = 1'b0;
    search_idx = '0;

    for (int offset = 0; offset < NUM_REQ; offset++) begin

      tmp_idx = wrr_ptr_q + offset;
      if (tmp_idx >= NUM_REQ)
        tmp_idx = tmp_idx - NUM_REQ;
      search_idx = req_idx_t'(tmp_idx);
      //search_idx = wrr_ptr_q + offset;

      if (search_idx >= NUM_REQ)
        search_idx = search_idx - NUM_REQ[REQ_IDX_W-1:0];

      if (!found) begin
        if (reload_needed) begin
          if (eligible_i[search_idx] && (weight_i[search_idx] != '0)) begin
            sel_valid            = 1'b1;
            sel_idx              = search_idx;
            sel_onehot[search_idx] = 1'b1;
            found                = 1'b1;
          end
        end else begin
          if (effective_quota_mask[search_idx]) begin
            sel_valid            = 1'b1;
            sel_idx              = search_idx;
            sel_onehot[search_idx] = 1'b1;
            found                = 1'b1;
          end
        end
      end
    end
  end

  assign grant_valid_o  = sel_valid;
  assign grant_idx_o    = sel_idx;
  assign grant_onehot_o = sel_onehot;


  always_comb begin : next_state_comb
   wrr_ptr_n = wrr_ptr_q;

    for (int i = 0; i < NUM_REQ; i++) begin
      quota_n[i] = quota_q[i];
    end

    if (advance_i && sel_valid) begin
      // if current round is exhausted, start fresh round on this consume event
      if (reload_needed) begin
        for (int i = 0; i < NUM_REQ; i++) begin
          if (eligible_i[i] && (weight_i[i] != '0)) begin
            quota_n[i] = weight_i[i];
          end else begin
            quota_n[i] = '0;
          end
        end
      end

      // consume one credit from granted requester
      if (reload_needed) begin
        quota_n[sel_idx] = weight_i[sel_idx] - 1'b1;
      end else begin
        quota_n[sel_idx] = quota_q[sel_idx] - 1'b1;
      end

      // Clear quota that are no longer eligible
      for (int i = 0; i < NUM_REQ; i++) begin
        if (!eligible_i[i]) begin
          quota_n[i] = '0;
        end
      end

      if (sel_idx == NUM_REQ-1) begin
       wrr_ptr_n = '0;
      end else begin
       wrr_ptr_n = sel_idx + 1'b1;
      end
    end else begin
      // If No consume event, keep state stable
      // clear stale quota for ineligible requesters
      for (int i = 0; i < NUM_REQ; i++) begin
        if (!eligible_i[i]) begin
          quota_n[i] = '0;
        end
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin : state_ff
    if (!rst_n) begin
     wrr_ptr_q <= '0;
      for (int i = 0; i < NUM_REQ; i++) begin
        quota_q[i] <= '0;
      end
    end else begin
     wrr_ptr_q <= wrr_ptr_n;
      for (int i = 0; i < NUM_REQ; i++) begin
        quota_q[i] <= quota_n[i];
      end
    end
  end

endmodule : wrr_arbiter