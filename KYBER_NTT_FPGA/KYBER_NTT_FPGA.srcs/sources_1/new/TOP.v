//=============================================================
// NTT TOP LEVEL - Collega FSM e Datapath
//=============================================================

module ntt_top (
    input  wire clk,
    input  wire rst,
    input  wire start_tx,         // Avvio trasmissione UART (btn)
    input  wire start_butterfly,  // Avvio calcolo butterfly (sw2)
    input  wire uart_RX,

    output wire uart_mode,
    output wire done,
    output wire uart_TX,
    output wire fifo_tx_full,
    output wire fifo_tx_empty,
    output wire fifo_rx_full,
    output wire fifo_rx_empty
);

    // ========================================================
    // SEGNALI DI INTERCONNESSIONE FSM <-> DATAPATH
    // ========================================================
    
    // --- Controllo dalla FSM al Datapath ---
    wire cnt_k_load, cnt_k_inc;
    wire cnt_start_load, cnt_start_upd;
    wire cnt_j_load, cnt_j_inc;
    wire cnt_len_load, cnt_len_shift;
    wire rom_req;
    wire ram_rd_req, ram_wr_req;
    wire ram_sel_pair;
    wire butterfly_valid_fsm;
    wire clear_ram_driver;
    wire start_rx;

    // --- Status dal Datapath alla FSM ---
    wire rom_valid_sig;
    wire all_data_loaded;
    wire all_butterflies_ready;
    wire ram_wr_done_sig;
    wire hit_j, hit_start, hit_len;
    wire uart_tx_done;
    wire ram_loaded;

    // --- Segnali UART esterni ---
    wire start_tx_pulse;
    wire start_butterfly_pulse;
    wire running;

    // ========================================================
    // ISTANZA FSM
    // ========================================================
    ntt_fsm U_FSM (
        .clk(clk),
        .rst(rst),
        
        // Handshake
        .rom_valid(rom_valid_sig),
        .ram_rd_valid(all_data_loaded),
        .butterfly_ready(all_butterflies_ready),
        .ram_wr_done(ram_wr_done_sig),
        
        // Hit signals
        .hit_j(hit_j),
        .hit_start(hit_start),
        .hit_len(hit_len),
        
        // UART
        .end_tx(uart_tx_done),
        .end_rx(ram_loaded),
        .start_rx(start_rx),
        
        // Controllo manuale
        .start_butterfly(start_butterfly_pulse),
        
        // Controllo contatori
        .cnt_k_load(cnt_k_load),
        .cnt_k_inc(cnt_k_inc),
        .cnt_start_load(cnt_start_load),
        .cnt_start_upd(cnt_start_upd),
        .cnt_j_load(cnt_j_load),
        .cnt_j_inc(cnt_j_inc),
        .cnt_len_load(cnt_len_load),
        .cnt_len_shift(cnt_len_shift),
        
        // Controllo memoria/calcolo
        .rom_req(rom_req),
        .ram_rd_req(ram_rd_req),
        .ram_wr_req(ram_wr_req),
        .ram_sel_pair(ram_sel_pair),
        .butterfly_valid(butterfly_valid_fsm),
        .done(done),
        .uart_mode(uart_mode),
        .clear_ram_driver(clear_ram_driver)
    );

    // ========================================================
    // ISTANZA DATAPATH
    // ========================================================
    ntt_datapath U_DATAPATH (
        .clk(clk),
        .rst(rst),
        
        // Controllo dalla FSM
        .cnt_k_load(cnt_k_load),
        .cnt_k_inc(cnt_k_inc),
        .cnt_start_load(cnt_start_load),
        .cnt_start_upd(cnt_start_upd),
        .cnt_j_load(cnt_j_load),
        .cnt_j_inc(cnt_j_inc),
        .cnt_len_load(cnt_len_load),
        .cnt_len_shift(cnt_len_shift),
        .rom_req(rom_req),
        .ram_rd_req(ram_rd_req),
        .ram_wr_req(ram_wr_req),
        .ram_sel_pair(ram_sel_pair),
        .butterfly_valid_fsm(butterfly_valid_fsm),
        .uart_mode(uart_mode),
        .clear_ram_driver(clear_ram_driver),
        .start_rx(start_rx),
        
        // Status verso FSM
        .rom_valid_sig(rom_valid_sig),
        .all_data_loaded(all_data_loaded),
        .all_butterflies_ready(all_butterflies_ready),
        .ram_wr_done_sig(ram_wr_done_sig),
        .hit_j(hit_j),
        .hit_start(hit_start),
        .hit_len(hit_len),
        .uart_tx_done(uart_tx_done),
        .ram_loaded(ram_loaded),
        
        // Interfaccia UART esterna
        .start_tx_pulse(start_tx_pulse),
        .uart_RX(uart_RX),
        .uart_TX(uart_TX),
        .fifo_tx_full(fifo_tx_full),
        .fifo_tx_empty(fifo_tx_empty),
        .fifo_rx_full(fifo_rx_full),
        .fifo_rx_empty(fifo_rx_empty),
        .running(running)
    );

    // ========================================================
    // DEBOUNCER PER PULSANTI
    // ========================================================
    debounce_onepulse #(
        .CLK_FREQ(100_000_000),
        .DEBOUNCE_MS(1)
    ) U_DEB_BTN_BUTTERFLY (
        .clk(clk),
        .rst(rst),
        .button_in(start_butterfly),
        .button_pulse(start_butterfly_pulse)
    );

    debounce_onepulse #(
        .CLK_FREQ(100_000_000),
        .DEBOUNCE_MS(1)
    ) U_DEB_BTN_UART_WRITER (
        .clk(clk),
        .rst(rst),
        .button_in(start_tx),
        .button_pulse(start_tx_pulse)
    );

endmodule