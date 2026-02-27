`timescale 1ns / 1ps
module tb_sistema_completo;

    reg clk, rst, start_tx, start_butterfly, uart_RX;

    wire done, uart_mode, uart_TX;
    wire fifo_tx_full, fifo_tx_empty, fifo_rx_full, fifo_rx_empty;

    // Array per test e verifica
    reg [15:0] test_values      [0:255];    // valori da inviare
    reg [7:0]  tx_chars_captured[0:2047];  // 256 valori x 8 char ASCII = 2048 bytes
    integer    tx_char_count;
    integer    i, errors;
    reg [15:0] abs_val;

    wire end_rx = M_TOP.ram_loaded;
    wire end_tx = M_TOP.uart_tx_done;

    // Latch testbench: end_rx dura solo ~2 cicli (ntt_fsm abbassa start_rx subito).
    // Il testbench arriva al wait() DOPO che il pulse e' gia' calato -> race condition.
    // Questo latch cattura il pulse indipendentemente dalla latenza del testbench.
    reg rx_complete;
    always @(posedge clk) begin
        if (rst)    rx_complete <= 1'b0;
        else if (end_rx) rx_complete <= 1'b1;
    end
    wire        write_char = M_TOP.U_DATAPATH.U_UART_UNIT.write_char;
    wire [7:0]  ascii_char = M_TOP.U_DATAPATH.U_UART_UNIT.ascii_char;
    
    // Parametri temporali
    defparam M_TOP.U_DATAPATH.U_UART_UNIT.U_UART_TOP.baud_rate_gen_module.COUNT = 13;
    localparam PERIODO = 2170; //periodo di un bit in ns
    //con COUNT=13, otteniamo un baud rate di 460800 bps (cioè 1 bit ogni 2170ns) per accelerare la simulazione
    // baud_count = freq clock / (16 * baud_rate) (in bps) e periodo = 10^9 / baud_rate (in ns)

    // Override debouncer per simulazione: CLK_FREQ=1000 -> DEBOUNCE_CYCLES=1
    // (reale: CLK_FREQ=100_000_000 -> DEBOUNCE_CYCLES=100_000)
    defparam M_TOP.U_DEB_BTN_BUTTERFLY.CLK_FREQ   = 1000;
    defparam M_TOP.U_DEB_BTN_UART_WRITER.CLK_FREQ = 1000;

    ntt_top M_TOP (
        .clk(clk),
        .rst(rst),
        .start_tx(start_tx),
        .start_butterfly(start_butterfly),
        .uart_RX(uart_RX),
        .done(done),
        .uart_mode(uart_mode),
        .uart_TX(uart_TX),
        .fifo_tx_full(fifo_tx_full),
        .fifo_tx_empty(fifo_tx_empty),
        .fifo_rx_full(fifo_rx_full),
        .fifo_rx_empty(fifo_rx_empty)
    );

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
    always @(posedge clk) begin
        if (rst) begin
            tx_char_count = 0;
        end else if (write_char) begin
            tx_chars_captured[tx_char_count] = ascii_char;
            tx_char_count = tx_char_count + 1;
        end
    end

    initial begin
        clk           = 0;
        rst           = 1;
        uart_RX         = 1'b1; // UART idle = HIGH
        start_tx        = 0;
        start_butterfly = 0;
        
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
        for (i = 0; i < 256; i = i + 1) send_uart_word(test_values[i]);

        // Attendi completamento ricezione
        $display("[%0t ns] Attendo rx_complete...", $time);
        wait(rx_complete == 1'b1);
        $display("[%0t ns] rx_complete! (end_rx catturato dal latch)", $time);
        #100;
        $display("[RX] end_rx ricevuto. Verifica contenuto RAM...");

        // Verifica: RAM[i] deve corrispondere a test_values[i]
        for (i = 0; i < 256; i = i + 1) begin
            if (M_TOP.U_DATAPATH.U_RAM_DRIVER.RAM.ram[i] !== test_values[i]) begin
                $display("  RX ERRORE addr[%0d]: atteso=%04h  trovato=%04h",
                         i, test_values[i], M_TOP.U_DATAPATH.U_RAM_DRIVER.RAM.ram[i]);
                errors = errors + 1;
            end
        end

        if (errors == 0) $display("[RX] PASS - tutti 256 valori corretti in RAM");
        else $display("[RX] FAIL - %0d errori su 256 posizioni RAM", errors);
        errors = 0;

        // ================================================================
        // TEST 2: CALCOLO - Avvio butterfly, calcolo dei nuovi valori
        // ================================================================
        $display("[%0t ns] Avvio butterfly...", $time);
        @(negedge clk) start_butterfly = 1;
        @(negedge clk) start_butterfly = 0;
        $display("[%0t ns] Pulse start_butterfly inviato. FSM=%d", $time, M_TOP.U_FSM.state);

        $display("[%0t ns] Attendo done...", $time);
        wait(done == 1'b1);
        $display("[%0t ns] done ricevuto! FSM=%d", $time, M_TOP.U_FSM.state);

        $display("Aggiorno il vettore dei valori di test con i nuovi numeri dopo la butterfly");
        for (i = 0; i < 256; i = i + 1) test_values[i] = M_TOP.U_DATAPATH.U_RAM_DRIVER.RAM.ram[i];

        $display("Butterfly completata. Verifica caratteri UART trasmessi...");

        // ================================================================
        // TEST 3: TX - Avvia trasmissione, verifica caratteri ASCII catturati
        // ================================================================
        $display("[%0t ns] Invio pulse start_tx...", $time);
        @(negedge clk); start_tx = 1;
        @(negedge clk); start_tx = 0;
        $display("[%0t ns] Pulse start_tx inviato. FSM=%d uart_mode=%b", $time, M_TOP.U_FSM.state, uart_mode);

        // Attendi segnale di fine trasmissione
        $display("[%0t ns] Attendo end_tx...", $time);
        wait(end_tx == 1'b1);
        $display("[%0t ns] end_tx ricevuto! FSM=%d", $time, M_TOP.U_FSM.state);
        // Attendi svuotamento TX FIFO dell'ultimo valore (8 char x 800ns)
        #(PERIODO * 100);

        $display("[TX] end_tx ricevuto. Char catturati: %0d (attesi: %0d)",
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

    // Monitor periodico: stampa stato FSM ogni 5ms per identificare blocchi
    initial begin : state_monitor
        #1_000_000; // aspetta 1ms prima di iniziare
        forever begin
            #5_000_000; // ogni 5ms
            $display("[%0t ns] FSM=%d | done=%b | uart_mode=%b | end_rx=%b | end_tx=%b | fifo_rx_empty=%b | fifo_tx_empty=%b",
                $time,
                M_TOP.U_FSM.state,
                done, uart_mode, end_rx, end_tx,
                fifo_rx_empty, fifo_tx_empty);
        end
    end

    initial begin
        #100_000_000;
        $display("TIMEOUT - simulazione terminata forzatamente a 100ms");
        $finish;
    end
endmodule