`timescale 1ns/1ps

module tb_status_counters;

  import scheduler_pkg::*;

  localparam int unsigned NUM_REQ    = 4;
  localparam int unsigned COUNTER_W  = 32;
  localparam int unsigned REQ_IDX_W  = (NUM_REQ <= 1) ? 1 : $clog2(NUM_REQ);

  logic                         clk;
  logic                         rst_n;
  logic                         fire_i;
  logic [NUM_REQ-1:0]           serve_i;
  logic                         out_valid_i;
  logic                         out_ready_i;
  logic                         age_override_fire_i;
  logic [COUNTER_W-1:0]         grant_count_o [NUM_REQ];
  logic [COUNTER_W-1:0]         stall_count_o;
  logic [COUNTER_W-1:0]         starve_hit_count_o;

  status_counters #(
    .NUM_REQ   (NUM_REQ),
    .COUNTER_W (COUNTER_W),
    .REQ_IDX_W (REQ_IDX_W)
  ) dut (
    .clk                 (clk),
    .rst_n               (rst_n),
    .fire_i              (fire_i),
    .serve_i             (serve_i),
    .out_valid_i         (out_valid_i),
    .out_ready_i         (out_ready_i),
    .age_override_fire_i (age_override_fire_i),
    .grant_count_o       (grant_count_o),
    .stall_count_o       (stall_count_o),
    .starve_hit_count_o  (starve_hit_count_o)
  );

  always #5 clk = ~clk;


  task automatic clear_inputs();
    fire_i              = 1'b0;
    serve_i             = '0;
    out_valid_i         = 1'b0;
    out_ready_i         = 1'b0;
    age_override_fire_i = 1'b0;
  endtask


  task automatic check_grant_counts(
    input logic [COUNTER_W-1:0] exp0,
    input logic [COUNTER_W-1:0] exp1,
    input logic [COUNTER_W-1:0] exp2,
    input logic [COUNTER_W-1:0] exp3
  );
    if (grant_count_o[0] !== exp0) $fatal(1, "grant_count_o[0] exp=%0d got=%0d", exp0, grant_count_o[0]);
    if (grant_count_o[1] !== exp1) $fatal(1, "grant_count_o[1] exp=%0d got=%0d", exp1, grant_count_o[1]);
    if (grant_count_o[2] !== exp2) $fatal(1, "grant_count_o[2] exp=%0d got=%0d", exp2, grant_count_o[2]);
    if (grant_count_o[3] !== exp3) $fatal(1, "grant_count_o[3] exp=%0d got=%0d", exp3, grant_count_o[3]);
  endtask


  task automatic check_stall_count(input logic [COUNTER_W-1:0] exp);
    if (stall_count_o !== exp) $fatal(1, "stall_count_o exp=%0d got=%0d", exp, stall_count_o);
  endtask

  task automatic check_starve_count(input logic [COUNTER_W-1:0] exp);
    if (starve_hit_count_o !== exp) $fatal(1, "starve_hit_count_o exp=%0d got=%0d", exp, starve_hit_count_o);
  endtask


  initial begin
    clk = 1'b0;
    clear_inputs();

    rst_n = 1'b0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    check_grant_counts(0, 0, 0, 0);
    check_stall_count(0);
    check_starve_count(0);


    // Basic grant count
    fire_i  = 1'b1;
    serve_i = 4'b0001;
    @(posedge clk);
    clear_inputs();
    @(posedge clk);
    check_grant_counts(1, 0, 0, 0);
    check_stall_count(0);
    check_starve_count(0);

    // another requester grant
    fire_i  = 1'b1;
    serve_i = 4'b0100;
    @(posedge clk);
    clear_inputs();
    @(posedge clk);
    check_grant_counts(1, 0, 1, 0);

    // No fire -> no grant count even if serve_i toggles
    serve_i = 4'b0010;
    @(posedge clk);
    clear_inputs();
    @(posedge clk);
    check_grant_counts(1, 0, 1, 0);


    // stall count increments per blocked cycle
    out_valid_i = 1'b1;
    out_ready_i = 1'b0;
    repeat (3) @(posedge clk);
    clear_inputs();
    @(posedge clk);
    check_stall_count(3);

    // No stall increment if ready is high
    out_valid_i = 1'b1;
    out_ready_i = 1'b1;
    repeat (2) @(posedge clk);
    clear_inputs();
    @(posedge clk);
    check_stall_count(3);


    // starvation prevention service count
    age_override_fire_i = 1'b1;
    @(posedge clk);
    clear_inputs();
    @(posedge clk);
    check_starve_count(1);

    // Simultaneous grant, stall, age override
    fire_i              = 1'b1;
    serve_i             = 4'b1000;
    out_valid_i         = 1'b1;
    out_ready_i         = 1'b0;
    age_override_fire_i = 1'b1;
    @(posedge clk);
    clear_inputs();
    @(posedge clk);

    check_grant_counts(1, 0, 1, 1);
    check_stall_count(4);
    check_starve_count(2);

    $display("tb_status_counters PASSED");
    $finish;
  end

endmodule