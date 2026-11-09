`timescale 1ns/1ps

module conv2_engine_oc4_axis #(
    parameter K_TERMS    = 288,
    parameter OC_GROUPS  = 16,
    parameter DATA_WIDTH = 64
)(
    input  wire clk,
    input  wire rst,
    input  wire start,

    // Memory -> Engine
    input  wire signed [31:0] activation,

    input  wire signed [15:0] weight0,
    input  wire signed [15:0] weight1,
    input  wire signed [15:0] weight2,
    input  wire signed [15:0] weight3,

    // Engine -> Memory
    output wire       mem_req,
    output wire [8:0] k,
    output wire [3:0] oc_group,

    // Serialized output
    output wire signed [DATA_WIDTH-1:0] out_data,
    output wire                         out_valid,
    input  wire                         out_ready,

    output wire [5:0] out_ch,

    output wire done
);

    wire clear_acc;
    wire pe_valid;

    wire serializer_start;
    wire serializer_done;

    wire signed [DATA_WIDTH-1:0] result0;
    wire signed [DATA_WIDTH-1:0] result1;
    wire signed [DATA_WIDTH-1:0] result2;
    wire signed [DATA_WIDTH-1:0] result3;

    wire result_valid;

    wire [1:0] lane_idx;


    // =========================================================
    // Controller
    // =========================================================

    conv2_controller_fsm #(
        .K_TERMS(K_TERMS),
        .OC_GROUPS(OC_GROUPS)
    ) u_controller (
        .clk(clk),
        .rst(rst),
        .start(start),

        .result_valid(result_valid),
        .serializer_done(serializer_done),

        .mem_req(mem_req),
        .k(k),
        .oc_group(oc_group),

        .clear_acc(clear_acc),
        .pe_valid(pe_valid),

        .serializer_start(serializer_start),

        .done(done)
    );


    // =========================================================
    // True PE4
    // =========================================================

    pe_array4_oc #(
        .K_TERMS(K_TERMS)
    ) u_pe_array4 (
        .clk(clk),
        .rst(rst),

        .clear_acc(clear_acc),
        .valid_in(pe_valid),

        .activation(activation),

        .weight0(weight0),
        .weight1(weight1),
        .weight2(weight2),
        .weight3(weight3),

        .result0(result0),
        .result1(result1),
        .result2(result2),
        .result3(result3),

        .result_valid(result_valid)
    );


    // =========================================================
    // AXI-ready Serializer
    // =========================================================

    output_serializer4_axis #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_serializer (
        .clk(clk),
        .rst(rst),

        .start(serializer_start),

        .result0(result0),
        .result1(result1),
        .result2(result2),
        .result3(result3),

        .out_data(out_data),
        .out_valid(out_valid),
        .out_ready(out_ready),

        .lane_idx(lane_idx),

        .done(serializer_done)
    );


    // group ¡¿ 4 + lane
    assign out_ch = {oc_group, lane_idx};

endmodule