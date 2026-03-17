package scheduler_pkg;

  parameter int unsigned NUM_REQ       = 4;
  parameter int unsigned REQ_W         = 32;
  parameter int unsigned FIFO_DEPTH    = 4;
  parameter int unsigned WEIGHT_W      = 4;
  parameter int unsigned AGE_W         = 8;
  parameter int unsigned FIFO_CNT_W    = (FIFO_DEPTH <= 1) ? 1 : $clog2(FIFO_DEPTH + 1);
  parameter int unsigned REQ_IDX_W     = (NUM_REQ <= 1) ? 1 : $clog2(NUM_REQ);


  typedef logic [REQ_W-1:0] req_t;
  typedef logic [REQ_IDX_W-1:0] req_idx_t;
  typedef logic [WEIGHT_W-1:0] weight_t;
  typedef logic [AGE_W-1:0] age_t;
  typedef logic [FIFO_CNT_W-1:0] fifo_cnt_t;

endpackage : scheduler_pkg
