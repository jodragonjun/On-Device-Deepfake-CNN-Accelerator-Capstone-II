`timescale 1ns/1ps

module conv2_controller_fsm #(
    parameter integer K_TERMS   = 288,
    parameter integer OC_GROUPS = 16
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       start,

    // PE4 -> Controller
    input  wire       result_valid,

    // Serializer -> Controller
    input  wire       serializer_done,

    // Controller -> Memory
    output reg        mem_req,
    output reg [8:0]  k,
    output reg [3:0]  oc_group,

    // Controller -> PE4
    output reg        clear_acc,
    output reg        pe_valid,

    // Controller -> Serializer
    output reg        serializer_start,

    // Controller -> Top
    output reg        done
);

    // ---------------------------------------------------------
    // State definition
    // ---------------------------------------------------------

    localparam [3:0]
        IDLE      = 4'd0,
        CLEAR     = 4'd1,
        RUN       = 4'd2,
        DRAIN     = 4'd3,
        SER_START = 4'd4,
        SER_WAIT  = 4'd5,
        NEXT      = 4'd6,
        DONE_ST   = 4'd7;

    reg [3:0] state;
    reg [3:0] next_state;


    // ---------------------------------------------------------
    // State register + counters
    // ---------------------------------------------------------

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            k          <= 9'd0;
            oc_group   <= 4'd0;
            pe_valid   <= 1'b0;
        end
        else begin
            state <= next_state;

            // -------------------------------------------------
            // Memory request -> PE valid
            //
            // Memory latency = 1 cycle
            // 따라서 mem_req를 1클럭 지연시켜 PE valid로 사용
            // -------------------------------------------------
            pe_valid <= mem_req;


            // -------------------------------------------------
            // Start of one Conv2 operation
            // -------------------------------------------------
            if ((state == IDLE) && start) begin
                k        <= 9'd0;
                oc_group <= 4'd0;
            end


            // -------------------------------------------------
            // Before starting a new OC group
            // -------------------------------------------------
            else if (state == CLEAR) begin
                k <= 9'd0;
            end


            // -------------------------------------------------
            // RUN
            //
            // One memory request every clock.
            // k = 0 ~ 287
            // -------------------------------------------------
            else if (state == RUN) begin
                if (k < K_TERMS - 1)
                    k <= k + 1'b1;
                else
                    k <= k;
            end


            // -------------------------------------------------
            // Move to next output-channel group
            // -------------------------------------------------
            else if (state == NEXT) begin
                k <= 9'd0;

                if (oc_group < OC_GROUPS - 1)
                    oc_group <= oc_group + 1'b1;
            end
        end
    end


    // ---------------------------------------------------------
    // Next-state logic + control outputs
    // ---------------------------------------------------------

    always @(*) begin

        // Default values
        next_state       = state;

        mem_req          = 1'b0;
        clear_acc        = 1'b0;
        serializer_start = 1'b0;
        done             = 1'b0;


        case (state)

            // -------------------------------------------------
            // Wait for start
            // -------------------------------------------------
            IDLE: begin
                if (start)
                    next_state = CLEAR;
            end


            // -------------------------------------------------
            // Clear four PE accumulators
            // -------------------------------------------------
            CLEAR: begin
                clear_acc  = 1'b1;
                next_state = RUN;
            end


            // -------------------------------------------------
            // Request k=0~287 from memory
            // -------------------------------------------------
            RUN: begin
                mem_req = 1'b1;

                if (k == K_TERMS - 1)
                    next_state = DRAIN;
            end


            // -------------------------------------------------
            // All memory requests are finished.
            //
            // Last data may still be inside:
            // Memory -> PE pipeline -> accumulator
            //
            // Wait until PE says final result is ready.
            // -------------------------------------------------
            DRAIN: begin
                if (result_valid)
                    next_state = SER_START;
            end


            // -------------------------------------------------
            // One-cycle pulse to start serializer
            // -------------------------------------------------
            SER_START: begin
                serializer_start = 1'b1;
                next_state       = SER_WAIT;
            end


            // -------------------------------------------------
            // Wait until result0~3 are serialized
            // -------------------------------------------------
            SER_WAIT: begin
                if (serializer_done)
                    next_state = NEXT;
            end


            // -------------------------------------------------
            // Decide whether to calculate next OC group
            // -------------------------------------------------
            NEXT: begin
                if (oc_group == OC_GROUPS - 1)
                    next_state = DONE_ST;
                else
                    next_state = CLEAR;
            end


            // -------------------------------------------------
            // Conv2 calculation complete
            // -------------------------------------------------
            DONE_ST: begin
                done       = 1'b1;
                next_state = IDLE;
            end


            default: begin
                next_state = IDLE;
            end

        endcase
    end

endmodule