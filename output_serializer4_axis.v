`timescale 1ns/1ps

module output_serializer4_axis #(
    parameter DATA_WIDTH = 64
)(
    input  wire clk,
    input  wire rst,

    input  wire start,

    input  wire signed [DATA_WIDTH-1:0] result0,
    input  wire signed [DATA_WIDTH-1:0] result1,
    input  wire signed [DATA_WIDTH-1:0] result2,
    input  wire signed [DATA_WIDTH-1:0] result3,

    output reg  signed [DATA_WIDTH-1:0] out_data,
    output reg                          out_valid,
    input  wire                         out_ready,

    output reg [1:0] lane_idx,
    output reg       done
);

    localparam IDLE = 1'b0;
    localparam SEND = 1'b1;

    reg state;

    reg signed [DATA_WIDTH-1:0] data1;
    reg signed [DATA_WIDTH-1:0] data2;
    reg signed [DATA_WIDTH-1:0] data3;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            out_data  <= {DATA_WIDTH{1'b0}};
            out_valid <= 1'b0;
            lane_idx  <= 2'd0;
            done      <= 1'b0;

            data1 <= {DATA_WIDTH{1'b0}};
            data2 <= {DATA_WIDTH{1'b0}};
            data3 <= {DATA_WIDTH{1'b0}};
        end
        else begin
            done <= 1'b0;

            case (state)

                IDLE: begin
                    out_valid <= 1'b0;

                    if (start) begin
                        // PE 결과를 보존
                        data1 <= result1;
                        data2 <= result2;
                        data3 <= result3;

                        // lane0부터 출력
                        out_data  <= result0;
                        lane_idx  <= 2'd0;
                        out_valid <= 1'b1;

                        state <= SEND;
                    end
                end


                SEND: begin

                    // 실제 AXI 전송이 성립한 경우에만
                    // 다음 lane으로 이동
                    if (out_valid && out_ready) begin

                        case (lane_idx)

                            2'd0: begin
                                out_data <= data1;
                                lane_idx <= 2'd1;
                            end

                            2'd1: begin
                                out_data <= data2;
                                lane_idx <= 2'd2;
                            end

                            2'd2: begin
                                out_data <= data3;
                                lane_idx <= 2'd3;
                            end

                            2'd3: begin
                                out_valid <= 1'b0;
                                lane_idx  <= 2'd0;
                                done      <= 1'b1;
                                state     <= IDLE;
                            end

                        endcase
                    end
                end

            endcase
        end
    end

endmodule