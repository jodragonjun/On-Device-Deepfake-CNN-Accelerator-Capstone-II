`timescale 1ns/1ps

module conv2_memory_oc4 (
    clk,

    act_wr_en,
    act_wr_in_ch,
    act_wr_k_idx,
    act_wr_data,

    mem_req,
    k,
    oc_group,

    activation,
    weight0,
    weight1,
    weight2,
    weight3
);

parameter WEIGHT_MEM_FILE = "conv2_weight_oc4.hex";

input clk;

/* Activation-buffer write interface */
input act_wr_en;
input [5:0] act_wr_in_ch;
input [3:0] act_wr_k_idx;
input signed [31:0] act_wr_data;

/* Controller read-request interface */
input mem_req;
input [8:0] k;
input [3:0] oc_group;

/* PE4 data interface */
output signed [31:0] activation;
output signed [15:0] weight0;
output signed [15:0] weight1;
output signed [15:0] weight2;
output signed [15:0] weight3;

/*
    Common timing contract:

    cycle N:
        mem_req = 1
        k and oc_group are valid

    cycle N+1:
        activation and weight0~3 correspond to the request from cycle N.

    This module deliberately has no data-valid output.
    Controller delays mem_req by one clock to create PE valid.
*/

wire [12:0] oc_group_ext;
wire [12:0] k_ext;
wire [12:0] weight_addr;

assign oc_group_ext = {9'd0, oc_group};
assign k_ext = {4'd0, k};

/*
    weight_addr = oc_group * 288 + k
                = oc_group * (256 + 32) + k
*/
assign weight_addr =
      (oc_group_ext << 8)
    + (oc_group_ext << 5)
    + k_ext;

conv2_activation_buffer u_activation_buffer (
    .clk       (clk),

    .wr_en     (act_wr_en),
    .wr_in_ch  (act_wr_in_ch),
    .wr_k_idx  (act_wr_k_idx),
    .wr_data   (act_wr_data),

    .rd_en     (mem_req),
    .rd_addr   (k),
    .rd_data   (activation)
);

conv2_weight_rom_oc4 #(
    .MEM_FILE(WEIGHT_MEM_FILE)
) u_weight_rom (
    .clk       (clk),
    .rd_en     (mem_req),
    .addr      (weight_addr),
    .weight0   (weight0),
    .weight1   (weight1),
    .weight2   (weight2),
    .weight3   (weight3)
);

endmodule
