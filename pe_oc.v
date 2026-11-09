`timescale 1ns/1ps

module pe_oc #(
 parameter integer K_TERMS = 288
)(
 input wire clk,
 input wire rst,
 input wire clear_acc,
 input wire valid_in,
 input wire signed [31:0] activation,
 input wire signed [15:0] weight,
 output reg signed [63:0] result,
 output reg result_valid
);
 // Conv2: K_TERMS = 288
 // Conv3: K_TERMS = 576
 // K_TERMS must be >= 1.
 function integer count_width;
 input integer value;
 integer n;
 begin
 n = value - 1;
 count_width = 0;
 while (n > 0) begin
 count_width = count_width + 1;
 n = n >> 1;
 end
 if (count_width < 1)
 count_width = 1;
 end
 endfunction
 localparam integer CNT_WIDTH = count_width(K_TERMS);
 localparam [CNT_WIDTH-1:0] LAST_INPUT = K_TERMS - 1;
 reg [CNT_WIDTH-1:0] input_count;
 reg accepting;
 reg signed [47:0] product_reg;
 reg product_valid;
 reg product_last;
 reg signed [63:0] acc;
 wire signed [63:0] product_ext;
 wire signed [63:0] acc_next;
 assign product_ext = {{16{product_reg[47]}}, product_reg};
 assign acc_next = acc + product_ext;
 always @(posedge clk or posedge rst) begin
 if (rst) begin
 input_count <= 0;
 accepting <= 1'b0;
 product_reg <= 48'sd0;
 product_valid <= 1'b0;
 product_last <= 1'b0;
 acc <= 64'sd0;
 result <= 64'sd0;
 result_valid <= 1'b0;
 end
 else if (clear_acc) begin
 // Clear has priority over valid_in.
 // It also discards any pending pipeline product.
 input_count <= 0;
 accepting <= 1'b1;
 product_reg <= 48'sd0;
 product_valid <= 1'b0;
 product_last <= 1'b0;
 acc <= 64'sd0;
 result <= 64'sd0;
 result_valid <= 1'b0;
 end
 else begin
 result_valid <= 1'b0;
 product_valid <= 1'b0;
 product_last <= 1'b0;
 // Stage 1: signed multiplication.
 if (accepting && valid_in) begin
 product_reg <= $signed(activation) * $signed(weight);
 product_valid <= 1'b1;
 if (input_count == LAST_INPUT) begin
 product_last <= 1'b1;
 accepting <= 1'b0;
 end
 else begin
 input_count <= input_count + 1'b1;
 end
 end
 // Stage 2: accumulate the previous cycle's product.
 // This must run independently of current valid_in.
 if (product_valid) begin
 acc <= acc_next;
 if (product_last) begin
 // Include the final product in result.
 result <= acc_next;
 result_valid <= 1'b1;
 end
 end
 end
 end
endmodule