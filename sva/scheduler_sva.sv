`timescale 1ns/1ps

module scheduler_sva #(
  parameter int unsigned NUM_REQ   = 4,
  parameter int unsigned REQ_W     = 32,
  parameter int unsigned REQ_IDX_W = (NUM_REQ <= 1) ? 1 : $clog2(NUM_REQ)
) (
  input logic                     clk,
  input logic                     rst_n,
  input logic                     out_valid,
  input logic                     out_ready,
  input logic [REQ_W-1:0]         out_data,
  input logic [REQ_IDX_W-1:0]     out_src_idx,
  input logic [NUM_REQ-1:0]       fifo_pop,
  input logic [NUM_REQ-1:0]       serve
);

  // never pop unless output handshake happened
  property p_no_pop_without_handshake;
    @(posedge clk) disable iff (!rst_n)
      (|fifo_pop) |-> (out_valid && out_ready);
  endproperty

  a_no_pop_without_handshake:
    assert property (p_no_pop_without_handshake)
    else $error("SVA: fifo_pop without output handshake");


  // at most one pop in a cycle
  property p_onehot_fifo_pop;
    @(posedge clk) disable iff (!rst_n)
      $onehot0(fifo_pop);
  endproperty

  a_onehot_fifo_pop:
    assert property (p_onehot_fifo_pop)
    else $error("SVA: fifo_pop is not onehot0");


    // serve should match pop
  property p_serve_matches_pop;
    @(posedge clk) disable iff (!rst_n)
      serve == fifo_pop;
  endproperty

  a_serve_matches_pop:
    assert property (p_serve_matches_pop)
    else $error("SVA: serve and fifo_pop do not match");


  // if a pop happens, then it must be for reported source
  property p_pop_matches_out_src;
    @(posedge clk) disable iff (!rst_n)
      (out_valid && out_ready) |-> fifo_pop[out_src_idx];
  endproperty

  a_pop_matches_out_src: 
    assert property (p_pop_matches_out_src)
    else $error("SVA: popped source does not match out_src_idx");

  // hold output stable during backpressure
  property p_hold_stable_on_stall;
    @(posedge clk) disable iff (!rst_n)
      ($past(out_valid && !out_ready) && out_valid && !out_ready) |-> ($stable(out_data) && $stable(out_src_idx));
  endproperty

  a_hold_stable_on_stall:
    assert property (p_hold_stable_on_stall)
    else $error("SVA: output changed while stalled");

  // no unknowns on output if valid is high
  property p_no_x_on_valid_output;
    @(posedge clk) disable iff (!rst_n)
      out_valid |-> !$isunknown({out_data, out_src_idx});
  endproperty

  a_no_x_on_valid_output:
    assert property (p_no_x_on_valid_output)
    else $error("SVA: X/Z seen on output while valid");

  // if serve happens, it must be a real handshake
  property p_serve_only_on_handshake;
    @(posedge clk) disable iff (!rst_n)
      (|serve) |-> (out_valid && out_ready);
  endproperty

  a_serve_only_on_handshake:
    assert property (p_serve_only_on_handshake)
    else $error("SVA: serve without output handshake");

  // if handshake happens, src index should not be unknown
  property p_known_src_on_handshake;
    @(posedge clk) disable iff (!rst_n)
      (out_valid && out_ready) |-> !$isunknown(out_src_idx);
  endproperty

  a_known_src_on_handshake:
    assert property (p_known_src_on_handshake)
    else $error("SVA: unknown src index on output handshake");


endmodule