bind scheduler_top scheduler_sva #(
  .NUM_REQ(NUM_REQ),
  .REQ_W(REQ_W),
  .REQ_IDX_W(REQ_IDX_W)
) u_scheduler_sva (
  .clk        (clk),
  .rst_n      (rst_n),
  .out_valid  (out_valid_o),
  .out_ready  (out_ready_i),
  .out_data   (out_data_o),
  .out_src_idx(out_src_idx_o),
  .fifo_pop   (fifo_pop),
  .serve      (serve)
  );