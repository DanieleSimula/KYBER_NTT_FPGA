//=============================================================
// NTT DATAPATH - Contiene tutti i componenti operativi
//=============================================================

module ntt_datapath (
    input  wire clk,
    input  wire rst,
    
    // ========================================================
    // SEGNALI DI CONTROLLO DALLA FSM
    // ========================================================
    input  wire cnt_k_load,
    input  wire cnt_k_inc,
    input  wire cnt_start_load,
    input  wire cnt_start_upd,
    input  wire cnt_j_load,
    input  wire cnt_j_inc,
    input  wire cnt_len_load,
    input  wire cnt_len_shift,
    input  wire rom_req,
    input  wire ram_rd_req,
    input  wire ram_wr_req,
    input  wire ram_sel_pair,
    input  wire butterfly_valid_fsm,
    input  wire uart_mode,
    input  wire clear_ram_driver,
    input  wire start_rx,
    
    // ========================================================
    // SEGNALI DI STATUS VERSO FSM
    // ========================================================
    output wire rom_valid_sig,
    output wire all_data_loaded,
    output wire all_butterflies_ready,
    output wire ram_wr_done_sig,
    output wire hit_j,
    output wire hit_start,
    output wire hit_len,
    output wire uart_tx_done,
    output wire ram_loaded,
    
    // ========================================================
    // INTERFACCIA UART ESTERNA
    // ========================================================
    input  wire start_tx_pulse,
    input  wire uart_RX,
    output wire uart_TX,
    output wire fifo_tx_full,
    output wire fifo_tx_empty,
    output wire fifo_rx_full,
    output wire fifo_rx_empty,
    output wire running
);

    // ========================================================
    // SEGNALI INTERNI
    // ========================================================
    
    // --- Contatori ---
    wire [7:0]  k_idx;
    wire [8:0]  j_idx;
    wire [8:0]  start_idx;
    wire [7:0]  len_val;
    wire [15:0] zeta_val;

    // --- RAM Driver ---
    wire [15:0] drv_rj_out, drv_rjl_out;
    wire drv_rd_valid;
    wire [15:0] driver_din_rj, driver_din_rjl;

    // --- UART ---
    wire [7:0]  uart_rd_addr;
    wire [7:0]  uart_wr_addr;
    wire        uart_wr_enable;
    wire        uart_rd_req;
    wire        uart_wr_req;
    wire [7:0]  rx_data;
    wire [15:0] uart_reader_out;
    wire        uart_read_enable;

    // --- Data Converter ---
    wire [7:0]  ascii_char;
    wire        converter_ready;
    wire        write_char;

    // --- Multiplexer ---
    wire [8:0]  ram_wr_addr_mux;
    wire [8:0]  ram_rd_addr_mux;
    wire        ram_rd_req_mux;
    wire        ram_wr_req_mux;
    wire [15:0] ram_wr_data_mux_rj;
    
    assign ram_rd_addr_mux     = uart_mode ? {1'b0, uart_rd_addr} : j_idx;
    assign ram_rd_req_mux      = uart_mode ? uart_rd_req : ram_rd_req;
    assign ram_wr_req_mux      = uart_mode ? uart_wr_req : ram_wr_req;
    assign ram_wr_addr_mux     = uart_mode ? {1'b0, uart_wr_addr} : j_idx;
    assign ram_wr_data_mux_rj  = uart_mode ? uart_reader_out : driver_din_rj;

    // --- Butterfly ---
    wire signed [15:0] reg_rj_0,  reg_rjl_0;
    wire signed [15:0] reg_rj_1,  reg_rjl_1;
    wire signed [15:0] butt0_out_rj, butt0_out_rjl;
    wire signed [15:0] butt1_out_rj, butt1_out_rjl;
    wire butt0_ready, butt1_ready;

    // ========================================================
    // ISTANZE MODULI
    // ========================================================

    // --- CONTATORI ---
    cnt_k U_CNT_K (
        .clk(clk), .rst(rst),
        .load(cnt_k_load), 
        .inc(cnt_k_inc),
        .k(k_idx)
    );

    cnt_len U_CNT_LEN (
        .clk(clk), .rst(rst),
        .load(cnt_len_load), 
        .shift(cnt_len_shift),
        .len(len_val),
        .hit_len(hit_len)
    );

    cnt_start U_CNT_START (
        .clk(clk), .rst(rst),
        .load(cnt_start_load), 
        .upd(cnt_start_upd),
        .len(len_val),
        .start(start_idx),
        .hit_start(hit_start)
    );

    cnt_j U_CNT_J (
        .clk(clk), .rst(rst),
        .load(cnt_j_load), 
        .inc(cnt_j_inc),
        .start(start_idx), 
        .len(len_val),
        .j(j_idx),
        .hit_j(hit_j)
    );

    // --- ROM READER ---
    rom_reader U_ROM_READER (
        .clk(clk), 
        .rst(rst),
        .req(rom_req),
        .k(k_idx),
        .zeta(zeta_val),
        .valid(rom_valid_sig)
    );

    // --- RAM DRIVER ---
    ram_driver U_RAM_DRIVER (
        .clk(clk), 
        .rst(rst),
        .clear(clear_ram_driver || uart_tx_done),
        .sel_pair(ram_sel_pair),
        .read_mode(uart_mode),
        .rd_req(ram_rd_req_mux),
        .j(ram_rd_addr_mux), 
        .len(len_val),
        .rj(drv_rj_out), 
        .rjl(drv_rjl_out),
        .rd_valid(drv_rd_valid),
        .wr_req(ram_wr_req_mux),
        .j_wr(ram_wr_addr_mux),     
        .len_wr(len_val),
        .outrj(ram_wr_data_mux_rj),
        .outrjl(driver_din_rjl),
        .wr_done(ram_wr_done_sig)
    );

    // --- BUTTERFLY DRIVER ---
    butterfly_driver U_BUTTERFLY_DRIVER (
        .clk(clk), 
        .rst(rst),
        .drv_rd_valid(drv_rd_valid && (!uart_mode)),
        .drv_rj_in(drv_rj_out),
        .drv_rjl_in(drv_rjl_out),
        .ram_wr_req(ram_wr_req),
        .cnt_j_inc(cnt_j_inc),
        .ram_sel_pair(ram_sel_pair),
        .to_butt0_rj(reg_rj_0), 
        .to_butt0_rjl(reg_rjl_0),
        .to_butt1_rj(reg_rj_1), 
        .to_butt1_rjl(reg_rjl_1),
        .butt0_ready(butt0_ready),  
        .butt1_ready(butt1_ready),
        .butt0_out_rj(butt0_out_rj), 
        .butt0_out_rjl(butt0_out_rjl),
        .butt1_out_rj(butt1_out_rj), 
        .butt1_out_rjl(butt1_out_rjl),
        .all_data_loaded(all_data_loaded),
        .all_butterflies_ready(all_butterflies_ready),
        .ram_din_rj(driver_din_rj),
        .ram_din_rjl(driver_din_rjl)
    );

    // --- BUTTERFLY UNITS ---
    butterfly U_BUTTERFLY_0 (
        .clk(clk), 
        .rst(rst),
        .in_valid(butterfly_valid_fsm),
        .zeta(zeta_val),
        .rj(reg_rj_0), 
        .rjl(reg_rjl_0),
        .ready(butt0_ready),
        .outrj(butt0_out_rj), 
        .outrjl(butt0_out_rjl)
    );

    butterfly U_BUTTERFLY_1 (
        .clk(clk), 
        .rst(rst),
        .in_valid(butterfly_valid_fsm),
        .zeta(zeta_val),
        .rj(reg_rj_1), 
        .rjl(reg_rjl_1),
        .ready(butt1_ready),
        .outrj(butt1_out_rj), 
        .outrjl(butt1_out_rjl)
    );

    uart_unit U_UART_UNIT (
        .clk(clk),
        .rst(rst),
        .uart_RX(uart_RX),
        .uart_TX(uart_TX),
        .start_tx_pulse(start_tx_pulse),
        .uart_mode(uart_mode),
        .start_rx(start_rx),
        .drv_rd_valid(drv_rd_valid),
        .drv_rj_out(drv_rj_out),
        .uart_rd_addr(uart_rd_addr),
        .uart_wr_addr(uart_wr_addr),
        .uart_rd_req(uart_rd_req),
        .uart_wr_req(uart_wr_req),
        .uart_data_out(uart_reader_out),
        .fifo_tx_full(fifo_tx_full),
        .fifo_tx_empty(fifo_tx_empty),
        .fifo_rx_full(fifo_rx_full),
        .fifo_rx_empty(fifo_rx_empty),
        .uart_tx_done(uart_tx_done),
        .ram_loaded(ram_loaded),
        .running(running)
    );

endmodule