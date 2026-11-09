`timescale 1ns/1ps

module conv2_engine_oc4 #(
    parameter integer K_TERMS   = 288,
    parameter integer OC_GROUPS = 16,
    parameter integer DATA_WIDTH = 64
)(
    input  wire clk,
    input  wire rst,
    input  wire start,

    // ---------------------------------------------------------
    // Memory -> Engine
    // Memory output is valid 1 clock after mem_req/k/oc_group
    // ---------------------------------------------------------
    input  wire signed [31:0] activation,

    input  wire signed [15:0] weight0,
    input  wire signed [15:0] weight1,
    input  wire signed [15:0] weight2,
    input  wire signed [15:0] weight3,

    // ---------------------------------------------------------
    // Engine -> Memory
    // ---------------------------------------------------------
    output wire       mem_req,
    output wire [8:0] k,
    output wire [3:0] oc_group,

    // ---------------------------------------------------------
    // Serialized Conv2 output
    // ---------------------------------------------------------
    output wire signed [DATA_WIDTH-1:0] out_data,
    output wire                         out_valid,

    output wire [5:0] out_ch,

    // ---------------------------------------------------------
    // Whole operation complete
    // ---------------------------------------------------------
    output wire done
);


    // =========================================================
    // Internal control signals
    // =========================================================

    wire clear_acc;
    wire pe_valid;

    wire serializer_start;
    wire serializer_done;


    // =========================================================
    // PE4 result signals
    // =========================================================

    wire signed [63:0] result0;
    wire signed [63:0] result1;
    wire signed [63:0] result2;
    wire signed [63:0] result3;

    wire result_valid;


    // =========================================================
    // Serializer signals
    // =========================================================

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

        // PE4 -> Controller
        .result_valid(result_valid),

        // Serializer -> Controller
        .serializer_done(serializer_done),

        // Controller -> Memory
        .mem_req(mem_req),
        .k(k),
        .oc_group(oc_group),

        // Controller -> PE4
        .clear_acc(clear_acc),
        .pe_valid(pe_valid),

        // Controller -> Serializer
        .serializer_start(serializer_start),

        // Controller -> Top
        .done(done)
    );


    // =========================================================
    // True PE4
    //
    // Same activation is broadcast to all four PEs.
    // Each PE receives a different output-channel weight.
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
    // PE4 Output Serializer
    // =========================================================

    output_serializer4 #(
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

        .lane_idx(lane_idx),

        .done(serializer_done)
    );


    // =========================================================
    // Output channel number
    //
    // oc_group = 0, lane = 0~3 -> OC0~3
    // oc_group = 1, lane = 0~3 -> OC4~7
    // ...
    //
    // Equivalent to:
    // out_ch = oc_group * 4 + lane_idx
    // =========================================================

    assign out_ch = {oc_group, lane_idx};


endmodule