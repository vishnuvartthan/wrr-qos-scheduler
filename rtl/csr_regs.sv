`timescale 1ns/1ps

module csr_regs import scheduler_pkg::*; #(
  parameter int unsigned NUM_REQ      = 4,
  parameter int unsigned WEIGHT_W     = 4,
  parameter int unsigned AGE_W        = 8,
  parameter int unsigned COUNTER_W    = 32,
  parameter int unsigned ADDR_W       = 8,
  parameter int unsigned DATA_W       = 32,
  parameter logic [WEIGHT_W-1:0] RESET_WEIGHT [NUM_REQ] = '{4'd1, 4'd1, 4'd1, 4'd1},
  parameter logic [AGE_W-1:0]    RESET_AGING_THRESHOLD  = 8'd16
) (
  input  logic                         clk,
  input  logic                         rst_n,
  input  logic                         csr_write_i,
  input  logic                         csr_read_i,
  input  logic [ADDR_W-1:0]            csr_addr_i,
  input  logic [DATA_W-1:0]            csr_wdata_i,
  input  logic [NUM_REQ-1:0]           fifo_full_i,
  input  logic [NUM_REQ-1:0]           fifo_empty_i,
  input  logic [COUNTER_W-1:0]         grant_count_i [NUM_REQ],
  input  logic [COUNTER_W-1:0]         stall_count_i,
  input  logic [COUNTER_W-1:0]         starve_hit_count_i,

  output logic [DATA_W-1:0]            csr_rdata_o,
  output logic                         csr_ready_o,
  output logic [WEIGHT_W-1:0]          weight_o [NUM_REQ],
  output logic [AGE_W-1:0]             aging_threshold_o
  );

  localparam logic [ADDR_W-1:0] ADDR_WEIGHT0      = 8'h00;
  localparam logic [ADDR_W-1:0] ADDR_WEIGHT1      = 8'h04;
  localparam logic [ADDR_W-1:0] ADDR_WEIGHT2      = 8'h08;
  localparam logic [ADDR_W-1:0] ADDR_WEIGHT3      = 8'h0C;

  localparam logic [ADDR_W-1:0] ADDR_AGING_THR    = 8'h10;
  localparam logic [ADDR_W-1:0] ADDR_FIFO_STATUS  = 8'h20;
  localparam logic [ADDR_W-1:0] ADDR_GRANT_CNT0   = 8'h30;
  localparam logic [ADDR_W-1:0] ADDR_GRANT_CNT1   = 8'h34;
  localparam logic [ADDR_W-1:0] ADDR_GRANT_CNT2   = 8'h38;
  localparam logic [ADDR_W-1:0] ADDR_GRANT_CNT3   = 8'h3C;
  localparam logic [ADDR_W-1:0] ADDR_STALL_CNT    = 8'h40;
  localparam logic [ADDR_W-1:0] ADDR_STARVE_CNT   = 8'h44;

  logic [WEIGHT_W-1:0] weight_q [NUM_REQ];
  logic [AGE_W-1:0]    aging_threshold_q;

  assign csr_ready_o = 1'b1;



  always_ff @(posedge clk or negedge rst_n) begin : cfg_ff
    if (!rst_n) begin
      for (int i = 0; i < NUM_REQ; i++) begin
        weight_q[i] <= RESET_WEIGHT[i];
      end
      aging_threshold_q <= RESET_AGING_THRESHOLD;
    end else begin
      if (csr_write_i) begin
        unique case (csr_addr_i)
          ADDR_WEIGHT0: if (NUM_REQ > 0) weight_q[0] <= csr_wdata_i[WEIGHT_W-1:0];
          ADDR_WEIGHT1: if (NUM_REQ > 1) weight_q[1] <= csr_wdata_i[WEIGHT_W-1:0];
          ADDR_WEIGHT2: if (NUM_REQ > 2) weight_q[2] <= csr_wdata_i[WEIGHT_W-1:0];
          ADDR_WEIGHT3: if (NUM_REQ > 3) weight_q[3] <= csr_wdata_i[WEIGHT_W-1:0];
          ADDR_AGING_THR:                aging_threshold_q <= csr_wdata_i[AGE_W-1:0];
          default: ;
        endcase
      end
    end
  end


  for (genvar g = 0; g < NUM_REQ; g++) begin : gen_cfg_out
    assign weight_o[g] = weight_q[g];
  end
  assign aging_threshold_o = aging_threshold_q;



  always_comb begin : read_mux_comb
    csr_rdata_o = '0;

    if (csr_read_i) begin
      unique case (csr_addr_i)
        ADDR_WEIGHT0: begin
          if (NUM_REQ > 0) csr_rdata_o[WEIGHT_W-1:0] = weight_q[0];
        end

        ADDR_WEIGHT1: begin
          if (NUM_REQ > 1) csr_rdata_o[WEIGHT_W-1:0] = weight_q[1];
        end

        ADDR_WEIGHT2: begin
          if (NUM_REQ > 2) csr_rdata_o[WEIGHT_W-1:0] = weight_q[2];
        end

        ADDR_WEIGHT3: begin
          if (NUM_REQ > 3) csr_rdata_o[WEIGHT_W-1:0] = weight_q[3];
        end

        ADDR_AGING_THR: begin
          csr_rdata_o[AGE_W-1:0] = aging_threshold_q;
        end

        ADDR_FIFO_STATUS: begin
          csr_rdata_o[NUM_REQ-1:0]               = fifo_empty_i;
          csr_rdata_o[(2*NUM_REQ)-1:NUM_REQ]     = fifo_full_i;
        end

        ADDR_GRANT_CNT0: begin
          if (NUM_REQ > 0) csr_rdata_o = grant_count_i[0];
        end

        ADDR_GRANT_CNT1: begin
          if (NUM_REQ > 1) csr_rdata_o = grant_count_i[1];
        end

        ADDR_GRANT_CNT2: begin
          if (NUM_REQ > 2) csr_rdata_o = grant_count_i[2];
        end

        ADDR_GRANT_CNT3: begin
          if (NUM_REQ > 3) csr_rdata_o = grant_count_i[3];
        end

        ADDR_STALL_CNT: begin
          csr_rdata_o = stall_count_i;
        end

        ADDR_STARVE_CNT: begin
          csr_rdata_o = starve_hit_count_i;
        end

        default: begin
          csr_rdata_o = '0;
        end
      endcase
    end
  end

endmodule : csr_regs