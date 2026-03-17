`timescale 1ns/1ps

module tb_csr_regs;
  import scheduler_pkg::*;

  localparam int unsigned NUM_REQ   = 4;
  localparam int unsigned WEIGHT_W  = 4;
  localparam int unsigned AGE_W     = 8;
  localparam int unsigned COUNTER_W = 32;
  localparam int unsigned ADDR_W    = 8;
  localparam int unsigned DATA_W    = 32;

  logic clk;
  logic rst_n;

  logic                  csr_write_i;
  logic                  csr_read_i;
  logic [ADDR_W-1:0]     csr_addr_i;
  logic [DATA_W-1:0]     csr_wdata_i;
  logic [DATA_W-1:0]     csr_rdata_o;
  logic                  csr_ready_o;
  logic [WEIGHT_W-1:0]   weight_o [NUM_REQ];
  logic [AGE_W-1:0]      aging_threshold_o;
  logic [NUM_REQ-1:0]    fifo_full_i;
  logic [NUM_REQ-1:0]    fifo_empty_i;
  logic [COUNTER_W-1:0]  grant_count_i [NUM_REQ];
  logic [COUNTER_W-1:0]  stall_count_i;
  logic [COUNTER_W-1:0]  starve_hit_count_i;

  csr_regs dut (
    .clk                (clk),
    .rst_n              (rst_n),
    .csr_write_i        (csr_write_i),
    .csr_read_i         (csr_read_i),
    .csr_addr_i         (csr_addr_i),
    .csr_wdata_i        (csr_wdata_i),
    .csr_rdata_o        (csr_rdata_o),
    .csr_ready_o        (csr_ready_o),
    .weight_o           (weight_o),
    .aging_threshold_o  (aging_threshold_o),
    .fifo_full_i        (fifo_full_i),
    .fifo_empty_i       (fifo_empty_i),
    .grant_count_i      (grant_count_i),
    .stall_count_i      (stall_count_i),
    .starve_hit_count_i (starve_hit_count_i)
  );


  always #5 clk = ~clk;

  task automatic csr_write(input logic [ADDR_W-1:0] addr,
                           input logic [DATA_W-1:0] data);
    begin
      @(negedge clk);
      csr_write_i = 1'b1;
      csr_read_i  = 1'b0;
      csr_addr_i  = addr;
      csr_wdata_i = data;
      @(negedge clk);
      csr_write_i = 1'b0;
      csr_addr_i  = '0;
      csr_wdata_i = '0;
    end
  endtask


  task automatic csr_read(input logic [ADDR_W-1:0] addr,
                          input logic [DATA_W-1:0] exp);
    begin
      @(negedge clk);
      csr_read_i  = 1'b1;
      csr_write_i = 1'b0;
      csr_addr_i  = addr;
      #1;
      if (csr_rdata_o !== exp) begin
        $error("CSR read mismatch addr=0x%0h exp=0x%08h got=0x%08h",
               addr, exp, csr_rdata_o);
      end
      @(negedge clk);
      csr_read_i = 1'b0;
      csr_addr_i = '0;
    end
  endtask


  initial begin
    clk = 0;
    rst_n = 0;

    csr_write_i = 0;
    csr_read_i  = 0;
    csr_addr_i  = '0;
    csr_wdata_i = '0;

    fifo_full_i         = '0;
    fifo_empty_i        = '1;
    stall_count_i       = '0;
    starve_hit_count_i  = '0;
    for (int i = 0; i < NUM_REQ; i++) begin
      grant_count_i[i] = '0;
    end

    repeat (3) @(negedge clk);
    rst_n = 1;
    repeat (1) @(negedge clk);

    // reset values
    if (csr_ready_o !== 1'b1) $error("csr_ready_o should be tied high");
    for (int i = 0; i < NUM_REQ; i++) begin
      if (weight_o[i] !== 4'd1) $error("Reset weight_o[%0d] mismatch", i);
    end
    if (aging_threshold_o !== 8'd16) $error("Reset aging_threshold mismatch");

    csr_read(8'h00, 32'h0000_0001);
    csr_read(8'h04, 32'h0000_0001);
    csr_read(8'h08, 32'h0000_0001);
    csr_read(8'h0C, 32'h0000_0001);
    csr_read(8'h10, 32'h0000_0010);

    // Config writes
    csr_write(8'h00, 32'h0000_0003);
    csr_write(8'h04, 32'h0000_0005);
    csr_write(8'h08, 32'h0000_0007);
    csr_write(8'h0C, 32'h0000_0009);
    csr_write(8'h10, 32'h0000_0024);

    if (weight_o[0] !== 4'd3) $error("weight_o[0] mismatch");
    if (weight_o[1] !== 4'd5) $error("weight_o[1] mismatch");
    if (weight_o[2] !== 4'd7) $error("weight_o[2] mismatch");
    if (weight_o[3] !== 4'd9) $error("weight_o[3] mismatch");
    if (aging_threshold_o !== 8'h24) $error("aging_threshold_o mismatch");

    csr_read(8'h00, 32'h0000_0003);
    csr_read(8'h04, 32'h0000_0005);
    csr_read(8'h08, 32'h0000_0007);
    csr_read(8'h0C, 32'h0000_0009);
    csr_read(8'h10, 32'h0000_0024);

    // status readback
    fifo_empty_i = 4'b0101;
    fifo_full_i  = 4'b1010;
    csr_read(8'h20, 32'h0000_00A5); // [3:0]=empty=0101, [7:4]=full=1010

    grant_count_i[0] = 32'h0000_0011;
    grant_count_i[1] = 32'h0000_0022;
    grant_count_i[2] = 32'h0000_0033;
    grant_count_i[3] = 32'h0000_0044;
    stall_count_i    = 32'h0000_0055;
    starve_hit_count_i = 32'h0000_0066;

    csr_read(8'h30, 32'h0000_0011);
    csr_read(8'h34, 32'h0000_0022);
    csr_read(8'h38, 32'h0000_0033);
    csr_read(8'h3C, 32'h0000_0044);
    csr_read(8'h40, 32'h0000_0055);
    csr_read(8'h44, 32'h0000_0066);

    // Invalid addr reads zero
    csr_read(8'h7C, 32'h0000_0000);

    // invalid addr write does nothing
    csr_write(8'h7C, 32'hDEAD_BEEF);
    csr_read(8'h00, 32'h0000_0003);
    csr_read(8'h10, 32'h0000_0024);

    $display("tb_csr_regs PASSED");
    $finish;
  end

endmodule