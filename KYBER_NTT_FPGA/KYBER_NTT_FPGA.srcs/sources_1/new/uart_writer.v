`timescale 1ns / 1ps
module uart_writer (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire       tx_empty,
    input  wire       rd_valid,
    input  wire       converter_ready,

    output reg  [7:0] cnt,
    output wire       done,
    output wire       rd_req,
    output wire       running
);

    wire load_cnt;   
    wire inc_cnt;    

    reg [7:0] cnt_next;

    wire cnt_done;

    assign cnt_done = (cnt == 8'd255); 

    uart_writer_fsm U_FSM (
        .clk            (clk),
        .rst            (rst),
        .start          (start),
        .tx_empty       (tx_empty),
        .rd_valid       (rd_valid),
        .converter_ready(converter_ready),
        .cnt_done       (cnt_done),
        .load_cnt       (load_cnt),
        .inc_cnt        (inc_cnt),
        .rd_req         (rd_req),
        .done           (done),
        .running        (running)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) cnt <= 8'd0;
        else     cnt <= cnt_next;
    end

    always @(load_cnt, inc_cnt, cnt) begin
        if (load_cnt) begin
            cnt_next = 8'd0;
        end else if (inc_cnt) begin
            cnt_next = cnt + 8'd1;
        end else begin
            cnt_next = cnt;
        end
    end

endmodule