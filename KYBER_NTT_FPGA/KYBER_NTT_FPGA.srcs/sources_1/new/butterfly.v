module butterfly(
    input  wire              clk,
    input  wire              rst,
    input  wire              in_valid,
    input  wire signed [15:0] zeta,
    input  wire signed [15:0] rj,
    input  wire signed [15:0] rjl,

    output wire              ready,
    output wire signed [15:0] outrj,
    output wire signed [15:0] outrjl
);

    // ============================================================
    // USCITA MONTGOMERY
    // ============================================================
    wire signed [15:0] t;
    wire               t_valid;

    montgomery MGREDUCE (
        .clk       (clk),
        .rst       (rst),
        .in_valid  (in_valid),
        .zeta      (zeta),
        .rjl       (rjl),
        .t         (t),
        .out_valid (t_valid)
    );

    // ============================================================
    //  BUTTERFLY
    // ============================================================

    //calcolo la butterfly
    assign outrj  = rj + t;
    assign outrjl = rj - t;


    //Il risultato è valido quando lo è t
    assign ready = t_valid;

endmodule


module montgomery (
    input  wire               clk,
    input  wire               rst,
    input  wire               in_valid,
    input  wire signed [15:0] zeta,
    input  wire signed [15:0] rjl,
    output reg  signed [15:0] t,
    output reg                out_valid
);

    // COSTANTI BLINDATE (HEX per evitare ambiguità)
    // Q = 3329, QINV = -3327
    parameter signed [31:0] KYBER_Q_32 = 32'sd3329; 
    parameter signed [15:0] QINV       = 16'shF301; // F301 è -3327 in Hex

    // ============================================================
    // STADIO 1: Moltiplicazione
    // ============================================================
    wire signed [31:0] prod;
    assign prod = zeta * rjl;

    // Qui forziamo il cast signed sulla slice per sicurezza assoluta
    wire signed [15:0] k_factor;
    assign k_factor = $signed(prod[15:0]) * QINV;

    reg signed [31:0] prod_reg;
    reg signed [15:0] k_reg;
    reg               valid_d1;

    // Debug Variables (per visualizzazione waveform se serve)
    wire signed [15:0] prod_low = prod[15:0];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            prod_reg <= 32'd0;
            k_reg    <= 16'd0;
            valid_d1 <= 1'b0;
        end else begin
            prod_reg <= prod;
            k_reg    <= k_factor;
            valid_d1 <= in_valid;
        end
    end

    // ============================================================
    // STADIO 2: Riduzione
    // ============================================================
    wire signed [31:0] k_times_q;
    assign k_times_q = k_reg * KYBER_Q_32;

    wire signed [31:0] diff;
    assign diff = prod_reg - k_times_q;

    wire signed [15:0] result;
    assign result = diff[31:16]; // Shift >> 16

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            t         <= 16'd0;
            out_valid <= 1'b0;
        end else begin
            t         <= result;
            out_valid <= valid_d1;
        end
    end

endmodule

