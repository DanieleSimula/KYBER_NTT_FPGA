
//CONTATORE K
module cnt_k (
    input  wire       clk,
    input  wire       rst,
    input  wire       load,   // cnt_k_load
    input  wire       inc,    // cnt_k_inc
    output reg  [7:0] k
);
    reg [7:0] k_next;

    // combinatorio
    always @(k,load,inc) begin
        k_next = k;

        if (load)
            k_next = 8'd1;
        else if (inc)
            k_next = k + 8'd1;
    end

    // sequenziale
    always @(posedge clk or posedge rst) begin
        if (rst)
            k <= 8'd1;
        else
            k <= k_next;
    end
endmodule

//_________________________________________________________________________________
//CONTATORE J
module cnt_j (
    input  wire        clk,
    input  wire        rst,
    input  wire        load,    // cnt_j_load
    input  wire        inc,     // cnt_j_inc
    input  wire [8:0]  start,   // da cnt_start
    input  wire [7:0]  len,     // da cnt_len
    output reg  [8:0]  j,
    output wire        hit_j
);
    reg  [8:0] j_next;
    wire [9:0] j_last = {1'b0, start} + {2'b00, len} - 10'd1;

    // combinatorio
    always @(j,start,load,inc) begin
        j_next = j;

        if (load)
            j_next = start;
        else if (inc)
            j_next = j + 9'd2;
    end

    // sequenziale
    always @(posedge clk or posedge rst) begin
        if (rst)
            j <= 9'd0;
        else
            j <= j_next;
    end
    // MODIFICA CRITICA: Stop anticipato
    // Poiché processiamo (j) e (j+1), l'ultimo indice valido di partenza 
    // è (start + len - 2).
    // Esempio: Start=0, Len=4 -> Indici 0,1,2,3.
    // Iterazione 1: j=0 (processa 0,1). Next j=2.
    // Iterazione 2: j=2 (processa 2,3). Hit deve essere 1 qui.
    // 2 >= 0 + 4 - 2 -> 2 >= 2 -> VERO.
    assign hit_j = (j >= start + len - 2);
endmodule

//__________________________________________________________________________________
//CONTRATORE START
module cnt_start (
    input  wire        clk,
    input  wire        rst,
    input  wire        load,     // cnt_start_load
    input  wire        upd,      // cnt_start_upd
    input  wire [7:0]  len,      // da cnt_len
    output reg  [8:0]  start,
    output wire        hit_start
);
    reg  [8:0] start_next;
    wire [9:0] start_plus_2len = {1'b0, start} + ({1'b0, len} << 1);

    // combinatorio
    always @(start,load,upd,start_plus_2len) begin
        start_next = start;

        if (load) begin
            start_next = 9'd0;
        end else if (upd) begin
            if (start_plus_2len >= 10'd256)
                start_next = 9'd256;
            else
                start_next = start_plus_2len[8:0];
        end
    end

    // sequenziale
    always @(posedge clk or posedge rst) begin
        if (rst)
            start <= 9'd0;
        else
            start <= start_next;
    end

    // Controlla se il PROSSIMO start sborderebbe.
// start_plus_2len è già calcolato nel modulo, usalo!
    assign hit_start = (start_plus_2len >= 10'd256);
endmodule

//--------------------------------------------------------------------------------------------------------------------------------------------
//CONTATORE LEN
module cnt_len (
    input  wire       clk,
    input  wire       rst,
    input  wire       load,    // cnt_len_load
    input  wire       shift,   // cnt_len_shift
    output reg  [7:0] len,
    output wire       hit_len
);
    reg [7:0] len_next;

    // combinatorio
    always @(len,load,shift) begin
        len_next = len;
        if (load)
            len_next = 8'd128;
        else if (shift)
            len_next = (len >> 1);
    end

    // sequenziale
    always @(posedge clk or posedge rst) begin
        if (rst)
            len <= 8'd1;
        else
            len <= len_next;
    end
    assign hit_len = (len == 8'd2); // Si ferma appena finito il livello 2
endmodule





