`timescale 1ns/1ps

module tb_scheduler_core;

  import scheduler_pkg::*;

  localparam int unsigned NUM_REQ_L   = 4;
  localparam int unsigned REQ_W_L     = 32;
  localparam int unsigned AGE_W_L     = 8;
  localparam int unsigned REQ_IDX_W_L = 2;

  logic                         clk;
  logic                         rst_n;
  logic [NUM_REQ_L-1:0]         fifo_valid_i;
  logic [REQ_W_L-1:0]           fifo_data_i [NUM_REQ_L];
  logic [NUM_REQ_L-1:0]         starved_i;
  logic [AGE_W_L-1:0]           age_i [NUM_REQ_L];
  logic                         wrr_grant_valid_i;
  logic [REQ_IDX_W_L-1:0]       wrr_grant_idx_i;
  logic [NUM_REQ_L-1:0]         wrr_grant_onehot_i;
  logic                         out_ready_i;
  logic                         out_valid_o;
  logic [REQ_W_L-1:0]           out_data_o;
  logic [REQ_IDX_W_L-1:0]       out_src_idx_o;
  logic [NUM_REQ_L-1:0]         fifo_pop_o;
  logic [NUM_REQ_L-1:0]         serve_o;
  logic [NUM_REQ_L-1:0]         pending_o;
  logic [NUM_REQ_L-1:0]         wrr_eligible_o;
  logic                         wrr_advance_o;
  logic                         selected_from_age_override_o;

  scheduler_core #(
    .NUM_REQ   (NUM_REQ_L),
    .REQ_W     (REQ_W_L),
    .AGE_W     (AGE_W_L),
    .REQ_IDX_W (REQ_IDX_W_L)
  ) dut (
    .clk                         (clk),
    .rst_n                       (rst_n),
    .fifo_valid_i                (fifo_valid_i),
    .fifo_data_i                 (fifo_data_i),
    .starved_i                   (starved_i),
    .age_i                       (age_i),
    .wrr_grant_valid_i           (wrr_grant_valid_i),
    .wrr_grant_idx_i             (wrr_grant_idx_i),
    .wrr_grant_onehot_i          (wrr_grant_onehot_i),
    .out_ready_i                 (out_ready_i),
    .out_valid_o                 (out_valid_o),
    .out_data_o                  (out_data_o),
    .out_src_idx_o               (out_src_idx_o),
    .fifo_pop_o                  (fifo_pop_o),
    .serve_o                     (serve_o),
    .pending_o                   (pending_o),
    .wrr_eligible_o              (wrr_eligible_o),
    .wrr_advance_o               (wrr_advance_o),
    .selected_from_age_override_o(selected_from_age_override_o)
  );

  always #5 clk = ~clk;

  task automatic clear_inputs();
    fifo_valid_i        = '0;
    starved_i           = '0;
    wrr_grant_valid_i   = 1'b0;
    wrr_grant_idx_i     = '0;
    wrr_grant_onehot_i  = '0;

    for (int i = 0; i < NUM_REQ_L; i++) begin
      fifo_data_i[i] = '0;
      age_i[i]       = '0;
    end
  endtask

  task automatic reset_dut();
    clear_inputs();
    out_ready_i = 1'b1;
    rst_n = 1'b0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
  endtask

  task automatic testcase_reset();
    clear_inputs();
    out_ready_i = 1'b1;
    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
    #1;
    if (dut.hold_q !== 1'b0) $fatal(1, "hold_q not cleared after testcase reset");
  endtask


  task automatic set_wrr_req(
    input int unsigned idx,
    input logic [REQ_W_L-1:0] data
  );
    fifo_valid_i[idx]       = 1'b1;
    fifo_data_i[idx]        = data;
    wrr_grant_valid_i       = 1'b1;
    wrr_grant_idx_i         = idx[REQ_IDX_W_L-1:0];
    wrr_grant_onehot_i      = '0;
    wrr_grant_onehot_i[idx] = 1'b1;
  endtask

  task automatic set_starved_req(
    input int unsigned idx,
    input logic [REQ_W_L-1:0] data,
    input logic [AGE_W_L-1:0] age
  );
    fifo_valid_i[idx] = 1'b1;
    fifo_data_i[idx]  = data;
    starved_i[idx]    = 1'b1;
    age_i[idx]        = age;
  endtask

  task automatic expect_outputs(
    input logic                    exp_valid,
    input logic [REQ_W_L-1:0]      exp_data,
    input logic [REQ_IDX_W_L-1:0]  exp_idx,
    input logic [NUM_REQ_L-1:0]    exp_pop,
    input logic [NUM_REQ_L-1:0]    exp_serve,
    input logic                    exp_wrr_adv,
    input logic                    exp_age_sel,
    input string                   msg
  );
    #1;
    if (out_valid_o !== exp_valid) $fatal(1, "%s: out_valid_o mismatch", msg);
    if (out_data_o  !== exp_data ) $fatal(1, "%s: out_data_o mismatch",  msg);
    if (out_src_idx_o !== exp_idx) $fatal(1, "%s: out_src_idx_o mismatch", msg);
    if (fifo_pop_o !== exp_pop)    $fatal(1, "%s: fifo_pop_o mismatch", msg);
    if (serve_o !== exp_serve)     $fatal(1, "%s: serve_o mismatch", msg);
    if (wrr_advance_o !== exp_wrr_adv) $fatal(1, "%s: wrr_advance_o mismatch", msg);
    if (selected_from_age_override_o !== exp_age_sel)
      $fatal(1, "%s: selected_from_age_override_o mismatch", msg);
  endtask


  task automatic dump_state(input string tag);
    $display("[%0t] %s", $time, tag);
    $display("  fifo_valid_i       = %b", fifo_valid_i);
    $display("  fifo_data_i[0]     = 0x%08h", fifo_data_i[0]);
    $display("  fifo_data_i[1]     = 0x%08h", fifo_data_i[1]);
    $display("  fifo_data_i[2]     = 0x%08h", fifo_data_i[2]);
    $display("  fifo_data_i[3]     = 0x%08h", fifo_data_i[3]);
    $display("  starved_i          = %b", starved_i);
    $display("  wrr_grant_valid_i  = %b", wrr_grant_valid_i);
    $display("  wrr_grant_idx_i    = %0d", wrr_grant_idx_i);
    $display("  wrr_grant_onehot_i = %b", wrr_grant_onehot_i);
    $display("  out_ready_i        = %b", out_ready_i);
    $display("  out_valid_o        = %b", out_valid_o);
    $display("  out_data_o         = 0x%08h", out_data_o);
    $display("  out_src_idx_o      = %0d", out_src_idx_o);
    $display("  fifo_pop_o         = %b", fifo_pop_o);
    $display("  serve_o            = %b", serve_o);
    $display("  wrr_advance_o      = %b", wrr_advance_o);
    $display("  selected_from_age_override_o = %b", selected_from_age_override_o);
    $display("  dut.hold_q         = %b", dut.hold_q);
    $display("");
  endtask

  initial begin
    clk = 1'b0;
    reset_dut();

    // idle
    clear_inputs();
    out_ready_i = 1'b1;
    expect_outputs(1'b0, '0, '0, '0, '0, 1'b0, 1'b0, "idle");

    // single WRR request, ready high
    clear_inputs();
    out_ready_i = 1'b1;
    set_wrr_req(2, 32'hAAAA_0002);
    out_ready_i = 1'b1;
    expect_outputs(1'b1, 32'hAAAA_0002, 2, 4'b0100, 4'b0100, 1'b1, 1'b0, "single_wrr");
    @(posedge clk);

    //aging override beats WRR
    clear_inputs();
    out_ready_i = 1'b1;
    set_wrr_req(1, 32'hBBBB_0001);
    set_starved_req(3, 32'hCCCC_0003, 8'd20);
    out_ready_i = 1'b1;
    expect_outputs(1'b1, 32'hCCCC_0003, 3, 4'b1000, 4'b1000, 1'b0, 1'b1, "age_beats_wrr");
    @(posedge clk);

    // oldest starved wins
    clear_inputs();
    out_ready_i = 1'b1;
    set_starved_req(0, 32'h1000_0000, 8'd7);
    set_starved_req(2, 32'h2000_0000, 8'd15);
    out_ready_i = 1'b1;
    expect_outputs(1'b1, 32'h2000_0000, 2, 4'b0100, 4'b0100, 1'b0, 1'b1, "oldest_starved");
    @(posedge clk);

    // equal age tie, lower index
    clear_inputs();
    out_ready_i = 1'b1;
    set_starved_req(1, 32'h1111_1111, 8'd9);
    set_starved_req(3, 32'h3333_3333, 8'd9);
    out_ready_i = 1'b1;
    expect_outputs(1'b1, 32'h1111_1111, 1, 4'b0010, 4'b0010, 1'b0, 1'b1, "equal_age_tie");
    @(posedge clk);

    testcase_reset();


    // WRR stall hold...
    // stall entry
    clear_inputs();
    set_wrr_req(0, 32'hDEAD_BEEF);
    out_ready_i = 1'b0;
    #1;
    dump_state("wrr_hold_entry");
    expect_outputs(1'b1, 32'hDEAD_BEEF, 0, '0, '0, 1'b0, 1'b0, "wrr_hold_entry");

    // now clock it in, then change inputs underneath and verify held output
    @(posedge clk);
    #1;
    clear_inputs();
    set_wrr_req(3, 32'hFACE_CAFE);
    set_starved_req(2, 32'hCAFE_BABE, 8'd30);
    out_ready_i = 1'b0;
    #1;
    dump_state("wrr_hold_stable");
    expect_outputs(1'b1, 32'hDEAD_BEEF, 0, '0, '0, 1'b0, 1'b0, "wrr_hold_stable");

    //release hold
    out_ready_i = 1'b1;
    #1;
    dump_state("wrr_hold_release");
    expect_outputs(1'b1, 32'hDEAD_BEEF, 0, 4'b0001, 4'b0001, 1'b1, 1'b0, "wrr_hold_release");
    @(posedge clk);

    testcase_reset();


    // age override stall hold
    // stall entry
    clear_inputs();
    set_wrr_req(1, 32'h0101_0101);
    set_starved_req(2, 32'h0202_0202, 8'd40);
    out_ready_i = 1'b0;
    #1;
    dump_state("age_hold_entry");
    expect_outputs(1'b1, 32'h0202_0202, 2, '0, '0, 1'b0, 1'b1, "age_hold_entry");

    // after clock: held value must stay stable even if inputs change
    @(posedge clk);
    #1;
    clear_inputs();
    set_wrr_req(0, 32'hABCD_EF01);
    out_ready_i = 1'b0;
    #1;
    dump_state("age_hold_stable");
    expect_outputs(1'b1, 32'h0202_0202, 2, '0, '0, 1'b0, 1'b1, "age_hold_stable");

    //release hold
    out_ready_i = 1'b1;
    #1;
    dump_state("age_hold_release");
    expect_outputs(1'b1, 32'h0202_0202, 2, 4'b0100, 4'b0100, 1'b0, 1'b1, "age_hold_release");
    @(posedge clk);



    // pending and eligibility reflect fifo_valid_i
    clear_inputs();
    out_ready_i = 1'b1;
    fifo_valid_i = 4'b1010;
    #1;
    if (pending_o      !== 4'b1010) $fatal(1, "pending_o mismatch");
    if (wrr_eligible_o !== 4'b1010) $fatal(1, "wrr_eligible_o mismatch");

    $display("tb_scheduler_core PASSED");
    $finish;
  end

endmodule