`timescale 1ns/1ps

module tb_age_tracker;

  import scheduler_pkg::*;

  localparam int unsigned NUM_REQ = 4;
  localparam int unsigned AGE_W   = 8;


  logic                 clk;
  logic                 rst_n;
  logic [NUM_REQ-1:0]   pending_i;
  logic [NUM_REQ-1:0]   serve_i;
  logic [AGE_W-1:0]     aging_threshold_i;
  logic [AGE_W-1:0]     age_o [NUM_REQ];
  logic [NUM_REQ-1:0]   starved_o;

  age_tracker #(
    .NUM_REQ(NUM_REQ),
    .AGE_W  (AGE_W)
  ) dut (
    .clk               (clk),
    .rst_n             (rst_n),
    .pending_i         (pending_i),
    .serve_i           (serve_i),
    .aging_threshold_i (aging_threshold_i),
    .age_o             (age_o),
    .starved_o         (starved_o)
  );

  always #5 clk = ~clk;

  task automatic tick;
    @(posedge clk);
    #1;
  endtask


  task automatic check_age(input int idx, input logic [AGE_W-1:0] exp);
    if (age_o[idx] !== exp) begin
      $error("age_o[%0d] exp=%0d got=%0d", idx, exp, age_o[idx]);
      $fatal;
    end
  endtask


  task automatic check_starved(input int idx, input logic exp);
    if (starved_o[idx] !== exp) begin
      $error("starved_o[%0d] exp=%0b got=%0b", idx, exp, starved_o[idx]);
      $fatal;
    end
  endtask


  initial begin
    clk = 0;
    rst_n = 0;
    pending_i = '0;
    serve_i = '0;
    aging_threshold_i = 8'd3;

    tick;
    check_age(0, 0); check_age(1, 0); check_age(2, 0); check_age(3, 0);
    check_starved(0, 0); check_starved(1, 0); check_starved(2, 0); check_starved(3, 0);

    rst_n = 1;

    //no pending, stay zero
    repeat (2) begin
      pending_i = '0;
      serve_i   = '0;
      tick;
      check_age(0, 0); check_age(1, 0); check_age(2, 0); check_age(3, 0);
      check_starved(0, 0); check_starved(1, 0); check_starved(2, 0); check_starved(3, 0);
    end

    // pending increments
    pending_i = 4'b0001;
    serve_i   = '0;
    tick; check_age(0, 1); check_starved(0, 0);
    tick; check_age(0, 2); check_starved(0, 0);
    tick; check_age(0, 3); check_starved(0, 1);
    tick; check_age(0, 4); check_starved(0, 1);

    //serve clears while pending
    pending_i = 4'b0001;
    serve_i   = 4'b0001;
    tick; check_age(0, 0); check_starved(0, 0);

    // Drop pending, clear
    pending_i = '0;
    serve_i   = '0;
    tick; check_age(0, 0); check_starved(0, 0);

    // threshold 0, immediate starved when pending
    aging_threshold_i = 0;
    pending_i = 4'b0010;
    serve_i   = '0;
    #1;
    check_starved(1, 1);
    tick;
    check_age(1, 1);
    check_starved(1, 1);

    // serve without pending, zero
    pending_i = '0;
    serve_i   = 4'b0010;
    tick; check_age(1, 0); check_starved(1, 0);

    // independent per requester
    aging_threshold_i = 8'd2;
    pending_i = 4'b1010; // req1, req3
    serve_i   = '0;
    tick;
    check_age(0, 0); check_age(1, 1); check_age(2, 0); check_age(3, 1);
    check_starved(1, 0); check_starved(3, 0);

    tick;
    check_age(1, 2); check_age(3, 2);
    check_starved(1, 1); check_starved(3, 1);

    //Saturation
    aging_threshold_i = {AGE_W{1'b1}};
    pending_i = 4'b0100;
    serve_i   = '0;
    repeat ((1<<AGE_W) + 4) tick;
    check_age(2, {AGE_W{1'b1}});
    check_starved(2, 1);

    $display("tb_age_tracker PASSED");
    $finish;
  end

endmodule