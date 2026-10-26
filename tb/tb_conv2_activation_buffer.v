`timescale 1ns/1ps

module tb_conv2_activation_buffer;

reg clk;
reg wr_en;
reg [5:0] wr_in_ch;
reg [3:0] wr_k_idx;
reg signed [31:0] wr_data;

reg rd_en;
reg [8:0] rd_addr;
wire signed [31:0] rd_data;

reg signed [31:0] expected [0:287];

integer i;
integer ch;
integer kpos;
integer rand_value;
integer test_count;
integer error_count;
integer check_index;

conv2_activation_buffer dut (
    .clk(clk),
    .wr_en(wr_en),
    .wr_in_ch(wr_in_ch),
    .wr_k_idx(wr_k_idx),
    .wr_data(wr_data),
    .rd_en(rd_en),
    .rd_addr(rd_addr),
    .rd_data(rd_data)
);

always #5 clk = ~clk;

task check_read;
    input integer index_value;
    begin
        check_index = index_value;

        @(negedge clk);
        rd_en = 1'b1;
        rd_addr = check_index[8:0];

        @(posedge clk);
        #1;
        test_count = test_count + 1;

        if ($signed(rd_data) !== $signed(expected[check_index])) begin
            error_count = error_count + 1;
            $display("ERROR rd_addr=%0d got=%0d expected=%0d",
                     check_index, $signed(rd_data),
                     $signed(expected[check_index]));
        end
    end
endtask

initial begin
    clk = 1'b0;
    wr_en = 1'b0;
    wr_in_ch = 6'd0;
    wr_k_idx = 4'd0;
    wr_data = 32'sd0;
    rd_en = 1'b0;
    rd_addr = 9'd0;
    test_count = 0;
    error_count = 0;

    /*
        Fill all 288 locations using the same addressing rule as Conv2 input:
            addr = in_ch * 9 + k_idx
    */
    for (i = 0; i < 288; i = i + 1) begin
        expected[i] = (i * 97) - 14000;
        ch = i / 9;
        kpos = i % 9;

        @(negedge clk);
        wr_en = 1'b1;
        wr_in_ch = ch[5:0];
        wr_k_idx = kpos[3:0];
        wr_data = expected[i];
    end

    @(negedge clk);
    wr_en = 1'b0;

    check_read(0);
    check_read(1);
    check_read(8);
    check_read(9);
    check_read(143);
    check_read(287);

    for (i = 0; i < 100; i = i + 1) begin
        rand_value = $random;
        rand_value = rand_value & 32'h7fffffff;
        check_read(rand_value % 288);
    end

    @(negedge clk);
    rd_en = 1'b0;

    $display("test_count  = %0d", test_count);
    $display("error_count = %0d", error_count);

    if (error_count == 0)
        $display("******** PASS: tb_conv2_activation_buffer ********");
    else
        $display("******** FAIL: tb_conv2_activation_buffer ********");

    $finish;
end

endmodule
