`timescale 1ns/1ps

module tb_conv2_weight_rom_oc4;

parameter PACKED_FILE = "../data/weights/conv2_weight_oc4.hex";

reg clk;
reg rd_en;
reg [12:0] addr;

wire signed [15:0] weight0;
wire signed [15:0] weight1;
wire signed [15:0] weight2;
wire signed [15:0] weight3;

reg [35:0] packed_ref [0:4607];

integer error_count;
integer test_count;
integer i;
integer rand_value;
integer req_addr;

reg signed [15:0] exp0;
reg signed [15:0] exp1;
reg signed [15:0] exp2;
reg signed [15:0] exp3;

conv2_weight_rom_oc4 #(
    .MEM_FILE(PACKED_FILE)
) dut (
    .clk(clk),
    .rd_en(rd_en),
    .addr(addr),
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

task check_addr;
    input integer check_address;
    begin
        req_addr = check_address;
        exp0 = sext9(packed_ref[req_addr][8:0]);
        exp1 = sext9(packed_ref[req_addr][17:9]);
        exp2 = sext9(packed_ref[req_addr][26:18]);
        exp3 = sext9(packed_ref[req_addr][35:27]);

        @(negedge clk);
        rd_en = 1'b1;
        addr = req_addr[12:0];

        @(posedge clk);
        #1;
        test_count = test_count + 1;

        if (($signed(weight0) !== $signed(exp0)) ||
            ($signed(weight1) !== $signed(exp1)) ||
            ($signed(weight2) !== $signed(exp2)) ||
            ($signed(weight3) !== $signed(exp3))) begin
            error_count = error_count + 1;
            $display("ERROR addr=%0d", req_addr);
            $display("  got = %0d %0d %0d %0d",
                     $signed(weight0), $signed(weight1),
                     $signed(weight2), $signed(weight3));
            $display("  exp = %0d %0d %0d %0d",
                     $signed(exp0), $signed(exp1),
                     $signed(exp2), $signed(exp3));
        end
    end
endtask

task check_known_vector;
    input integer check_address;
    input integer known0;
    input integer known1;
    input integer known2;
    input integer known3;
    begin
        check_addr(check_address);

        if (($signed(weight0) !== known0) ||
            ($signed(weight1) !== known1) ||
            ($signed(weight2) !== known2) ||
            ($signed(weight3) !== known3)) begin
            error_count = error_count + 1;
            $display("KNOWN VECTOR ERROR addr=%0d", check_address);
            $display("  got   = %0d %0d %0d %0d",
                     $signed(weight0), $signed(weight1),
                     $signed(weight2), $signed(weight3));
            $display("  known = %0d %0d %0d %0d",
                     known0, known1, known2, known3);
        end
    end
endtask

initial begin
    clk = 1'b0;
    rd_en = 1'b0;
    addr = 13'd0;
    error_count = 0;
    test_count = 0;

    $readmemh(PACKED_FILE, packed_ref);

    /*
        Known vectors from the current repository's original
        data/weights/conv2_weight.hex.
        These checks verify the packing order, not only ROM extraction.
    */
    check_known_vector(0,    -21,  37, -34,  -8);
    check_known_vector(1,    -15,  -6,  25,  56);
    check_known_vector(2,     17,  33,   2,  43);
    check_known_vector(3,     28, -15, -29,  46);
    check_known_vector(287,  -36,  37,  12, -43);
    check_known_vector(288,   -1, -39,  13,  23);
    check_known_vector(289,   11, -22,  28,  34);
    check_known_vector(1234,  30,  35,   7, -47);
    check_known_vector(2048,  32,  26,  47,  79);
    check_known_vector(4095,  19, -23,  36,  51);
    check_known_vector(4604,  20,   3, -36, -12);
    check_known_vector(4605, -25,  36, -63, -23);
    check_known_vector(4606,  -3,  16, -18, -28);
    check_known_vector(4607, -37,   8, -20, -29);

    /* Random ROM extraction/read-latency checks. */
    for (i = 0; i < 200; i = i + 1) begin
        rand_value = $random;
        rand_value = rand_value & 32'h7fffffff;
        check_addr(rand_value % 4608);
    end

    @(negedge clk);
    rd_en = 1'b0;

    $display("test_count  = %0d", test_count);
    $display("error_count = %0d", error_count);

    if (error_count == 0)
        $display("******** PASS: tb_conv2_weight_rom_oc4 ********");
    else
        $display("******** FAIL: tb_conv2_weight_rom_oc4 ********");

    $finish;
end

endmodule
