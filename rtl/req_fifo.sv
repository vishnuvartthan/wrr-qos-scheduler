`timescale 1ns/1ps

module req_fifo #(
  parameter int unsigned WIDTH = 32,
  parameter int unsigned DEPTH = 4,
  parameter int unsigned CNT_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH + 1)
) (
  input  logic               clk,
  input  logic               rst_n,

  input  logic               push,
  input  logic [WIDTH-1:0]   push_data,

  input  logic               pop,
  output logic [WIDTH-1:0]   pop_data,

  output logic               full,
  output logic               empty,
  output logic [CNT_W-1:0]   count
);

  localparam int unsigned PTR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH);

  logic [WIDTH-1:0] mem [0:DEPTH-1];
  logic [PTR_W-1:0] wr_ptr, rd_ptr;

  logic do_push, do_pop;

  assign full    = (count == DEPTH);
  assign empty   = (count == 0);
  assign do_pop  = pop  && !empty;
  assign do_push = push && (!full || do_pop);             // replaced push && !full

  assign pop_data = mem[rd_ptr];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr <= '0;
      rd_ptr <= '0;
      count  <= '0;
    end else begin
      if (do_push) begin
        mem[wr_ptr] <= push_data;
        if (wr_ptr == DEPTH-1) begin
          wr_ptr <= '0;
        end else begin
          wr_ptr <= wr_ptr + 1'b1;
        end
      end

      if (do_pop) begin
        if (rd_ptr == DEPTH-1) begin
          rd_ptr <= '0;
        end else begin
          rd_ptr <= rd_ptr + 1'b1;
        end
      end

      unique case ({do_push, do_pop})
        2'b10: count <= count + 1'b1;
        2'b01: count <= count - 1'b1;
        default: count <= count;
      endcase
    end
  end

endmodule : req_fifo
