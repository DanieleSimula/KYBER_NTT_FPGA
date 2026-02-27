`timescale 1ns / 1ps
module uart_top #(parameter
    DATA_BITS = 8,
    STOP_TICK = 16,
    BR_COUNT  = 651, //651 per 9600 bps e 54 per 115200 bps con clock a 100 MHz
    BR_BITS   = 10,
    FIFO_EXP  = 8)(
    
    input clk, rst, 
    input read_uart, write_uart,         //Control signals
    input rx_data_in,                    //Serial in data (RX pin)
    input tx_switch,                     //Switch per abilitare trasmissione
    input [DATA_BITS-1:0] write_data,    //Parallel Data to TX-FIFO
    
    output fifo_rx_full, fifo_rx_empty,  //RX FIFO status LEDs
    output tx_full, tx_empty,            //TX FIFO status LEDs  
    output tx_data_out,                  //Serial out data (TX pin)
    output [DATA_BITS-1:0] read_data     //Parallel Data from RX-FIFO
    );
    
    //Interconnect wires
    wire tick;
    wire rx_done, tx_done;
    wire tx_fifo_empty, tx_fifo_not_empty;
    wire [DATA_BITS-1:0] tx_fifo_out, rx_fifo_in;
    
    //Connecting all modules
    baud_rate_generator #(.N(BR_BITS), .COUNT(BR_COUNT)) 
    baud_rate_gen_module (.clk(clk), .rst(rst), .tick(tick));
    
    uart_receiver       #(.DATA_BITS(DATA_BITS), .STOP_TICK(STOP_TICK)) 
    uart_rx_module       (.clk(clk), .rst(rst), .rx_data(rx_data_in), .sample_tick(tick), 
                          .data_out(rx_fifo_in), .data_ready(rx_done));
   
    fifo                #(.DATA_SIZE(DATA_BITS), .ADDR_SIZE_EXP(FIFO_EXP)) 
    fifo_rx_module       (.clk(clk), .rst(rst), .rd_from_fifo(read_uart), .wr_to_fifo(rx_done),
                          .wr_data_in(rx_fifo_in), .rd_data_out(read_data), .empty(fifo_rx_empty), .full(fifo_rx_full));                     
                      
    fifo                #(.DATA_SIZE(DATA_BITS), .ADDR_SIZE_EXP(FIFO_EXP)) 
    fifo_tx_module       (.clk(clk), .rst(rst), .rd_from_fifo(tx_done), .wr_to_fifo(write_uart && tx_switch),
                          .wr_data_in(write_data), .rd_data_out(tx_fifo_out), .empty(tx_empty), .full(tx_full));
                                                
    uart_transmitter    #(.DATA_BITS(DATA_BITS), .STOP_TICK(STOP_TICK)) 
    uart_tx_module       (.clk(clk), .rst(rst), .tx_start(tx_fifo_not_empty), .sample_tick(tick), 
                          .data_in(tx_fifo_out), .tx_done(tx_done), .tx_data(tx_data_out));
   
    assign tx_fifo_not_empty = ~tx_empty;
    
endmodule