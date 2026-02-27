module ntt_fsm(
    input  wire clk,
    input  wire rst,

    // Handshake
    input  wire rom_valid,
    input  wire ram_rd_valid,    // Deve diventare alto quando ENTRAMBE le coppie sono pronte
    input  wire butterfly_ready, // Deve essere AND(ready0, ready1)
    input  wire ram_wr_done,     // Deve segnalare fine scrittura della seconda coppia

    // Hit signals (Logica aggiornata esternamente per step di 2)
    input  wire hit_j,
    input  wire hit_start,
    input  wire hit_len,

    //Trasmissione/Ricezione UART completata
    input wire end_tx,
    input wire end_rx,
    
    // Controllo manuale avvio calcolo butterfly
    input wire start_butterfly,

    // Output UART
    output reg start_rx,

    // Outputs Controllo Contatori
    output reg cnt_k_load,
    output reg cnt_k_inc,
    output reg cnt_start_load,
    output reg cnt_start_upd,
    output reg cnt_j_load,
    output reg cnt_j_inc,      // Esternamente questo triggera +2
    output reg cnt_len_load,
    output reg cnt_len_shift,

    // Outputs Controllo Memoria/Calcolo
    output reg rom_req,
    output reg ram_rd_req,
    output reg ram_wr_req,
    output reg ram_sel_pair,   // 0: Coppia pari (j), 1: Coppia dispari (j+1)
    output reg butterfly_valid,
    output reg done,
    output reg uart_mode,
    output reg clear_ram_driver
);

    //=========================================================
    // Stati FSM
    //=========================================================
    parameter IDLE        = 4'd0;
    parameter RAM_LOAD    = 4'd1;
    parameter WAIT_START  = 4'd2;  // Attende start_butterfly in uart_mode
    parameter INIT        = 4'd3;
    parameter PREP_BLOCK  = 4'd4; // Stato cuscinetto anti-race condition
    parameter ROM_REQ     = 4'd5;
    
    // Stati RAM READ Split (2 cicli)
    parameter RAM_READ_0  = 4'd6; 
    parameter RAM_READ_1  = 4'd7;  
    
    parameter WAIT_DATA   = 4'd8;
    parameter BUTTERFLY   = 4'd9;
    
    // Stati RAM WRITE Split (2 cicli)
    parameter RAM_WRITE_0 = 4'd10;
    parameter RAM_WRITE_1 = 4'd11;

    parameter NEXT_J      = 4'd12;
    parameter NEXT_START  = 4'd13;
    parameter NEXT_LEN    = 4'd14;
    parameter DONE        = 4'd15;

    reg [3:0] state, state_next;

    //=========================================================
    // 1. BLOCCO SEQUENZIALE
    //=========================================================
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else
            state <= state_next;
    end

    //=========================================================
    // 2. BLOCCO COMBINATORIO NEXT STATE
    //=========================================================
    always @(state, rom_valid, ram_rd_valid, butterfly_ready, ram_wr_done, hit_j, hit_start, hit_len, end_tx, end_rx, start_butterfly) begin
        
        state_next = state; // Default latch prevention

        case (state)
            IDLE:       state_next = RAM_LOAD;

            RAM_LOAD:  if(end_rx) state_next = WAIT_START;
                         else state_next = RAM_LOAD;
            
            WAIT_START: if(start_butterfly) state_next = INIT;
                          else state_next = WAIT_START;
            
            INIT:       state_next = PREP_BLOCK; 

            PREP_BLOCK: state_next = ROM_REQ;

            ROM_REQ:    if (rom_valid) state_next = RAM_READ_0;

            // --- FASE LETTURA SPLIT ---
            // Ciclo 1: Richiede coppia j, j+len
            RAM_READ_0: state_next = RAM_READ_1; 
            // Ciclo 2: Richiede coppia j+1, j+1+len
            RAM_READ_1: state_next = WAIT_DATA;

            // Attende che il ram_driver abbia validato TUTTI i 4 dati
            WAIT_DATA:  if (ram_rd_valid)    state_next = BUTTERFLY;
            
            // Attende che entrambe le butterfly abbiano finito
            BUTTERFLY:  if (butterfly_ready) state_next = RAM_WRITE_0;
            
            // --- FASE SCRITTURA SPLIT ---
            // Ciclo 1: Scrive coppia j, j+len
            RAM_WRITE_0: state_next = RAM_WRITE_1;
            // Ciclo 2: Scrive coppia j+1, j+1+len e aspetta done
            RAM_WRITE_1: if (ram_wr_done)     state_next = NEXT_J;

            NEXT_J: begin
                // hit_j ora deve scattare quando siamo a (start + len - 2)
                if (hit_j) state_next = NEXT_START;
                else       state_next = ROM_REQ;
            end

            NEXT_START: begin
                if (hit_start) state_next = NEXT_LEN;
                else           state_next = PREP_BLOCK; 
            end

            NEXT_LEN: begin
                if (hit_len) state_next = DONE;
                else         state_next = PREP_BLOCK;
            end
                    
            DONE: if(end_tx) state_next = IDLE;
                    else state_next = DONE;
            
            default: state_next = IDLE;
        endcase
    end

    //=========================================================
    // 3. BLOCCO COMBINATORIO OUTPUT
    //=========================================================
    always @(state) begin
        // Defaults
        cnt_k_load = 0; cnt_k_inc = 0;
        cnt_start_load = 0; cnt_start_upd = 0;
        cnt_j_load = 0; cnt_j_inc = 0;
        cnt_len_load = 0; cnt_len_shift = 0;
        
        rom_req = 0; 
        ram_rd_req = 0; 
        ram_wr_req = 0; 
        ram_sel_pair = 0; // Default a offset 0
        
        butterfly_valid = 0; 
        done = 0;
        uart_mode = 0;
        start_rx = 0;
        clear_ram_driver = 0;

        case (state)
            IDLE: begin
                clear_ram_driver = 1;
            end

            RAM_LOAD: begin
                clear_ram_driver = 0;
                uart_mode = 1;
                start_rx = 1;
            end
            
            WAIT_START: begin
                uart_mode = 1;  // Rimane in modalità UART
                start_rx = 0;   // Non richiede più lettura
            end

            INIT: begin
                start_rx = 0;
                uart_mode = 0;
                cnt_k_load     = 1;
                cnt_len_load   = 1;
                cnt_start_load = 1;
            end

            PREP_BLOCK: begin
                cnt_j_load = 1; 
            end

            ROM_REQ: rom_req = 1;

            // --- LETTURA ---
            RAM_READ_0: begin
                ram_rd_req = 1;
                ram_sel_pair = 0; // Richiedi j, j+len
            end
            RAM_READ_1: begin
                ram_rd_req = 1;
                ram_sel_pair = 1; // Richiedi j+1, j+1+len
            end

            // Nello stato WAIT_DATA ram_rd_req torna a 0, il driver processa la pipeline

            BUTTERFLY: butterfly_valid = 1; // Start calcolo parallelo

            // --- SCRITTURA ---
            RAM_WRITE_0: begin
                ram_wr_req = 1;
                ram_sel_pair = 0; // Scrivi j, j+len
            end
            RAM_WRITE_1: begin
                ram_wr_req = 1;
                ram_sel_pair = 1; // Scrivi j+1, j+1+len
            end

            NEXT_J: cnt_j_inc = 1; // Questo incrementa di 2 nel contatore esterno

            NEXT_START: begin
                cnt_start_upd = 1;
                cnt_k_inc     = 1;
            end

            NEXT_LEN: begin
                cnt_len_shift  = 1;
                cnt_start_load = 1;
            end

            DONE: begin
                done = 1;
                uart_mode = 1;
            end
        endcase
    end

endmodule