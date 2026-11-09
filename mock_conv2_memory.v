`timescale 1ns/1ps

module mock_conv2_memory (
    input  wire clk,
    input  wire rst,

    // Controller -> Mock Memory
    input  wire       mem_req,
    input  wire [8:0] k,
    input  wire [3:0] oc_group,

    // Mock Memory -> PE4
    output reg signed [31:0] activation,

    output reg signed [15:0] weight0,
    output reg signed [15:0] weight1,
    output reg signed [15:0] weight2,
    output reg signed [15:0] weight3
);

    always @(posedge clk or posedge rst) begin

        if (rst) begin

            activation <= 32'sd0;

            weight0 <= 16'sd0;
            weight1 <= 16'sd0;
            weight2 <= 16'sd0;
            weight3 <= 16'sd0;

        end
        else if (mem_req) begin

            // ---------------------------------------------
            // Activation:
            //
            // k=0   -> 1
            // k=1   -> 2
            // ...
            // k=287 -> 288
            // ---------------------------------------------

            activation <= $signed({23'd0, k}) + 32'sd1;


            // ---------------------------------------------
            // Weight:
            //
            // oc_group=0 -> 1,2,3,4
            // oc_group=1 -> 5,6,7,8
            // ...
            // oc_group=15 -> 61,62,63,64
            //
            // {oc_group, 2'b00} = oc_group * 4
            // ---------------------------------------------

            weight0 <= {10'd0, oc_group, 2'b00} + 16'd1;
            weight1 <= {10'd0, oc_group, 2'b00} + 16'd2;
            weight2 <= {10'd0, oc_group, 2'b00} + 16'd3;
            weight3 <= {10'd0, oc_group, 2'b00} + 16'd4;

        end

    end

endmodule