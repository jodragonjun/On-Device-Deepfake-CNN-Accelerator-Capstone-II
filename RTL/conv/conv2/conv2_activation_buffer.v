`timescale 1ns/1ps

module conv2_activation_buffer (
    clk,

    wr_en,
    wr_in_ch,
    wr_k_idx,
    wr_data,

    rd_en,
    rd_addr,
    rd_data
);

input clk;

input wr_en;
input [5:0] wr_in_ch;
input [3:0] wr_k_idx;
input signed [31:0] wr_data;

input rd_en;
input [8:0] rd_addr;
output reg signed [31:0] rd_data;

/*
    One Conv2 spatial-position window:
        32 input channels * 3 * 3 = 288 activations

    Write address:
        wr_addr = wr_in_ch * 9 + wr_k_idx
        wr_in_ch = 0 ~ 31
        wr_k_idx = 0 ~ 8

    Read address:
        rd_addr = controller k = 0 ~ 287

    Read timing:
        cycle N   : rd_en=1, rd_addr valid
        cycle N+1 : rd_data valid

    IMPORTANT:
    - The memory array is intentionally not reset.
    - No valid output is generated in this module.
*/

(* ram_style = "block" *) reg signed [31:0] mem [0:287];

wire [8:0] wr_in_ch_ext;
wire [8:0] wr_addr;

assign wr_in_ch_ext = {3'd0, wr_in_ch};

/* 9 = 8 + 1 */
assign wr_addr =
      (wr_in_ch_ext << 3)
    + wr_in_ch_ext
    + {5'd0, wr_k_idx};

always @(posedge clk) begin
    if (wr_en) begin
        mem[wr_addr] <= wr_data;
    end

    if (rd_en) begin
        rd_data <= mem[rd_addr];
    end
end

endmodule
