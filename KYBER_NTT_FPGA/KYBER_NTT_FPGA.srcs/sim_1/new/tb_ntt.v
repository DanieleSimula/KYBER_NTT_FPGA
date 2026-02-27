`timescale 1ns / 1ps
module tb_ntt;


    // 1. SEGNALI
    reg  clk;
    reg  rst;
    wire done;
    
    integer i; // Variabile per il ciclo for

    // 2. DUT
    ntt_top dut (
        .clk(clk),
        .rst(rst),
        .done(done)
    );

    // 3. CLOCK (100 MHz)
    always #5 clk = ~clk;

    // 4.
    initial begin
        // Inizializzazione
        clk = 0;
        rst = 1;
        
        $display("[TB] Reset Attivo...");
        
        // Tiene il reset per 100ns
        #100;
        rst = 0;
        $display("[TB] Reset Rilasciato. Attesa segnale DONE...");

        // --- ATTESA SEMPLICE ---
        // Il simulatore si ferma qui finché done non diventa 1
        wait(done == 1'b1);
        
        // Aspetta un attimo per sicurezza grafica
        #100;
        $display("\n[TB] DONE ricevuto! Inizio lettura memoria RAM interna...\n");
        $display("-------------------------------------------------------");
        $display("   OUTPUT RAM (Signed)");
        $display("-------------------------------------------------------");

        // --- CICLO DI STAMPA ---
        for (i = 0; i < 256; i = i + 1) begin
            // Accesso diretto alla memoria interna
            // $signed() converte i 16 bit grezzi in numero +/-
            $write("%6d ", $signed(dut.U_RAM_DRIVER.RAM.ram[i]));
            // va a capo ogni 8 numeri
            if ((i + 1) % 8 == 0) begin
                $write("\n");
            end
        end

        $display("\n-------------------------------------------------------");
        $display("[TB] Fine Simulazione.");
        $stop; // Ferma la simulazione
    end

endmodule