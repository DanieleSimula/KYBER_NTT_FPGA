module rom_reader (
    input  wire        clk,
    input  wire        rst,
    input  wire        req,       
    input  wire [7:0]  k,         

    output reg  [15:0] zeta,      // Registrato per spezzare il percorso critico ROM->DSP
    output reg         valid      
);

    reg  [6:0] addr_reg;
    reg  [1:0] valid_pipe; 

    wire [15:0] rom_zeta_out;

    Rom ROM_ZETA (
        .clk  (clk),
        .addr (addr_reg),
        .zeta (rom_zeta_out)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            addr_reg   <= 7'd0;
            zeta       <= 16'd0;
            valid      <= 1'b0;
            valid_pipe <= 2'b00;
        end else begin
            // 1. Gestione Indirizzo
            if (req) begin
                addr_reg <= k[6:0];
            end
            
            // 2. Pipeline Valid
            valid_pipe[0] <= req;
            valid_pipe[1] <= valid_pipe[0];
            
            // 3. Registra l'uscita della ROM (spezza il percorso critico ROM->DSP)
            zeta <= rom_zeta_out;
            
            // 4. Output Valid (sincronizzato con zeta registrato)
            valid <= valid_pipe[1];
        end
    end

endmodule