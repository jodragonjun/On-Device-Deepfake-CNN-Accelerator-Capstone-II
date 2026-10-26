`timescale 1ns/1ps

module conv2_weight_rom_oc4 (
    clk,
    rd_en,
    addr,
    weight0,
    weight1,
    weight2,
    weight3
);

parameter MEM_FILE = "conv2_weight_oc4.hex";

input clk;
input rd_en;
input [12:0] addr;

output signed [15:0] weight0;
output signed [15:0] weight1;
output signed [15:0] weight2;
output signed [15:0] weight3;

/*
    Conv2 True-PE4 weight memory.

    Address:
        addr = oc_group * 288 + k
        oc_group = 0 ~ 15
        k        = 0 ~ 287

    One 36-bit word:
        [ 8: 0] : W[4*oc_group + 0][k]
        [17: 9] : W[4*oc_group + 1][k]
        [26:18] : W[4*oc_group + 2][k]
        [35:27] : W[4*oc_group + 3][k]

    Stored weight width is signed 9-bit.
    PE interface remains signed 16-bit by sign-extension.

    Read timing:
        cycle N   : rd_en=1, addr valid
        cycle N+1 : weight0~3 valid

    No valid output is generated here.
*/

(* rom_style = "block" *) reg [35:0] mem [0:4607];
reg [35:0] data_reg;

initial begin
    $readmemh(MEM_FILE, mem);
end

always @(posedge clk) begin
    if (rd_en) begin
        data_reg <= mem[addr];
    end
end

assign weight0 = {{7{data_reg[8]}},  data_reg[8:0]};
assign weight1 = {{7{data_reg[17]}}, data_reg[17:9]};
assign weight2 = {{7{data_reg[26]}}, data_reg[26:18]};
assign weight3 = {{7{data_reg[35]}}, data_reg[35:27]};

endmodule
