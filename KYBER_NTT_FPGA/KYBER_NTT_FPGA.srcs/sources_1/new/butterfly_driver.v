module butterfly_driver (
    input  wire clk,
    input  wire rst,

    // --- Input dal RAM Driver ---
    input  wire drv_rd_valid,
    input  wire signed [15:0] drv_rj_in,
    input  wire signed [15:0] drv_rjl_in,

    // --- Segnali di Controllo dalla FSM ---
    input  wire ram_wr_req,    // Reset flag (inizio fase scrittura)
    input  wire cnt_j_inc,     // Reset flag (passaggio al prossimo blocco)
    input  wire ram_sel_pair,  // 0=Address J, 1=Address J+1

    // --- Verso le Butterfly (Output Registrati) ---
    output reg  signed [15:0] to_butt0_rj,  to_butt0_rjl,
    output reg  signed [15:0] to_butt1_rj,  to_butt1_rjl,
    
    // --- Dalle Butterfly ---
    input  wire butt0_ready,
    input  wire butt1_ready,
    input  wire signed [15:0] butt0_out_rj, butt0_out_rjl,
    input  wire signed [15:0] butt1_out_rj, butt1_out_rjl,

    // --- Output di Stato verso FSM ---
    output wire all_data_loaded,       
    output wire all_butterflies_ready, 
    
    // --- Output verso RAM Driver ---
    output wire signed [15:0] ram_din_rj,
    output wire signed [15:0] ram_din_rjl
);

    // ========================================================
    // 1. DEFINIZIONE REGISTRI (Stato Corrente e Next State)
    // ========================================================
    reg got_pair_0;
    reg got_pair_1;
    
    reg got_pair_0_next;
    reg got_pair_1_next;
    reg signed [15:0] to_butt0_rj_next,  to_butt0_rjl_next;
    reg signed [15:0] to_butt1_rj_next,  to_butt1_rjl_next;

    // ========================================================
    // 2. LOGICA SEQUENZIALE (Clocked)
    // ========================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            got_pair_0   <= 1'b0;
            got_pair_1   <= 1'b0;
            to_butt0_rj  <= 16'd0; 
            to_butt0_rjl <= 16'd0;
            to_butt1_rj  <= 16'd0; 
            to_butt1_rjl <= 16'd0;
        end else begin
            got_pair_0   <= got_pair_0_next;
            got_pair_1   <= got_pair_1_next;
            to_butt0_rj  <= to_butt0_rj_next;
            to_butt0_rjl <= to_butt0_rjl_next;
            to_butt1_rj  <= to_butt1_rj_next;
            to_butt1_rjl <= to_butt1_rjl_next;
        end
    end

    // ========================================================
    // 3. LOGICA COMBINATORIA (Sensitivity List Esplicita)
    // ========================================================
    always @(
        cnt_j_inc, ram_wr_req, drv_rd_valid,
        drv_rj_in, drv_rjl_in,
        got_pair_0, got_pair_1,
        to_butt0_rj, to_butt0_rjl,
        to_butt1_rj, to_butt1_rjl
    ) begin
        
        // --- Defaults ---
        got_pair_0_next   = got_pair_0;
        got_pair_1_next   = got_pair_1;
        to_butt0_rj_next  = to_butt0_rj;
        to_butt0_rjl_next = to_butt0_rjl;
        to_butt1_rj_next  = to_butt1_rj;
        to_butt1_rjl_next = to_butt1_rjl;

        // --- Logic ---
        if (cnt_j_inc || ram_wr_req) begin
            got_pair_0_next = 1'b0;
            got_pair_1_next = 1'b0;
        end
        else if (drv_rd_valid) begin
            if (!got_pair_0) begin
                to_butt0_rj_next  = drv_rj_in;
                to_butt0_rjl_next = drv_rjl_in;
                got_pair_0_next   = 1'b1;
            end 
            else begin
                to_butt1_rj_next  = drv_rj_in;
                to_butt1_rjl_next = drv_rjl_in;
                got_pair_1_next   = 1'b1;
            end
        end
    end

    // ========================================================
    // 4. LOGICA DI OUTPUT (MUX INVERTITO)
    // ========================================================
    assign all_data_loaded       = got_pair_0 && got_pair_1;
    assign all_butterflies_ready = butt0_ready && butt1_ready;

    // --- CORREZIONE DEFINITIVA ---
    // Abbiamo invertito la logica qui sotto.
    // Se sel_pair=0 (Indirizzo Pari) -> Manda Butt1
    // Se sel_pair=1 (Indirizzo Dispari) -> Manda Butt0
    assign ram_din_rj  = (ram_sel_pair == 1'b0) ? butt1_out_rj  : butt0_out_rj;
    assign ram_din_rjl = (ram_sel_pair == 1'b0) ? butt1_out_rjl : butt0_out_rjl;

endmodule

