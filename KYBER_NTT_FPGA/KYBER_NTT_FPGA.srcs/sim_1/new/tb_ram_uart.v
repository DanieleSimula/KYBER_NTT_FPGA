`timescale 1ns / 1ps

module tb_ram_uart;
    reg clk, rst, clear;
    reg uart_RX, start_tx_pulse, uart_mode, start_rx;

    wire uart_TX_w;

    // Segnali di interconnessione tra uart_unit e ram_driver
    wire [7:0]  uart_rd_addr_w;
    wire [7:0]  uart_wr_addr_w;
    wire        uart_rd_req_w;
    wire        uart_wr_req_w;
    wire [15:0] uart_data_out_w;
    wire [15:0] drv_rj_out_w;
    wire        drv_rd_valid_w;
    wire        wr_done_w;
    wire        tx_done_w, rx_done_w;

    // Monitoraggio segnali interni di uart_unit (gerarchia)
    wire        write_char = M_UART_UNIT.write_char;
    wire [7:0]  ascii_char = M_UART_UNIT.ascii_char;

    // Array per test e verifica
    reg [15:0] test_values      [0:255];    // valori da inviare
    reg [7:0]  tx_chars_captured[0:2047];  // 256 valori x 8 char ASCII = 2048 bytes
    integer    tx_char_count;
    integer    i, errors;
    reg [15:0] abs_val;

    uart_unit M_UART_UNIT (
        .clk            (clk),
        .rst            (rst),
        .uart_RX        (uart_RX),
        .uart_TX        (uart_TX_w),
        .start_tx_pulse (start_tx_pulse),
        .uart_mode      (uart_mode),
        .start_rx       (start_rx),
        .drv_rd_valid   (drv_rd_valid_w),
        .drv_rj_out     (drv_rj_out_w),
        .uart_rd_addr   (uart_rd_addr_w),
        .uart_wr_addr   (uart_wr_addr_w),
        .uart_rd_req    (uart_rd_req_w),
        .uart_wr_req    (uart_wr_req_w),
        .uart_data_out  (uart_data_out_w),
        .uart_tx_done   (tx_done_w),
        .ram_loaded     (rx_done_w)
    );

    ram_driver M_RAM_DRIVER (
        .clk      (clk),
        .rst      (rst),
        .clear    (clear),
        .sel_pair (1'b0),       // non usato in modalita' UART
        .read_mode(uart_mode),
        .rd_req   (uart_rd_req_w),
        .j        ({1'b0, uart_rd_addr_w}),
        .len      (8'd0),       // non usato in modalita' UART
        .rj       (drv_rj_out_w),
        .rjl      (),           // non usato in modalita' UART
        .rd_valid (drv_rd_valid_w),
        .wr_req   (uart_wr_req_w),
        .j_wr     ({1'b0, uart_wr_addr_w}),
        .len_wr   (8'd0),       // non usato in modalita' UART
        .outrj    (uart_data_out_w),
        .outrjl   (16'd0),      // non usato in modalita' UART
        .wr_done  (wr_done_w)
    );

    // Parametri temporali
    defparam M_UART_UNIT.U_UART_TOP.baud_rate_gen_module.COUNT = 13;
    localparam PERIODO = 2170; //periodo di un bit in ns
    //con COUNT=13, otteniamo un baud rate di 460800 bps (cioè 1 bit ogni 2170ns) per accelerare la simulazione
    // baud_count = freq clock / (16 * baud_rate) (in bps) e periodo = 10^9 / baud_rate (in ns)

    always #5 clk = ~clk;

    // =====================================================================
    // Task: invia 1 byte in formato UART
    //   - 1 start bit (low)
    //   - 8 bit dati
    //   - 1 stop bit (high)
    // =====================================================================
    task send_uart_byte;
        input [7:0] data;
        integer k;
        begin
            uart_RX = 1'b0; #PERIODO;           // start bit
            for (k = 0; k < 8; k = k + 1) begin
                uart_RX = data[k]; #PERIODO;     // bit dati
            end
            uart_RX = 1'b1; #PERIODO;           // stop bit
        end
    endtask

    // =====================================================================
    // Task: invia 1 word 16-bit (MSB prima, poi LSB)
    // =====================================================================
    task send_uart_word;
        input [15:0] data;
        begin
            send_uart_byte(data[15:8]);  // MSB first
            send_uart_byte(data[7:0]);   // LSB
        end
    endtask

    // =====================================================================
    // Cattura caratteri ASCII scritti dalla data_converter nella TX FIFO
    // Viene eseguito durante la fase TX (write_char pulsa 8x per valore)
    // =====================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_char_count = 0;
        end else if (write_char) begin
            tx_chars_captured[tx_char_count] = ascii_char;
            tx_char_count = tx_char_count + 1;
        end
    end

    initial begin
        $display("=== INIZIO TESTBENCH tb_ram_uart ===");
        $display("PERIODO=%0d ns, 256 word da inviare", PERIODO);

        // ----- Inizializzazione -----
        clk           = 0;
        rst           = 1;
        clear         = 0;
        uart_RX       = 1'b1;   // UART idle = HIGH
        start_tx_pulse = 0;
        start_rx      = 0;
        uart_mode     = 1;
        errors        = 0;

        // Genera valori di test: sign-extension 8-bit -> 16-bit
        //   i =   0..127  ->  test_values =    0..127  (positivi)
        //   i = 128..255  ->  test_values = -128..-1   (negativi)
        for (i = 0; i < 256; i = i + 1) test_values[i] = {{8{i[7]}}, i[7:0]};

        #20;
        rst = 0;
        #50;

        // ================================================================
        // TEST 1: RX - Invia 256 word big-endian via UART, verifica RAM
        // ================================================================
        $display("\n--- TEST 1: Ricezione UART -> RAM ---");
        $display("[RX] Invio 256 word (512 byte) a %0d ns/bit...", PERIODO);

        start_rx = 1;

        for (i = 0; i < 256; i = i + 1) begin
            send_uart_word(test_values[i]);
        end

        // Attendi completamento ricezione
        wait(rx_done_w == 1'b1);
        #100;
        $display("[RX] ram_loaded ricevuto. Verifica contenuto RAM...");

        // Verifica: RAM[i] deve corrispondere a test_values[i]
        for (i = 0; i < 256; i = i + 1) begin
            if (M_RAM_DRIVER.RAM.ram[i] !== test_values[i]) begin
                $display("  RX ERRORE addr[%0d]: atteso=%04h  trovato=%04h",
                         i, test_values[i], M_RAM_DRIVER.RAM.ram[i]);
                errors = errors + 1;
            end
        end

        if (errors == 0)
            $display("[RX] PASS - tutti 256 valori corretti in RAM");
        else
            $display("[RX] FAIL - %0d errori su 256 posizioni RAM", errors);

        errors = 0;

        // ================================================================
        // TEST 2: TX - Avvia trasmissione, verifica caratteri ASCII catturati
        // ================================================================
        $display("\n--- TEST 2: TX RAM -> ASCII UART ---");

        @(posedge clk); start_tx_pulse = 1;
        @(posedge clk); start_tx_pulse = 0;

        // Attendi segnale di fine trasmissione
        wait(tx_done_w == 1'b1);

        $display("[TX] tx_done ricevuto. Char catturati: %0d (attesi: %0d)",
                 tx_char_count, 256 * 8);

        // Verifica conteggio totale caratteri (256 valori x 8 char)
        if (tx_char_count !== 2048) begin
            $display("[TX] ERRORE conteggio: catturati %0d, attesi 2048", tx_char_count);
            errors = errors + 1;
        end

        // Stampa campione: primi 4 e ultimi 4 valori per ispezione visiva
        $display("\n[TX] Campione output ASCII ( +/- DDDDD\\r\\n):");
        for (i = 0; i < 256; i = i + 1) begin
            if (i < 4 || i >= 252)
                $display("  val[%0d]=%0d -> '%c%c%c%c%c%c' + CR+LF",
                    i, $signed(test_values[i]),
                    tx_chars_captured[i*8+0], tx_chars_captured[i*8+1],
                    tx_chars_captured[i*8+2], tx_chars_captured[i*8+3],
                    tx_chars_captured[i*8+4], tx_chars_captured[i*8+5]);
        end

        // Verifica struttura ASCII per ogni valore:
        //   byte 0: segno ('+' = 0x2B  o  '-' = 0x2D)
        //   byte 1..5: 5 cifre decimali ASCII (0x30..0x39), da piu' a meno significativa
        //   byte 6: CR (0x0D)
        //   byte 7: LF (0x0A)
        $display("\n[TX] Verifica formato ASCII...");
        for (i = 0; i < 256; i = i + 1) begin

            // Calcola valore assoluto
            if ($signed(test_values[i]) < 0)
                abs_val = -$signed(test_values[i]);
            else
                abs_val = test_values[i];

            // --- Verifica segno ---
            if ($signed(test_values[i]) < 0) begin
                if (tx_chars_captured[i*8+0] !== 8'h2D) begin
                    $display("  TX ERRORE [%0d] segno: atteso '-', trovato %02h",
                             i, tx_chars_captured[i*8+0]);
                    errors = errors + 1;
                end
            end else begin
                if (tx_chars_captured[i*8+0] !== 8'h2B) begin
                    $display("  TX ERRORE [%0d] segno: atteso '+', trovato %02h",
                             i, tx_chars_captured[i*8+0]);
                    errors = errors + 1;
                end
            end

            // --- Verifica 5 cifre decimali ---
            if (tx_chars_captured[i*8+1] !== (8'h30 + abs_val / 10000)) begin
                $display("  TX ERRORE [%0d] cifra4: atteso %02h, trovato %02h",
                         i, 8'h30 + abs_val/10000, tx_chars_captured[i*8+1]);
                errors = errors + 1;
            end
            if (tx_chars_captured[i*8+2] !== (8'h30 + (abs_val / 1000) % 10)) begin
                $display("  TX ERRORE [%0d] cifra3: atteso %02h, trovato %02h",
                         i, 8'h30 + (abs_val/1000)%10, tx_chars_captured[i*8+2]);
                errors = errors + 1;
            end
            if (tx_chars_captured[i*8+3] !== (8'h30 + (abs_val / 100) % 10)) begin
                $display("  TX ERRORE [%0d] cifra2: atteso %02h, trovato %02h",
                         i, 8'h30 + (abs_val/100)%10, tx_chars_captured[i*8+3]);
                errors = errors + 1;
            end
            if (tx_chars_captured[i*8+4] !== (8'h30 + (abs_val / 10) % 10)) begin
                $display("  TX ERRORE [%0d] cifra1: atteso %02h, trovato %02h",
                         i, 8'h30 + (abs_val/10)%10, tx_chars_captured[i*8+4]);
                errors = errors + 1;
            end
            if (tx_chars_captured[i*8+5] !== (8'h30 + abs_val % 10)) begin
                $display("  TX ERRORE [%0d] cifra0: atteso %02h, trovato %02h",
                         i, 8'h30 + abs_val%10, tx_chars_captured[i*8+5]);
                errors = errors + 1;
            end

            // --- Verifica CR + LF ---
            if (tx_chars_captured[i*8+6] !== 8'h0D || tx_chars_captured[i*8+7] !== 8'h0A) begin
                $display("  TX ERRORE [%0d] CR/LF: trovato %02h %02h (attesi 0D 0A)",
                         i, tx_chars_captured[i*8+6], tx_chars_captured[i*8+7]);
                errors = errors + 1;
            end
        end

        if (errors == 0)
            $display("[TX] PASS - formato ASCII corretto per tutti 256 valori");
        else
            $display("[TX] FAIL - %0d errori totali", errors);

        $display("\n=== FINE TESTBENCH ===");
        $finish;
    end

    // =====================================================================
    // Timeout di sicurezza: 100ms
    // =====================================================================
    initial begin
        #100_000_000;
        $display("TIMEOUT - simulazione terminata forzatamente a 100ms");
        $finish;
    end
endmodule