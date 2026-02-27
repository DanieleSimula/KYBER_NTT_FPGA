//=============================================================================
// MODULO: ram_driver
// DESCRIZIONE: Interfaccia di accesso alla RAM dual-port.
//              Supporta due modalità:
//              - NTT (read_mode=0): accesso simultaneo a coppie butterfly
//                agli indirizzi j+sel_pair e j+sel_pair+len
//              - UART (read_mode=1): accesso sequenziale singolo per I/O dati.
//=============================================================================

module ram_driver (
    input  wire        clk,
    input  wire        rst,
    input  wire        clear,
    input  wire        sel_pair,  // 0 = coppia pari (j), 1 = coppia dispari (j+1)
    input  wire        read_mode, // 1 = lettura/scrittura normale singola (UART), 0 = lettura/scrittura doppia(NTT)

    // porte per la lettura
    input  wire        rd_req,
    input  wire [8:0]  j,       
    input  wire [7:0]  len,     
    output reg  signed [15:0] rj,
    output reg  signed [15:0] rjl,
    output reg         rd_valid,

    // porte per la scrittura
    input  wire        wr_req,
    input  wire [8:0]  j_wr,    
    input  wire [7:0]  len_wr,  
    input  wire signed [15:0] outrj,
    input  wire signed [15:0] outrjl,
    output reg         wr_done
);

   
    reg [8:0]  addr_j_reg, addr_l_reg;
    reg [1:0]  valid_pipe;              // Pipeline 2 cicli per latenza RAM
    
    
    reg [8:0]  addr_j_next, addr_l_next;
    reg [1:0]  valid_pipe_next;
    
    reg signed [15:0] rj_next, rjl_next;
    reg        rd_valid_next;
    reg        wr_done_next;

    wire signed [15:0] ram_rj_out;
    wire signed [15:0] ram_rjl_out;

    //ram dual port
    ram_dual RAM (
        .clk    (clk),
        .we_a   (wr_req),
        .addr_a (addr_j_reg),
        .din_a  (outrj),
        .dout_a (ram_rj_out),
        .we_b   (wr_req & ~read_mode),  //porta b spenta durante la modalita uart
        .addr_b (addr_l_reg),
        .din_b  (outrjl),
        .dout_b (ram_rjl_out)
    );

    
    always @(posedge clk or posedge rst) begin
        if (rst || clear) begin
            addr_j_reg  <= 9'd0;
            addr_l_reg  <= 9'd0;
            valid_pipe  <= 2'b00;
            rj          <= 16'sd0;
            rjl         <= 16'sd0;
            rd_valid    <= 1'b0;
            wr_done     <= 1'b0;
        end else begin
            addr_j_reg  <= addr_j_next;
            addr_l_reg  <= addr_l_next;
            valid_pipe  <= valid_pipe_next;
            rj          <= rj_next;
            rjl         <= rjl_next;
            rd_valid    <= rd_valid_next;
            wr_done     <= wr_done_next;
        end
    end

    always @(rd_req, wr_req, j, sel_pair, len, j_wr, len_wr, read_mode, valid_pipe, ram_rj_out, ram_rjl_out, addr_j_reg, addr_l_reg, rj, rjl) begin
        
        addr_j_next     = addr_j_reg;
        addr_l_next     = addr_l_reg;
        valid_pipe_next = {valid_pipe[0], 1'b0};
        rj_next         = rj;
        rjl_next        = rjl;
        rd_valid_next   = 1'b0;
        wr_done_next    = 1'b0;
        
        if (rd_req) begin
            if(read_mode) begin 
                addr_j_next = j;
                valid_pipe_next = {valid_pipe[0], 1'b1};
            end
            else begin
                addr_j_next     = j + sel_pair;
                addr_l_next     = (j + sel_pair) + len;
                valid_pipe_next = {valid_pipe[0], 1'b1};
            end
        end
        else if (wr_req) begin
            if(read_mode) begin
                addr_j_next = j_wr;
                wr_done_next = 1'b1;
            end
            else begin
                addr_j_next     = j_wr + sel_pair;
                addr_l_next     = (j_wr + sel_pair) + len_wr;
                wr_done_next    = 1'b1;
            end
        end

        if (valid_pipe[1]) begin
            rj_next = ram_rj_out;
            rd_valid_next = 1'b1;
            
            // In modalità NTT leggi anche rjl, in modalità UART solo rj
            if (!read_mode) begin
                rjl_next = ram_rjl_out;
            end
        end
    end

endmodule