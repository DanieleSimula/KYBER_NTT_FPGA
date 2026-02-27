`timescale 1ns / 1ps

module Rom #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 7
)(
    input wire clk,
    input wire  [(ADDR_WIDTH - 1):0]addr,
    output wire [(DATA_WIDTH-1):0] zeta
);

reg [DATA_WIDTH-1:0] rom [2**ADDR_WIDTH-1:0];
reg [(ADDR_WIDTH-1):0]addr_r;

initial begin
    $readmemh("zetas.mem", rom);
end

    always @(posedge clk)
        addr_r <= addr;    
    assign zeta = rom[addr_r];

endmodule