`timescale 1ns/1ps

module tb_wrr_arbiter;

  import scheduler_pkg::*;

  localparam int unsigned NUM_REQ   = 4;
  localparam int unsigned WEIGHT_W  = 4;
  localparam int unsigned REQ_IDX_W = (NUM_REQ <= 1) ? 1 : $clog2(NUM_REQ);

  logic                     clk;
  logic                     rst_n;
  logic [NUM_REQ-1:0]       eligible_i;
  logic [WEIGHT_W-1:0]      weight_i [NUM_REQ];
  logic                     advance_i;
  logic                     grant_valid_o;
  logic [REQ_IDX_W-1:0]     grant_idx_o;
  logic [NUM_REQ-1:0]       grant_onehot_o;

  int unsigned grant_hist [NUM_REQ];

  wrr_arbiter #(
    .NUM_REQ   (NUM_REQ),
    .WEIGHT_W  (WEIGHT_W),
    .REQ_IDX_W (REQ_IDX_W)
  ) dut (
    .clk            (clk),
    .rst_n          (rst_n),
    .eligible_i     (eligible_i),
    .weight_i       (weight_i),
    .advance_i      (advance_i),
    .grant_valid_o  (grant_valid_o),
    .grant_idx_o    (grant_idx_o),
    .grant_onehot_o (grant_onehot_o)
  );

  always #5 clk = ~clk;

  task automatic reset_dut();
    clk        = 1'b0;
    rst_n      = 1'b0;
    eligible_i = '0;
    advance_i  = 1'b0;
    for (int i = 0; i < NUM_REQ; i++) begin
      weight_i[i]   = 4'd1;
      grant_hist[i] = 0;
    end
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);
  endtask

  task automatic clear_hist();
    for (int i = 0; i < NUM_REQ; i++) grant_hist[i] = 0;
  endtask

  task automatic sample_and_advance(int cycles);
    for (int c = 0; c < cycles; c++) begin
      @(negedge clk);
      advance_i = grant_valid_o;
      @(posedge clk);
      if (grant_valid_o) begin
        grant_hist[grant_idx_o]++;
      end
    end
    @(negedge clk);
    advance_i = 1'b0;
  endtask

  task automatic check_onehot();
    if (grant_valid_o) begin
      if (!$onehot(grant_onehot_o)) begin
        $error("grant_onehot_o not onehot when grant_valid_o=1: %b", grant_onehot_o);
        $fatal;
      end
      if (!grant_onehot_o[grant_idx_o]) begin
        $error("grant_idx_o does not match grant_onehot_o");
        $fatal;
      end
    end else begin
      if (grant_onehot_o != '0) begin
        $error("grant_onehot_o should be zero when grant_valid_o=0");
        $fatal;
      end
    end
  endtask

  task automatic test_no_eligible();
    eligible_i = '0;
    repeat (4) begin
      @(posedge clk);
      check_onehot();
      if (grant_valid_o) begin
        $error("Expected no grant when no requesters are eligible");
        $fatal;
      end
    end
    $display("[PASS] no eligible");
  endtask

  task automatic test_single_requester();
    eligible_i = 4'b0100;
    weight_i[0] = 4'd1;
    weight_i[1] = 4'd1;
    weight_i[2] = 4'd3;
    weight_i[3] = 4'd1;

    repeat (8) begin
      @(posedge clk);
      check_onehot();
      if (!grant_valid_o || grant_idx_o != 2) begin
        $error("Single requester test failed. valid=%0b idx=%0d", grant_valid_o, grant_idx_o);
        $fatal;
      end
      @(negedge clk);
      advance_i = 1'b1;
    end
    @(negedge clk);
    advance_i = 1'b0;
    $display("[PASS] single requester");
  endtask

    task automatic test_equal_weights_rr();
        clear_hist();

        eligible_i = 4'b1111;
        for (int i = 0; i < NUM_REQ; i++) weight_i[i] = 4'd1;

        sample_and_advance(16);

        if (grant_hist[0] != 4 ||
            grant_hist[1] != 4 ||
            grant_hist[2] != 4 ||
            grant_hist[3] != 4) begin
            $error("Equal-weight distribution failed. got=%0d,%0d,%0d,%0d",
                grant_hist[0], grant_hist[1], grant_hist[2], grant_hist[3]);
            $fatal;
        end

        $display("[PASS] equal weights distribution");
    endtask

  task automatic test_weighted_distribution();
    clear_hist();
    eligible_i = 4'b1111;
    weight_i[0] = 4'd4;
    weight_i[1] = 4'd2;
    weight_i[2] = 4'd1;
    weight_i[3] = 4'd1;

    sample_and_advance(32);

    if (grant_hist[0] != 16 || grant_hist[1] != 8 ||
        grant_hist[2] != 4  || grant_hist[3] != 4) begin
      $error("Weighted distribution failed. got=%0d,%0d,%0d,%0d",
             grant_hist[0], grant_hist[1], grant_hist[2], grant_hist[3]);
      $fatal;
    end
    $display("[PASS] weighted distribution");
  endtask

  task automatic test_weight_zero_never_served();
    clear_hist();
    eligible_i = 4'b1111;
    weight_i[0] = 4'd2;
    weight_i[1] = 4'd0;
    weight_i[2] = 4'd1;
    weight_i[3] = 4'd1;

    sample_and_advance(24);

    if (grant_hist[1] != 0) begin
      $error("Weight-zero requester was served");
      $fatal;
    end
    $display("[PASS] weight zero requester never served");
  endtask

    task automatic test_no_state_advance_without_advance_i();
    logic [REQ_IDX_W-1:0] first_idx;

    eligible_i = 4'b1111;
    for (int i = 0; i < NUM_REQ; i++) weight_i[i] = 4'd1;

    @(posedge clk);
    check_onehot();
    first_idx = grant_idx_o;

    repeat (4) begin
        @(posedge clk);
        check_onehot();
        if (grant_idx_o != first_idx) begin
        $error("Grant changed without advance_i. first=%0d now=%0d",
                first_idx, grant_idx_o);
        $fatal;
        end
    end
    $display("[PASS] no state advance without advance_i");
    endtask

  task automatic test_drop_eligibility_mid_round();
    clear_hist();
    eligible_i = 4'b1111;
    weight_i[0] = 4'd2;
    weight_i[1] = 4'd2;
    weight_i[2] = 4'd1;
    weight_i[3] = 4'd1;

    sample_and_advance(3);

    eligible_i[1] = 1'b0;
    sample_and_advance(12);

    if (grant_hist[1] == 0) begin
      // okay if it already got none after the drop point, no action
    end


    repeat (6) begin
      @(posedge clk);
      check_onehot();
      if (grant_valid_o && grant_idx_o == 1) begin
        $error("Ineligible requester 1 was granted");
        $fatal;
      end
      @(negedge clk);
      advance_i = grant_valid_o;
    end
    @(negedge clk);
    advance_i = 1'b0;

    $display("[PASS] drop eligibility mid-round");
  endtask

  task automatic test_all_active_sanity();
    eligible_i = 4'b1111;
    weight_i[0] = 4'd3;
    weight_i[1] = 4'd1;
    weight_i[2] = 4'd2;
    weight_i[3] = 4'd1;

    repeat (20) begin
      @(posedge clk);
      check_onehot();
      if (!grant_valid_o) begin
        $error("Expected valid grant with all requesters active");
        $fatal;
      end
      if (!eligible_i[grant_idx_o]) begin
        $error("Granted requester is not eligible");
        $fatal;
      end
      if (weight_i[grant_idx_o] == '0) begin
        $error("Granted requester has zero weight");
        $fatal;
      end
      @(negedge clk);
      advance_i = 1'b1;
    end
    @(negedge clk);
    advance_i = 1'b0;
    $display("[PASS] all active sanity");
  endtask
  

  initial begin
    reset_dut();

    test_no_eligible();

    reset_dut();
    test_single_requester();

    reset_dut();
    test_equal_weights_rr();

    reset_dut();
    test_weighted_distribution();

    reset_dut();
    test_weight_zero_never_served();

    reset_dut();
    test_no_state_advance_without_advance_i();

    reset_dut();
    test_drop_eligibility_mid_round();

    reset_dut();
    test_all_active_sanity();

    $display("ALL WRR ARBITER TESTS PASSED");
    $finish;
  end

endmodule