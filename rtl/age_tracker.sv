`timescale 1ns/1ps

module age_tracker import scheduler_pkg::*; #(
  parameter int unsigned NUM_REQ = 4,
  parameter int unsigned AGE_W   = 8
) (
  input  logic                        clk,
  input  logic                        rst_n,
  input  logic [NUM_REQ-1:0]          pending_i,
  input  logic [NUM_REQ-1:0]          serve_i,
  input  logic [AGE_W-1:0]            aging_threshold_i,
  output logic [AGE_W-1:0]            age_o [NUM_REQ],
  output logic [NUM_REQ-1:0]          starved_o
);

  logic [AGE_W-1:0] age_q [NUM_REQ];
  logic [AGE_W-1:0] age_n [NUM_REQ];

  genvar g;
  generate
    for (g = 0; g < NUM_REQ; g++) begin : gen_age_out
      assign age_o[g] = age_q[g];
    end
  endgenerate


  always_comb begin : age_next_comb
    for (int i = 0; i < NUM_REQ; i++) begin
      age_n[i] = age_q[i];

      unique case ({pending_i[i], serve_i[i]})
        2'b00: age_n[i] = '0; // no pending request
        2'b01: age_n[i] = '0; // serve without pending, clear
        2'b10: begin
          // pending and not served
          if (age_q[i] == {AGE_W{1'b1}}) begin
            age_n[i] = age_q[i];
          end else begin
            age_n[i] = age_q[i] + 1'b1;
          end
        end
        2'b11: age_n[i] = '0; // reset age
        default: age_n[i] = age_q[i];
      endcase
    end
  end


  always_ff @(posedge clk or negedge rst_n) begin : age_seq
    if (!rst_n) begin
      for (int i = 0; i < NUM_REQ; i++) begin
        age_q[i] <= '0;
      end
    end else begin
      for (int i = 0; i < NUM_REQ; i++) begin
        age_q[i] <= age_n[i];
      end
    end
  end



  always_comb begin : starved_comb
    for (int i = 0; i < NUM_REQ; i++) begin
      starved_o[i] = pending_i[i] && (age_q[i] >= aging_threshold_i);
    end
  end

endmodule : age_tracker