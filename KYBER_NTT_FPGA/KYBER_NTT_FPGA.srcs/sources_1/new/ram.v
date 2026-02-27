`timescale 1ns / 1ps
//=============================================================================
// MODULO: ram_dual
// DESCRIZIONE: RAM true dual-port sincrona. Entrambe le porte supportano
//              lettura e scrittura simultanea e indipendente.
//              Utilizzata per memorizzare i coefficienti del polinomio
//              durante le operazioni NTT e per il trasferimento UART.
//=============================================================================
module ram_dual #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 8
)(
    input  wire                  clk,

   //porta A
    input  wire                  we_a,   // Write Enable A
    input  wire [ADDR_WIDTH-1:0] addr_a, // Indirizzo A
    input  wire [DATA_WIDTH-1:0] din_a,  // Dato in ingresso A (da Butterfly/uart outrj)
    output reg  [DATA_WIDTH-1:0] dout_a, // Dato in uscita A (verso Butterfly/uart rj)

   //porta B
    input  wire                  we_b,   // Write Enable B
    input  wire [ADDR_WIDTH-1:0] addr_b, // Indirizzo B
    input  wire [DATA_WIDTH-1:0] din_b,  // Dato in ingresso B (da Butterfly outrjl)
    output reg  [DATA_WIDTH-1:0] dout_b  // Dato in uscita B (verso Butterfly rjl)
);

    
    reg [DATA_WIDTH-1:0] ram [0: (1<<ADDR_WIDTH)-1];

    
    
    //initial begin    $readmemh("poly.mem", ram);end //inizializzazione (per debug)


    always @(posedge clk) begin
        if (we_a) begin
            ram[addr_a] <= din_a;
        end
        dout_a <= ram[addr_a]; 
    end


    always @(posedge clk) begin
        if (we_b) begin
            ram[addr_b] <= din_b;
        end
        dout_b <= ram[addr_b];
    end

endmodule