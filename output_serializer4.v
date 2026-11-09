`timescale 1ns/1ps

module output_serializer4 #(
    parameter integer DATA_WIDTH = 64
)(
    input  wire clk,
    input  wire rst,

    // Controller -> Serializer
    input  wire start,

    // PE4 results
    input  wire signed [DATA_WIDTH-1:0] result0,
    input  wire signed [DATA_WIDTH-1:0] result1,
    input  wire signed [DATA_WIDTH-1:0] result2,
    input  wire signed [DATA_WIDTH-1:0] result3,

    // Serialized output
    output reg  signed [DATA_WIDTH-1:0] out_data,
    output reg                         out_valid,

    // Which PE lane is currently being output
    output reg  [1:0]                  lane_idx,

    // Serializer status
    output reg                         done
);

    localparam IDLE = 1'b0;
    localparam SEND = 1'b1;

    reg state;

    // Latch PE results so that PE outputs may change later
    reg signed [DATA_WIDTH-1:0] data0;
    reg signed [DATA_WIDTH-1:0] data1;
    reg signed [DATA_WIDTH-1:0] data2;
    reg signed [DATA_WIDTH-1:0] data3;


    always @(posedge clk or posedge rst) begin

        if (rst) begin

            state     <= IDLE;

            data0     <= {DATA_WIDTH{1'b0}};
            data1     <= {DATA_WIDTH{1'b0}};
            data2     <= {DATA_WIDTH{1'b0}};
            data3     <= {DATA_WIDTH{1'b0}};

            out_data  <= {DATA_WIDTH{1'b0}};
            out_valid <= 1'b0;

            lane_idx  <= 2'd0;

            done      <= 1'b0;

        end
        else begin

            // Default: pulse signals
            out_valid <= 1'b0;
            done      <= 1'b0;


            case (state)

                // -------------------------------------------------
                // Wait for serializer start
                // -------------------------------------------------
                IDLE: begin

                    lane_idx <= 2'd0;

                    if (start) begin

                        // Save all four PE results
                        data0 <= result0;
                        data1 <= result1;
                        data2 <= result2;
                        data3 <= result3;

                        // First output
                        out_data  <= result0;
                        out_valid <= 1'b1;
                        lane_idx  <= 2'd0;

                        state <= SEND;

                    end

                end


                // -------------------------------------------------
                // Output remaining results
                // -------------------------------------------------
                SEND: begin

                    case (lane_idx)

                        2'd0: begin
                            out_data  <= data1;
                            out_valid <= 1'b1;
                            lane_idx  <= 2'd1;
                        end


                        2'd1: begin
                            out_data  <= data2;
                            out_valid <= 1'b1;
                            lane_idx  <= 2'd2;
                        end


                        2'd2: begin
                            out_data  <= data3;
                            out_valid <= 1'b1;
                            lane_idx  <= 2'd3;
                        end


                        2'd3: begin

                            // result3 was already valid
                            // during the previous cycle.
                            // Serialization is now complete.
                            done  <= 1'b1;
                            state <= IDLE;

                        end

                        default: begin
                            state <= IDLE;
                        end

                    endcase

                end

                default: begin
                    state <= IDLE;
                end

            endcase

        end

    end

endmodule