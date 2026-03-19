`timescale 1ns/1ps

module tb_req_fifo;

  localparam int unsigned WIDTH = 32;
  localparam int unsigned DEPTH = 4;
  localparam int unsigned CNT_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH + 1);

  logic             clk;
  logic             rst_n;
  logic             push;
  logic [WIDTH-1:0] push_data;
  logic             pop;
  logic [WIDTH-1:0] pop_data;
  logic             full;
  logic             empty;
  logic [CNT_W-1:0] count;

  req_fifo #(
    .WIDTH (WIDTH),
    .DEPTH (DEPTH),
    .CNT_W (CNT_W)
  ) dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .push     (push),
    .push_data(push_data),
    .pop      (pop),
    .pop_data (pop_data),
    .full     (full),
    .empty    (empty),
    .count    (count)
  );

  // for circular model
  logic [WIDTH-1:0] sim_mem [0:DEPTH-1];
  int unsigned head, tail, sim_count;
  int unsigned errors;

  always #5 clk = ~clk;

  task automatic check_outputs(string tag);
    begin
      if (empty !== (sim_count == 0)) $error("%s: empty mismatch", tag);
      if (full  !== (sim_count == DEPTH)) $error("%s: full mismatch", tag);
      if (count !== sim_count) $error("%s: count mismatch", tag);
      if (pop && sim_count > 0) begin
        if (pop_data !== sim_mem[head]) $error("%s: pop_data mismatch exp=0x%08x got=0x%08x", tag, sim_mem[head], pop_data);
      end
    end
  endtask

  task automatic drive_cycle(input logic push_i, input logic [WIDTH-1:0] push_data_i, input logic pop_i, input string tag);
    logic [WIDTH-1:0] popped;
    begin
      popped = (sim_count > 0 && pop_i) ? sim_mem[head] : '0;

      push      <= push_i;
      push_data <= push_data_i;
      pop       <= pop_i;
      @(posedge clk);
      #1;

      // updating simulation model like circular buffer
      if (pop_i && sim_count > 0) begin
        head = (head + 1) % DEPTH;
        sim_count -= 1;
      end
      if (push_i && (sim_count < DEPTH || pop_i)) begin
        sim_mem[tail] = push_data_i;
        tail = (tail + 1) % DEPTH;
        if (!(pop_i && sim_count == DEPTH)) sim_count += 1; // simultaneous push and pop keeps count same if full
      end

      check_outputs(tag);
    end
  endtask

  task automatic do_reset;
    begin
      rst_n = 1'b0;
      push = 0; pop = 0;
      head = 0; tail = 0; sim_count = 0;
      repeat(3) @(posedge clk);
      rst_n = 1'b1;
      @(posedge clk);
      check_outputs("after reset release");
    end
  endtask

  initial begin
    clk = 0;
    errors = 0;

    do_reset();

    // Sequential fill
    drive_cycle(1, 32'h11, 0, "push 11");
    drive_cycle(1, 32'h22, 0, "push 22");
    drive_cycle(1, 32'h33, 0, "push 33");
    drive_cycle(1, 32'h44, 0, "push 44");

    // push while full, ignored
    drive_cycle(1, 32'hDEAD_BEEF, 0, "push while full ignored");

    // Simultaneous pop+push
    drive_cycle(1, 32'h55, 1, "simultaneous pop push while full");

    // Pop sequence to test order
    drive_cycle(0, '0, 1, "pop 0");
    drive_cycle(0, '0, 1, "pop 1");

    // wraparound
    drive_cycle(1, 32'h66, 0, "push wrap 0");
    drive_cycle(1, 32'h77, 0, "push wrap 1");
    drive_cycle(0, '0, 1, "pop wrap 0");
    drive_cycle(1, 32'h88, 0, "push wrap 2");
    drive_cycle(0, '0, 1, "pop wrap 1");
    drive_cycle(0, '0, 1, "pop wrap 2");
    drive_cycle(0, '0, 1, "pop wrap 3");
    drive_cycle(0, '0, 1, "pop wrap 4 to empty");

    // pop on empty
    drive_cycle(0, '0, 1, "pop while empty ignored");

    // push & pop on empty acts like push only
    drive_cycle(1, 32'h99, 1, "push+pop on empty behaves as push");
    drive_cycle(0, '0, 1, "drain final entry");

    // quick refill or drain
    repeat(2) begin
      drive_cycle(1, 32'hA0A00001, 0, "refill 0");
      drive_cycle(1, 32'hA0A00002, 0, "refill 1");
      drive_cycle(0, '0, 1, "redrain 0");
      drive_cycle(0, '0, 1, "redrain 1");
    end

    if (errors == 0) $display("tb_req_fifo PASSED");
    else $fatal(1, "tb_req_fifo FAILED, %0d errors", errors );

    $finish;
  end

endmodule