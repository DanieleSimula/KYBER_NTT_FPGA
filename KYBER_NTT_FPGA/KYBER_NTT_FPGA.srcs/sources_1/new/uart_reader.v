`timescale 1ns / 1ps
module uart_reader(
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire        rx_empty,
    input  wire [7:0]  rx_data_in,

    output reg  [7:0]  cnt,
    output reg  [15:0] out_rx,
    output reg         read_uart,
    output wire        done,
    output reg         wr_req
);

    wire init_regs;   // resetta cnt e sel_byte
    wire fifo_rd;     // abilita lettura FIFO (registrata → 1 ciclo dopo READ)
    wire en_merge;    // elabora byte ricevuto

    reg sel_byte;

    reg [7:0]  cnt_next;
    reg [15:0] out_rx_next;
    reg        read_uart_next;
    reg        wr_req_next;
    reg        sel_byte_next;

    wire cnt_done;

    assign cnt_done = (cnt == 8'd255);

    uart_reader_fsm U_FSM (
        .clk        (clk),
        .rst        (rst),
        .start      (start),
        .rx_empty   (rx_empty),
        .sel_byte   (sel_byte),
        .cnt_done   (cnt_done),
        .init_regs  (init_regs),
        .fifo_rd    (fifo_rd),
        .en_merge   (en_merge),
        .done       (done)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt       <= 8'd0;
            sel_byte  <= 1'b1;
            out_rx    <= 16'd0;
            read_uart <= 1'b0;
            wr_req    <= 1'b0;
        end else begin
            cnt       <= cnt_next;
            sel_byte  <= sel_byte_next;
            out_rx    <= out_rx_next;
            read_uart <= read_uart_next;
            wr_req    <= wr_req_next;
        end
    end

    always @(init_regs, fifo_rd, en_merge, sel_byte, cnt, out_rx, rx_data_in) begin
        if (init_regs) begin
            cnt_next       = 8'd0;
            sel_byte_next  = 1'b1;
            out_rx_next    = out_rx;
            read_uart_next = fifo_rd;
            wr_req_next    = 1'b0;
        end else if (en_merge && sel_byte) begin
            // MSB ricevuto
            cnt_next       = cnt;
            sel_byte_next  = 1'b0;
            out_rx_next    = {rx_data_in, out_rx[7:0]};
            read_uart_next = fifo_rd;
            wr_req_next    = 1'b0;
        end else if (en_merge && !sel_byte) begin
            // LSB ricevuto → word completa
            cnt_next       = cnt + 8'd1;
            sel_byte_next  = 1'b1;
            out_rx_next    = {out_rx[15:8], rx_data_in};
            read_uart_next = fifo_rd;
            wr_req_next    = 1'b1;
        end else begin
            cnt_next       = cnt;
            sel_byte_next  = sel_byte;
            out_rx_next    = out_rx;
            read_uart_next = fifo_rd;
            wr_req_next    = 1'b0;
        end
    end

    

endmodule
