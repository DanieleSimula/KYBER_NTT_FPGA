module uart_unit (
    input  wire        clk,
    input  wire        rst,
    
    input  wire        uart_RX,
    output wire        uart_TX,
    
    input  wire        start_tx_pulse,
    input  wire        uart_mode,
    input  wire        start_rx,
    
    input  wire        drv_rd_valid,
    input  wire [15:0] drv_rj_out,
    
    output wire [7:0]  uart_rd_addr,
    output wire [7:0]  uart_wr_addr,
    output wire        uart_rd_req,
    output wire        uart_wr_req,
    output wire [15:0] uart_data_out,
    
    output wire        fifo_tx_full,
    output wire        fifo_tx_empty,
    output wire        fifo_rx_full,
    output wire        fifo_rx_empty,
    output wire        uart_tx_done,
    output wire        ram_loaded,
    output wire        running
);

    wire [7:0]  rx_data;
    wire        uart_read_enable;
    wire [7:0]  ascii_char;
    wire        write_char;
    wire        converter_ready;

    uart_top U_UART_TOP (
        .clk(clk),
        .rst(rst),
        .read_uart(uart_read_enable),
        .write_uart(write_char && uart_mode),
        .rx_data_in(uart_RX),
        .tx_switch(running),
        .write_data(ascii_char),
        .fifo_rx_full(fifo_rx_full),
        .fifo_rx_empty(fifo_rx_empty),
        .tx_full(fifo_tx_full),
        .tx_empty(fifo_tx_empty),
        .tx_data_out(uart_TX),
        .read_data(rx_data)
    );

    data_converter U_DATA_CONVERTER (
        .clk(clk),
        .rst(rst),
        .enable(drv_rd_valid && uart_mode),
        .data_in(drv_rj_out),
        .ascii_char(ascii_char),
        .ready(converter_ready),
        .write_char(write_char)
    );

    uart_writer U_UART_WRITER (
        .clk(clk),
        .rst(rst),
        .start(start_tx_pulse && uart_mode),
        .tx_empty(fifo_tx_empty),
        .rd_valid(drv_rd_valid),
        .converter_ready(converter_ready),
        .cnt(uart_rd_addr),
        .done(uart_tx_done),
        .rd_req(uart_rd_req),
        .running(running)
    );

    uart_reader U_UART_READER (
        .clk(clk),
        .rst(rst),
        .start(start_rx),
        .rx_empty(fifo_rx_empty),
        .cnt(uart_wr_addr),
        .rx_data_in(rx_data),
        .out_rx(uart_data_out),
        .read_uart(uart_read_enable),
        .done(ram_loaded),
        .wr_req(uart_wr_req)
    );

endmodule