`timescale 1ns/1ps

module conv2_axis_wrapper #(
    parameter WEIGHT_MEM_FILE = "conv2_weight_oc4.hex"
)(
    // =========================================================
    // AXI Clock / Reset
    // =========================================================

    input wire aclk,
    input wire aresetn,


    // =========================================================
    // AXI4-Stream Slave
    // DMA MM2S -> Conv2
    //
    // 32-bit activation ¡¿ 288
    // =========================================================

    input  wire signed [31:0] s_axis_tdata,
    input  wire               s_axis_tvalid,
    output wire               s_axis_tready,
    input  wire [3:0]         s_axis_tkeep,
    input  wire               s_axis_tlast,


    // =========================================================
    // AXI4-Stream Master
    // Conv2 -> DMA S2MM
    //
    // 64-bit result ¡¿ 64
    // =========================================================

    output wire signed [63:0] m_axis_tdata,
    output wire               m_axis_tvalid,
    input  wire               m_axis_tready,
    output wire [7:0]         m_axis_tkeep,
    output wire               m_axis_tlast,


    // =========================================================
    // Debug
    // =========================================================

    output wire busy,
    output wire conv_done,

    output reg input_frame_error
);

    wire rst;

    assign rst = ~aresetn;


    // =========================================================
    // State
    // =========================================================

    localparam ST_LOAD  = 2'd0;
    localparam ST_START = 2'd1;
    localparam ST_RUN   = 2'd2;

    reg [1:0] state;


    // =========================================================
    // Activation write address
    // =========================================================

    reg [5:0] wr_in_ch;
    reg [3:0] wr_k_idx;

    reg [8:0] recv_count;


    // =========================================================
    // Activation Buffer write signals
    // =========================================================

    wire               act_wr_en;
    wire [5:0]         act_wr_in_ch;
    wire [3:0]         act_wr_k_idx;
    wire signed [31:0] act_wr_data;


    // AXI handshake
    wire input_fire;

    assign input_fire =
        s_axis_tvalid && s_axis_tready;


    // Only receive data while loading one window
    assign s_axis_tready =
        (state == ST_LOAD);


    // Directly convert AXI handshake to Buffer write
    assign act_wr_en =
        input_fire;

    assign act_wr_in_ch =
        wr_in_ch;

    assign act_wr_k_idx =
        wr_k_idx;

    assign act_wr_data =
        s_axis_tdata;


    // =========================================================
    // Engine start
    // =========================================================

    wire engine_start;

    assign engine_start =
        (state == ST_START);


    // =========================================================
    // Engine <-> Memory
    // =========================================================

    wire       mem_req;
    wire [8:0] k;
    wire [3:0] oc_group;

    wire signed [31:0] activation;

    wire signed [15:0] weight0;
    wire signed [15:0] weight1;
    wire signed [15:0] weight2;
    wire signed [15:0] weight3;


    // =========================================================
    // Engine output
    // =========================================================

    wire signed [63:0] engine_out_data;
    wire               engine_out_valid;
    wire [5:0]         engine_out_ch;
    wire               engine_done;


    // =========================================================
    // Real Conv2 Memory
    // =========================================================

    conv2_memory_oc4 #(
        .WEIGHT_MEM_FILE(WEIGHT_MEM_FILE)
    ) u_memory (
        .clk(aclk),

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


    // =========================================================
    // Conv2 Engine
    // =========================================================

    conv2_engine_oc4_axis #(
        .K_TERMS(288),
        .OC_GROUPS(16),
        .DATA_WIDTH(64)
    ) u_engine (
        .clk(aclk),
        .rst(rst),

        .start(engine_start),

        .activation(activation),

        .weight0(weight0),
        .weight1(weight1),
        .weight2(weight2),
        .weight3(weight3),

        .mem_req(mem_req),
        .k(k),
        .oc_group(oc_group),

        .out_data(engine_out_data),
        .out_valid(engine_out_valid),
        .out_ready(m_axis_tready),

        .out_ch(engine_out_ch),

        .done(engine_done)
    );


    // =========================================================
    // AXI4-Stream Master mapping
    // =========================================================

    assign m_axis_tdata =
        engine_out_data;

    assign m_axis_tvalid =
        engine_out_valid;

    // All 8 bytes valid
    assign m_axis_tkeep =
        8'hFF;

    // Last output = OC63
    assign m_axis_tlast =
        engine_out_valid &&
        (engine_out_ch == 6'd63);


    // =========================================================
    // Status
    // =========================================================

    assign busy =
        (state != ST_LOAD);

    assign conv_done =
        engine_done;


    // =========================================================
    // Input Controller
    // =========================================================

    always @(posedge aclk) begin

        if (rst) begin

            state <= ST_LOAD;

            wr_in_ch <= 6'd0;
            wr_k_idx <= 4'd0;

            recv_count <= 9'd0;

            input_frame_error <= 1'b0;

        end
        else begin

            case (state)

                // =================================================
                // Receive 288 activations
                // =================================================

                ST_LOAD: begin

                    if (input_fire) begin

                        // Start of new packet:
                        // clear previous packet error
                        if (recv_count == 9'd0)
                            input_frame_error <= 1'b0;


                        // -----------------------------------------
                        // TLAST check
                        //
                        // Correct:
                        // word 287 -> TLAST = 1
                        // -----------------------------------------

                        if (recv_count == 9'd287) begin

                            if (!s_axis_tlast)
                                input_frame_error <= 1'b1;

                        end
                        else begin

                            if (s_axis_tlast)
                                input_frame_error <= 1'b1;

                        end


                        // -----------------------------------------
                        // Final activation
                        // -----------------------------------------

                        if (recv_count == 9'd287) begin

                            recv_count <= 9'd0;

                            wr_in_ch <= 6'd0;
                            wr_k_idx <= 4'd0;

                            state <= ST_START;

                        end
                        else begin

                            recv_count <= recv_count + 1'b1;


                            // -------------------------------------
                            // 3x3 = 9 values per input channel
                            // -------------------------------------

                            if (wr_k_idx == 4'd8) begin

                                wr_k_idx <= 4'd0;
                                wr_in_ch <= wr_in_ch + 1'b1;

                            end
                            else begin

                                wr_k_idx <= wr_k_idx + 1'b1;

                            end

                        end

                    end

                end


                // =================================================
                // One-cycle start state
                // =================================================

                ST_START: begin

                    state <= ST_RUN;

                end


                // =================================================
                // Wait Conv2 calculation
                // =================================================

                ST_RUN: begin

                    if (engine_done) begin

                        state <= ST_LOAD;

                    end

                end


                default: begin

                    state <= ST_LOAD;

                end

            endcase

        end

    end

endmodule