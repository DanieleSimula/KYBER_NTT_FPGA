`timescale 1ns / 1ps
module uart_reader_fsm (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire       rx_empty,
    input  wire       sel_byte,    // 1=MSB atteso, 0=LSB atteso
    input  wire       cnt_done,    // cnt == 255
    output reg        init_regs,   // resetta cnt e sel_byte (IDLE)
    output reg        fifo_rd,     // abilita lettura FIFO per 1 ciclo (READ)
    output reg        en_merge,    // elabora byte ricevuto (MERGE)
    output reg        done         // ricezione completata (DONE)
);

    parameter [2:0]
        IDLE  = 3'd0,
        WAIT  = 3'd1,
        READ  = 3'd2,
        MERGE = 3'd3,
        DONE  = 3'd4;

    reg [2:0] state, state_next;


    always @(posedge clk or posedge rst) begin
        if (rst) state <= IDLE;
        else     state <= state_next;
    end

    always @(state, start, rx_empty, sel_byte, cnt_done) begin
        case (state)
            IDLE:    state_next = start                   ? WAIT  : IDLE;
            WAIT:    state_next = rx_empty                ? WAIT  : READ;
            READ:    state_next = MERGE;
            MERGE:   state_next = (!sel_byte && cnt_done) ? DONE  : WAIT;
            DONE:    state_next = start                   ? DONE  : IDLE;
            default: state_next = IDLE;
        endcase
    end

    always @(state) begin
        case (state)
            IDLE: begin
                init_regs   = 1'b1;
                fifo_rd = 1'b0;
                en_merge    = 1'b0;
                done        = 1'b0;
            end
            WAIT: begin
                init_regs   = 1'b0;
                fifo_rd = 1'b0;
                en_merge    = 1'b0;
                done        = 1'b0;
            end
            READ: begin
                init_regs   = 1'b0;
                fifo_rd = 1'b1;
                en_merge    = 1'b0;
                done        = 1'b0;
            end
            MERGE: begin
                init_regs   = 1'b0;
                fifo_rd = 1'b0;
                en_merge    = 1'b1;
                done        = 1'b0;
            end
            DONE: begin
                init_regs   = 1'b0;
                fifo_rd = 1'b0;
                en_merge    = 1'b0;
                done        = 1'b1;
            end
            default: begin
                init_regs   = 1'b0;
                fifo_rd = 1'b0;
                en_merge    = 1'b0;
                done        = 1'b0;
            end
        endcase
    end

endmodule
