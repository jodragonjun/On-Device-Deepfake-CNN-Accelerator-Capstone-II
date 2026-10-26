`timescale 1ns/1ps

module tb_conv2_memory_oc4;

parameter PACKED_FILE = "../data/weights/conv2_weight_oc4.hex";

reg clk;

reg act_wr_en;
reg [5:0] act_wr_in_ch;
reg [3:0] act_wr_k_idx;
reg signed [31:0] act_wr_data;

reg mem_req;
reg [8:0] k;
reg [3:0] oc_group;

wire signed [31:0] activation;
wire signed [15:0] weight0;
wire signed [15:0] weight1;
wire signed [15:0] weight2;
wire signed [15:0] weight3;

reg signed [31:0] act_ref [0:287];
reg [35:0] packed_ref [0:4607];

integer i;
integer ch;
integer kpos;
integer rand_value;
integer req_k;
integer req_group;
integer packed_addr;
integer test_count;
integer error_count;

reg signed [15:0] exp_w0;
reg signed [15:0] exp_w1;
reg signed [15:0] exp_w2;
reg signed [15:0] exp_w3;

conv2_memory_oc4 #(
    .WEIGHT_MEM_FILE(PACKED_FILE)
) dut (
    .clk(clk),

    .act_wr_en(act_wr_en),
    .act_wr_in_ch(act_wr_in_ch),
    .act_wr_k_idx(act_wr_k_idx),
    .act_wr_data(act_wr_data),

    .mem_req(mem_req),
    .k(k),
    .oc_group(oc_group),

    .activation(activation),
    .weight0(weight0),
    .weight1(weight1),
    .weight2(weight2),
    .weight3(weight3)
);

always #5 clk = ~clk;

function [15:0] sext9;
    input [8:0] value;
    begin
        sext9 = {{7{value[8]}}, value};
    end
endfunction

task check_request;
    input integer group_value;
    input integer k_value;
    begin
        req_group = group_value;
        req_k = k_value;
        packed_addr = req_group * 288 + req_k;

        exp_w0 = sext9(packed_ref[packed_addr][8:0]);
        exp_w1 = sext9(packed_ref[packed_addr][17:9]);
        exp_w2 = sext9(packed_ref[packed_addr][26:18]);
        exp_w3 = sext9(packed_ref[packed_addr][35:27]);

        @(negedge clk);
        mem_req = 1'b1;
        oc_group = req_group[3:0];
        k = req_k[8:0];

        @(posedge clk);
        #1;
        test_count = test_count + 1;

        if (($signed(activation) !== $signed(act_ref[req_k])) ||
            ($signed(weight0) !== $signed(exp_w0)) ||
            ($signed(weight1) !== $signed(exp_w1)) ||
            ($signed(weight2) !== $signed(exp_w2)) ||
            ($signed(weight3) !== $signed(exp_w3))) begin
            error_count = error_count + 1;
            $display("ERROR group=%0d k=%0d", req_group, req_k);
            $display("  activation got=%0d expected=%0d",
                     $signed(activation), $signed(act_ref[req_k]));
            $display("  weight got=%0d %0d %0d %0d",
                     $signed(weight0), $signed(weight1),
                     $signed(weight2), $signed(weight3));
            $display("  weight exp=%0d %0d %0d %0d",
                     $signed(exp_w0), $signed(exp_w1),
                     $signed(exp_w2), $signed(exp_w3));
        end
    end
endtask

initial begin
    clk = 1'b0;
    act_wr_en = 1'b0;
    act_wr_in_ch = 6'd0;
    act_wr_k_idx = 4'd0;
    act_wr_data = 32'sd0;
    mem_req = 1'b0;
    k = 9'd0;
    oc_group = 4'd0;
    test_count = 0;
    error_count = 0;

    $readmemh(PACKED_FILE, packed_ref);

    /* Fill activation buffer. */
    for (i = 0; i < 288; i = i + 1) begin
        act_ref[i] = (i * 131) - 18000;
        ch = i / 9;
        kpos = i % 9;

        @(negedge clk);
        act_wr_en = 1'b1;
        act_wr_in_ch = ch[5:0];
        act_wr_k_idx = kpos[3:0];
        act_wr_data = act_ref[i];
    end

    @(negedge clk);
    act_wr_en = 1'b0;

    /* Explicit boundaries and group changes. */
    check_request(0, 0);
    check_request(0, 287);
    check_request(1, 0);
    check_request(7, 123);
    check_request(15, 287);

    /* Random group/k requests. */
    for (i = 0; i < 200; i = i + 1) begin
        rand_value = $random;
        rand_value = rand_value & 32'h7fffffff;
        req_group = rand_value % 16;

        rand_value = $random;
        rand_value = rand_value & 32'h7fffffff;
        req_k = rand_value % 288;

        check_request(req_group, req_k);
    end

    @(negedge clk);
    mem_req = 1'b0;

    $display("test_count  = %0d", test_count);
    $display("error_count = %0d", error_count);

    if (error_count == 0)
        $display("******** PASS: tb_conv2_memory_oc4 ********");
    else
        $display("******** FAIL: tb_conv2_memory_oc4 ********");

    $finish;
end

endmodule
