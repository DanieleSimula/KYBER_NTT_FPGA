`timescale 1ns / 1ps
module uart_writer_fsm (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire       tx_empty,
    input  wire       rd_valid,
    input  wire       converter_ready,
    input  wire       cnt_done,        // cnt == 255
    output reg        load_cnt,        // resetta cnt=0 (IDLE+start)
    output reg        inc_cnt,         // incrementa cnt (WAIT_CONV)
    output reg        rd_req,          // richiede lettura RAM (REQ_RD)
    output reg        done,            // trasmissione completata (DONE)
    output reg        running          // state != IDLE
);

    parameter [2:0]
        IDLE      = 3'b000,
        REQ_RD    = 3'b001,
        WAIT_RD   = 3'b010,
        WAIT_CONV = 3'b011,
        DONE      = 3'b100;

    reg [2:0] state, state_next;

    always @(posedge clk or posedge rst) begin
        if (rst) state <= IDLE;
        else     state <= state_next;
    end

    always @(state, start, tx_empty, rd_valid, converter_ready, cnt_done) begin
        case (state)
            IDLE:      state_next = start    ? REQ_RD    : IDLE;
            REQ_RD:    state_next = tx_empty ? WAIT_RD   : REQ_RD;
            WAIT_RD:   state_next = rd_valid ? WAIT_CONV : WAIT_RD;
            WAIT_CONV: begin
                if (converter_ready && tx_empty)
                    state_next = cnt_done ? DONE   : REQ_RD;
                else
                    state_next = WAIT_CONV;
            end
            DONE:      state_next = IDLE;
            default:   state_next = IDLE;
        endcase
    end

    always @(state, start, tx_empty, converter_ready, cnt_done) begin
        case (state)
            IDLE: begin
                load_cnt = start ? 1'b1 : 1'b0;
                inc_cnt  = 1'b0;
                rd_req   = 1'b0;
                done     = 1'b0;
                running  = 1'b0;
            end
            REQ_RD: begin
                load_cnt = 1'b0;
                inc_cnt  = 1'b0;
                rd_req   = 1'b1;
                done     = 1'b0;
                running  = 1'b1;
            end
            WAIT_RD: begin
                load_cnt = 1'b0;
                inc_cnt  = 1'b0;
                rd_req   = 1'b0;
                done     = 1'b0;
                running  = 1'b1;
            end
            WAIT_CONV: begin
                load_cnt = 1'b0;
                inc_cnt  = (converter_ready && tx_empty && !cnt_done) ? 1'b1 : 1'b0;
                rd_req   = 1'b0;
                done     = 1'b0;
                running  = 1'b1;
            end
            DONE: begin
                load_cnt = 1'b0;
                inc_cnt  = 1'b0;
                rd_req   = 1'b0;
                done     = 1'b1;
                running  = 1'b1;
            end
            default: begin
                load_cnt = 1'b0;
                inc_cnt  = 1'b0;
                rd_req   = 1'b0;
                done     = 1'b0;
                running  = 1'b0;
            end
        endcase
    end

endmodule
