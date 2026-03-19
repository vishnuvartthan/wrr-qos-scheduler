`timescale 1ns/1ps

module tb_scheduler_top;

  import scheduler_pkg::*;

  localparam int unsigned NUM_REQ    = 4;
  localparam int unsigned REQ_W      = 32;
  localparam int unsigned FIFO_DEPTH = 4;
  localparam int unsigned WEIGHT_W   = 4;
  localparam int unsigned AGE_W      = 8;
  localparam int unsigned COUNTER_W  = 32;
  localparam int unsigned ADDR_W     = 8;
  localparam int unsigned DATA_W     = 32;
  localparam int unsigned REQ_IDX_W  = (NUM_REQ <= 1) ? 1 : $clog2(NUM_REQ);

  logic                     clk;
  logic                     rst_n;
  logic [NUM_REQ-1:0]       in_valid_i;
  logic [REQ_W-1:0]         in_data_i [NUM_REQ];
  logic [NUM_REQ-1:0]       in_ready_o;
  logic                     out_valid_o;
  logic [REQ_W-1:0]         out_data_o;
  logic [REQ_IDX_W-1:0]     out_src_idx_o;
  logic                     out_ready_i;
  logic                     csr_write_i;
  logic                     csr_read_i;
  logic [ADDR_W-1:0]        csr_addr_i;
  logic [DATA_W-1:0]        csr_wdata_i;
  logic [DATA_W-1:0]        csr_rdata_o;
  logic                     csr_ready_o;

  scheduler_top #(
    .NUM_REQ    (NUM_REQ),
    .REQ_W      (REQ_W),
    .FIFO_DEPTH (FIFO_DEPTH),
    .WEIGHT_W   (WEIGHT_W),
    .AGE_W      (AGE_W),
    .COUNTER_W  (COUNTER_W),
    .ADDR_W     (ADDR_W),
    .DATA_W     (DATA_W)
  ) dut (
    .clk         (clk),
    .rst_n       (rst_n),
    .in_valid_i  (in_valid_i),
    .in_data_i   (in_data_i),
    .in_ready_o  (in_ready_o),
    .out_valid_o (out_valid_o),
    .out_data_o  (out_data_o),
    .out_src_idx_o(out_src_idx_o),
    .out_ready_i (out_ready_i),
    .csr_write_i (csr_write_i),
    .csr_read_i  (csr_read_i),
    .csr_addr_i  (csr_addr_i),
    .csr_wdata_i (csr_wdata_i),
    .csr_rdata_o (csr_rdata_o),
    .csr_ready_o (csr_ready_o)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;


  // expected queues
  logic [REQ_W-1:0] exp_q [NUM_REQ][$];
  int unsigned pass_count;
  int unsigned fail_count;


  //CSR addresses
  localparam logic [ADDR_W-1:0] ADDR_WEIGHT0    = 8'h00;
  localparam logic [ADDR_W-1:0] ADDR_WEIGHT1    = 8'h04;
  localparam logic [ADDR_W-1:0] ADDR_WEIGHT2    = 8'h08;
  localparam logic [ADDR_W-1:0] ADDR_WEIGHT3    = 8'h0C;
  localparam logic [ADDR_W-1:0] ADDR_AGING_THR  = 8'h10;
  localparam logic [ADDR_W-1:0] ADDR_FIFO_STAT  = 8'h20;
  localparam logic [ADDR_W-1:0] ADDR_GCNT0      = 8'h30;
  localparam logic [ADDR_W-1:0] ADDR_GCNT1      = 8'h34;
  localparam logic [ADDR_W-1:0] ADDR_GCNT2      = 8'h38;
  localparam logic [ADDR_W-1:0] ADDR_GCNT3      = 8'h3C;
  localparam logic [ADDR_W-1:0] ADDR_STALL_CNT  = 8'h40;
  localparam logic [ADDR_W-1:0] ADDR_STARVE_CNT = 8'h44;


  // helpers
  task automatic reset_dut();
    rst_n       = 1'b0;
    in_valid_i  = '0;
    out_ready_i = 1'b0;
    csr_write_i = 1'b0;
    csr_read_i  = 1'b0;
    csr_addr_i  = '0;
    csr_wdata_i = '0;
    for (int i = 0; i < NUM_REQ; i++) begin
      in_data_i[i] = '0;
      exp_q[i].delete();
    end
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);
  endtask


  task automatic csr_write(
    input logic [ADDR_W-1:0] addr,
    input logic [DATA_W-1:0] data
    );
    @(posedge clk);
    csr_write_i <= 1'b1;
    csr_read_i  <= 1'b0;
    csr_addr_i  <= addr;
    csr_wdata_i <= data;
    @(posedge clk);
    csr_write_i <= 1'b0;
    csr_addr_i  <= '0;
    csr_wdata_i <= '0;
  endtask

  task automatic csr_read(
    input logic [ADDR_W-1:0] addr,
    output logic [DATA_W-1:0] data
    );
    @(posedge clk);
    csr_read_i  <= 1'b1;
    csr_write_i <= 1'b0;
    csr_addr_i  <= addr;
    @(posedge clk);
    data = csr_rdata_o;
    csr_read_i <= 1'b0;
    csr_addr_i <= '0;
  endtask


  task automatic send_req(
    input int unsigned port,
    input logic [REQ_W-1:0] data
    );
    begin
      while (!in_ready_o[port]) @(posedge clk);
      in_valid_i[port] <= 1'b1;
      in_data_i[port]  <= data;
      @(posedge clk);
      while (!(in_valid_i[port] && in_ready_o[port])) @(posedge clk);
      in_valid_i[port] <= 1'b0;
      in_data_i[port]  <= '0;
    end
  endtask



  task automatic set_weights(
    input logic [WEIGHT_W-1:0] w0,
    input logic [WEIGHT_W-1:0] w1,
    input logic [WEIGHT_W-1:0] w2,
    input logic [WEIGHT_W-1:0] w3
    );
    
    csr_write(ADDR_WEIGHT0, w0);
    csr_write(ADDR_WEIGHT1, w1);
    csr_write(ADDR_WEIGHT2, w2);
    csr_write(ADDR_WEIGHT3, w3);
  endtask

  task automatic set_aging_threshold(input logic [AGE_W-1:0] thr);
    csr_write(ADDR_AGING_THR, thr);
  endtask



  always @(posedge clk) begin
    if (rst_n) begin
      for (int p = 0; p < NUM_REQ; p++) begin
        if (in_valid_i[p] && in_ready_o[p]) begin
          exp_q[p].push_back(in_data_i[p]);
        end
      end
    end
  end

  // monitor output
  always @(posedge clk) begin
    if (rst_n && out_valid_o && out_ready_i) begin
      if (exp_q[out_src_idx_o].size() == 0) begin
        $error("Unexpected output: src=%0d data=0x%08h", out_src_idx_o, out_data_o);
        fail_count <= fail_count + 1;
      end
      else begin
        logic [REQ_W-1:0] exp_data;
        exp_data = exp_q[out_src_idx_o].pop_front();
        if (out_data_o !== exp_data) begin
          $error("Data mismatch: src=%0d exp=0x%08h got=0x%08h",
                 out_src_idx_o, exp_data, out_data_o);
          fail_count <= fail_count + 1;
        end
        else begin
          pass_count <= pass_count + 1;
        end
      end
    end
  end


  task automatic test_smoke_single_port();
    begin
      $display("[TB] smoke_single_port");
      out_ready_i = 1'b1;
      set_weights(4'd1, 4'd1, 4'd1, 4'd1);
      set_aging_threshold(8'd16);

      send_req(0, 32'h0000_0001);
      send_req(0, 32'h0000_0002);
      send_req(0, 32'h0000_0003);

      repeat (10) @(posedge clk);

      if (exp_q[0].size() != 0) begin
        $error("Smoke test failed: queue for port0 not drained");
        fail_count++;
      end
    end
  endtask


  task automatic test_backpressure_hold();
    logic [REQ_W-1:0] held_data;
    logic [REQ_IDX_W-1:0] held_src;

    begin
      $display("[TB] backpressure_hold");

      // clean setup
      out_ready_i = 1'b1;
      set_weights(4'd1, 4'd1, 4'd1, 4'd1);
      set_aging_threshold(8'd16);

      send_req(1, 32'h1111_0001);

      @(posedge clk);
      wait (out_valid_o === 1'b1);

      // stall downstream and capture held output
      out_ready_i = 1'b0;
      held_data   = out_data_o;
      held_src    = out_src_idx_o;

      repeat (5) begin
        @(posedge clk);
        if (out_valid_o !== 1'b1) begin
          $error("Backpressure test failed: out_valid dropped during stall");
          fail_count++;
        end
        if (out_data_o !== held_data) begin
          $error("Backpressure test failed: out_data changed during stall exp=0x%08h got=0x%08h",
                held_data, out_data_o);
          fail_count++;
        end
        if (out_src_idx_o !== held_src) begin
          $error("Backpressure test failed: out_src_idx changed during stall exp=%0d got=%0d",
                held_src, out_src_idx_o);
          fail_count++;
        end
      end

      // release stll and allow handshake
      out_ready_i = 1'b1;
      @(posedge clk);
      @(posedge clk);

      if (exp_q[1].size() != 0) begin
        $error("Backpressure test failed: request was not consumed after stall release");
        fail_count++;
      end
    end
  endtask



  task automatic test_wrr_ratio_basic();
    logic [DATA_W-1:0] gcnt0_before, gcnt1_before, gcnt2_before, gcnt3_before;
    logic [DATA_W-1:0] gcnt0_after,  gcnt1_after,  gcnt2_after,  gcnt3_after;
    int unsigned d0, d1, d2, d3;
    int unsigned seq0, seq1, seq2, seq3;

    begin
      $display("[TB] wrr_ratio_basic");

      out_ready_i = 1'b1;
      set_weights(4'd4, 4'd2, 4'd1, 4'd1);
      set_aging_threshold(8'd64);

      csr_read(ADDR_GCNT0, gcnt0_before);
      csr_read(ADDR_GCNT1, gcnt1_before);
      csr_read(ADDR_GCNT2, gcnt2_before);
      csr_read(ADDR_GCNT3, gcnt3_before);

      seq0 = 0; seq1 = 0; seq2 = 0; seq3 = 0;

      // To keep all ports busy for a fixed window
      repeat (120) begin
        @(posedge clk);

        if (in_ready_o[0]) begin
          in_valid_i[0] <= 1'b1;
          in_data_i[0]  <= 32'h1000_0000 + seq0;
          seq0++;
        end else begin
          in_valid_i[0] <= 1'b0;
        end

        if (in_ready_o[1]) begin
          in_valid_i[1] <= 1'b1;
          in_data_i[1]  <= 32'h2000_0000 + seq1;
          seq1++;
        end else begin
          in_valid_i[1] <= 1'b0;
        end

        if (in_ready_o[2]) begin
          in_valid_i[2] <= 1'b1;
          in_data_i[2]  <= 32'h3000_0000 + seq2;
          seq2++;
        end else begin
          in_valid_i[2] <= 1'b0;
        end

        if (in_ready_o[3]) begin
          in_valid_i[3] <= 1'b1;
          in_data_i[3]  <= 32'h4000_0000 + seq3;
          seq3++;
        end else begin
          in_valid_i[3] <= 1'b0;
        end
      end

      @(posedge clk);
      in_valid_i = '0;

      csr_read(ADDR_GCNT0, gcnt0_after);
      csr_read(ADDR_GCNT1, gcnt1_after);
      csr_read(ADDR_GCNT2, gcnt2_after);
      csr_read(ADDR_GCNT3, gcnt3_after);

      d0 = gcnt0_after - gcnt0_before;
      d1 = gcnt1_after - gcnt1_before;
      d2 = gcnt2_after - gcnt2_before;
      d3 = gcnt3_after - gcnt3_before;

      $display("[TB] grant deltas: p0=%0d p1=%0d p2=%0d p3=%0d", d0, d1, d2, d3);

      if (!(d0 > d1 && d1 >= d2 && d1 >= d3)) begin
        $error("WRR test failed: service ordering does not match weights");
        fail_count++;
      end

      if (!(d2 > 0 && d3 > 0)) begin
        $error("WRR test failed: low-weight ports made no progress");
        fail_count++;
      end
    end
  endtask

  task automatic test_aging_override_basic();
    logic [DATA_W-1:0] gcnt1_before, scnt_before;
    logic [DATA_W-1:0] gcnt1_after,  scnt_after;
    int unsigned d_g1, d_scnt;

    begin
      $display("[TB] aging_override_basic");

      out_ready_i = 1'b1;

      // port1 cannot win through normal WRR
      set_weights(4'd8, 4'd0, 4'd0, 4'd0);
      set_aging_threshold(8'd3);

      csr_read(ADDR_GCNT1, gcnt1_before);
      csr_read(ADDR_STARVE_CNT, scnt_before);

      // keep port0 busy
      fork
        begin
          for (int i = 0; i < 20; i++) begin
            send_req(0, 32'hA000_0000 + i);
          end
        end
        begin
          send_req(1, 32'hB000_0001);
          send_req(1, 32'hB000_0002);
        end
      join

      repeat (120) @(posedge clk);

      csr_read(ADDR_GCNT1, gcnt1_after);
      csr_read(ADDR_STARVE_CNT, scnt_after);

      d_g1   = gcnt1_after - gcnt1_before;
      d_scnt = scnt_after  - scnt_before;

      $display("[TB] aging deltas: g1=%0d starve=%0d", d_g1, d_scnt);

      if (d_g1 < 2) begin
        $error("Aging test failed: port1 requests were not rescued");
        fail_count++;
      end

      if (d_scnt == 0) begin
        $error("Aging test failed: starvation-prevention counter did not increment");
        fail_count++;
      end
    end
  endtask


  task automatic test_csr_counter_readback();
    logic [DATA_W-1:0] gcnt0, gcnt1, stall_cnt, starve_cnt, fifo_stat;

    begin
      $display("[TB] csr_counter_readback");

      out_ready_i = 1'b1;
      set_weights(4'd2, 4'd1, 4'd0, 4'd0);
      set_aging_threshold(8'd3);

      // create some grant activity
      send_req(0, 32'hC000_0001);
      send_req(0, 32'hC000_0002);
      send_req(1, 32'hD000_0001);

      //create few stall cycles while output is active
      wait (out_valid_o === 1'b1);
      out_ready_i = 1'b0;
      repeat (3) @(posedge clk);
      out_ready_i = 1'b1;

      repeat (20) @(posedge clk);

      csr_read(ADDR_GCNT0, gcnt0);
      csr_read(ADDR_GCNT1, gcnt1);
      csr_read(ADDR_STALL_CNT, stall_cnt);
      csr_read(ADDR_STARVE_CNT, starve_cnt);
      csr_read(ADDR_FIFO_STAT, fifo_stat);

      $display("[TB] csr counters: g0=%0d g1=%0d stall=%0d starve=%0d fifo_stat=0x%08h", gcnt0, gcnt1, stall_cnt, starve_cnt, fifo_stat);

      if (gcnt0 == 0) begin
        $error("CSR readback failed: grant count 0 is zero");
        fail_count++;
      end

      if (gcnt1 == 0) begin
        $error("CSR readback failed: grant count 1 is zero");
        fail_count++;
      end

      if (stall_cnt == 0) begin
        $error("CSR readback failed: stall counter is zero");
        fail_count++;
      end

      if (fifo_stat[NUM_REQ-1:0] != {NUM_REQ{1'b1}}) begin
        $error("CSR readback failed: not all FIFOs report empty");
        fail_count++;
      end
    end
  endtask


  task automatic test_random_stress_parallel();
    int unsigned seq[NUM_REQ];
    logic [REQ_W-1:0] data_word;

    begin
      $display("[TB] random_stress_parallel");

      out_ready_i = 1'b1;
      set_weights(4'd4, 4'd2, 4'd1, 4'd1);
      set_aging_threshold(8'd5);

      for (int p = 0; p < NUM_REQ; p++) begin
        seq[p] = 0;
        in_valid_i[p] = 1'b0;
        in_data_i[p]  = '0;
      end

      repeat (120) begin
        @(posedge clk);

        out_ready_i = (($urandom % 100) < 20) ? 1'b0 : 1'b1;

        for (int p = 0; p < NUM_REQ; p++) begin
          // hold valid until accepted
          if (in_valid_i[p] && in_ready_o[p]) begin
            in_valid_i[p] <= 1'b0;
            in_data_i[p]  <= '0;
          end

          // if idle, maybe start a new request
          if (!in_valid_i[p]) begin
            if (($urandom % 100) < 40) begin
              data_word    = {8'h55, p[7:0], seq[p][15:0]};
              in_valid_i[p] <= 1'b1;
              in_data_i[p]  <= data_word;
              seq[p]++;
            end
          end
        end
      end

      @(posedge clk);
      in_valid_i = '0;
      out_ready_i = 1'b1;

      repeat (250) @(posedge clk);

      for (int p = 0; p < NUM_REQ; p++) begin
        if (exp_q[p].size() != 0) begin
          $error("Random parallel stress failed: exp_q[%0d] not empty", p);
          fail_count++;
        end
      end
    end
  endtask


  initial begin

    pass_count = 0;
    fail_count = 0;

    reset_dut();

    test_smoke_single_port();
    test_backpressure_hold();
    test_wrr_ratio_basic();
    test_aging_override_basic();
    test_csr_counter_readback();
    test_random_stress_parallel();

    repeat (20) @(posedge clk);

    if (fail_count == 0) $display("[TB] PASSED");
    else $display("[TB] FAILED, fail count=%0d", fail_count);

    $finish;
  end

endmodule