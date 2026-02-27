module debounce_onepulse #
(
    parameter integer CLK_FREQ = 10_000_000,  // 10 MHz
    parameter integer DEBOUNCE_MS = 1         // debounce time
)
(
    input  wire clk,
    input  wire rst,
    input  wire button_in,
    output reg  button_pulse
);

    // Calcolo cicli di debounce
    localparam integer DEBOUNCE_CYCLES =
        (CLK_FREQ / 1000) * DEBOUNCE_MS;

    localparam integer CNT_WIDTH =
        $clog2(DEBOUNCE_CYCLES + 1);

    // Sincronizzazione
    reg btn_sync_0, btn_sync_1;

    // Debounce
    reg [CNT_WIDTH-1:0] cnt;
    reg btn_stable;

    // Stato precedente (per fronte)
    reg btn_stable_d;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            btn_sync_0    <= 1'b0;
            btn_sync_1    <= 1'b0;
            btn_stable    <= 1'b0;
            btn_stable_d  <= 1'b0;
            cnt           <= 0;
            button_pulse  <= 1'b0;
        end else begin
            // Default: impulso spento
            button_pulse <= 1'b0;

            // Sincronizzazione
            btn_sync_0 <= button_in;
            btn_sync_1 <= btn_sync_0;

            // Debounce
            if (btn_sync_1 != btn_stable) begin
                cnt <= cnt + 1'b1;
                if (cnt >= DEBOUNCE_CYCLES - 1) begin
                    btn_stable <= btn_sync_1;
                    cnt <= 0;
                end
            end else begin
                cnt <= 0;
            end

            // Rilevamento fronte di salita
            btn_stable_d <= btn_stable;

            if (btn_stable == 1'b1 && btn_stable_d == 1'b0) begin
                button_pulse <= 1'b1;  // impulso di 1 ciclo
            end
        end
    end

endmodule
