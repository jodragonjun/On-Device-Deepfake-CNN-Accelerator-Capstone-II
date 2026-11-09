`timescale 1ns/1ps

module pe_array4_oc #(
    parameter integer K_TERMS = 288
)(
    input wire clk,
    input wire rst,
    input wire clear_acc,
    input wire valid_in,

    input wire signed [31:0] activation,

    input wire signed [15:0] weight0,
    input wire signed [15:0] weight1,
    input wire signed [15:0] weight2,
    input wire signed [15:0] weight3,

    output wire signed [63:0] result0,
    output wire signed [63:0] result1,
    output wire signed [63:0] result2,
    output wire signed [63:0] result3,

    output wire result_valid
);

    wire v0, v1, v2, v3;

    pe_oc #(.K_TERMS(K_TERMS)) u_pe0 (
        .clk(clk),
        .rst(rst),
        .clear_acc(clear_acc),
        .valid_in(valid_in),
        .activation(activation),
        .weight(weight0),
        .result(result0),
        .result_valid(v0)
    );

    pe_oc #(.K_TERMS(K_TERMS)) u_pe1 (
        .clk(clk),
        .rst(rst),
        .clear_acc(clear_acc),
        .valid_in(valid_in),
        .activation(activation),
        .weight(weight1),
        .result(result1),
        .result_valid(v1)
    );

    pe_oc #(.K_TERMS(K_TERMS)) u_pe2 (
        .clk(clk),
        .rst(rst),
        .clear_acc(clear_acc),
        .valid_in(valid_in),
        .activation(activation),
        .weight(weight2),
        .result(result2),
        .result_valid(v2)
    );

    pe_oc #(.K_TERMS(K_TERMS)) u_pe3 (
        .clk(clk),
        .rst(rst),
        .clear_acc(clear_acc),
        .valid_in(valid_in),
        .activation(activation),
        .weight(weight3),
        .result(result3),
        .result_valid(v3)
    );

    assign result_valid = v0 & v1 & v2 & v3;

endmodule