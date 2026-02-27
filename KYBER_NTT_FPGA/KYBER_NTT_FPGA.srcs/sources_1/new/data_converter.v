`timescale 1ns / 1ps
module data_converter (
    input  wire         clk,
    input  wire         rst,
    input  wire         enable,
    input  wire [15:0]  data_in,
    output reg  [7:0]   ascii_char,
    output reg          ready,
    output reg          write_char
);

    //Segnali di controllo dalla FSM
    wire [1:0] state;
    wire       load_input;   // campiona data_in
    wire       shift_en;     // esegue uno step Double Dabble
    wire       extract_en;   // estrae nibble BCD in d0-d4
    wire       inc_digit;    // incrementa sel_digit
    wire       set_ready;    // porta ready=1 e azzera sel_digit

    //Registri datapath
    reg [7:0]  sign;
    reg [3:0]  d4, d3, d2, d1, d0;
    reg [3:0]  sel_digit;
    reg [15:0] binary_val;
    reg [19:0] bcd_val;
    reg [4:0]  shift_count;

    //Registri next
    reg [7:0]  sign_next;
    reg [3:0]  d4_next, d3_next, d2_next, d1_next, d0_next;
    reg [3:0]  sel_digit_next;
    reg [15:0] binary_val_next;
    reg [19:0] bcd_val_next;
    reg [4:0]  shift_count_next;
    reg        ready_next;

    //Segnali di stato verso la FSM
    wire shift_done;
    wire output_done;

    assign shift_done = (shift_count == 5'd16);
    assign output_done = (sel_digit  >= 4'd8);

    //Double Dabble: correzione BCD (+3 se nibble >= 5)
    wire [19:0] bcd_temp;
    assign bcd_temp[3:0]   = (bcd_val[3:0]   >= 5) ? bcd_val[3:0]   + 3 : bcd_val[3:0];
    assign bcd_temp[7:4]   = (bcd_val[7:4]   >= 5) ? bcd_val[7:4]   + 3 : bcd_val[7:4];
    assign bcd_temp[11:8]  = (bcd_val[11:8]  >= 5) ? bcd_val[11:8]  + 3 : bcd_val[11:8];
    assign bcd_temp[15:12] = (bcd_val[15:12] >= 5) ? bcd_val[15:12] + 3 : bcd_val[15:12];
    assign bcd_temp[19:16] = (bcd_val[19:16] >= 5) ? bcd_val[19:16] + 3 : bcd_val[19:16];

    data_converter_fsm U_FSM (
        .clk        (clk),
        .rst        (rst),
        .enable     (enable),
        .shift_done (shift_done),
        .output_done(output_done),
        .load_input (load_input),
        .shift_en   (shift_en),
        .extract_en (extract_en),
        .inc_digit  (inc_digit),
        .set_ready  (set_ready),
        .state      (state)
    );


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign        <= 8'd43;
            binary_val  <= 16'd0;
            bcd_val     <= 20'd0;
            shift_count <= 5'd0;
            sel_digit   <= 4'd0;
            d0 <= 4'd0; d1 <= 4'd0;
            d2 <= 4'd0; d3 <= 4'd0; d4 <= 4'd0;
            ready       <= 1'b0;
        end else begin
            sign        <= sign_next;
            binary_val  <= binary_val_next;
            bcd_val     <= bcd_val_next;
            shift_count <= shift_count_next;
            sel_digit   <= sel_digit_next;
            d0 <= d0_next; d1 <= d1_next;
            d2 <= d2_next; d3 <= d3_next; d4 <= d4_next;
            ready       <= ready_next;
        end
    end


    
    always @(load_input, shift_en, extract_en, inc_digit, set_ready,
             data_in, sign, binary_val, bcd_val, bcd_temp,
             shift_count, sel_digit, d0, d1, d2, d3, d4, ready) begin
        if (load_input) begin
            sign_next        = data_in[15] ? 8'd45 : 8'd43;
            binary_val_next  = data_in[15] ? -$signed(data_in) : data_in;
            bcd_val_next     = 20'd0;
            shift_count_next = 5'd0;
            sel_digit_next   = 4'd0;
            d0_next          = d0;
            d1_next          = d1;
            d2_next          = d2;
            d3_next          = d3;
            d4_next          = d4;
            ready_next       = 1'b0;
        end else if (shift_en) begin
            sign_next        = sign;
            binary_val_next  = {binary_val[14:0], 1'b0};
            bcd_val_next     = {bcd_temp[18:0], binary_val[15]};
            shift_count_next = shift_count + 5'd1;
            sel_digit_next   = sel_digit;
            d0_next          = d0;
            d1_next          = d1;
            d2_next          = d2;
            d3_next          = d3;
            d4_next          = d4;
            ready_next       = ready;
        end else if (extract_en) begin
            sign_next        = sign;
            binary_val_next  = binary_val;
            bcd_val_next     = bcd_val;
            shift_count_next = shift_count;
            sel_digit_next   = sel_digit;
            d4_next          = bcd_val[3:0];
            d3_next          = bcd_val[7:4];
            d2_next          = bcd_val[11:8];
            d1_next          = bcd_val[15:12];
            d0_next          = bcd_val[19:16];
            ready_next       = ready;
        end else if (inc_digit) begin
            sign_next        = sign;
            binary_val_next  = binary_val;
            bcd_val_next     = bcd_val;
            shift_count_next = shift_count;
            sel_digit_next   = sel_digit + 4'd1;
            d0_next          = d0;
            d1_next          = d1;
            d2_next          = d2;
            d3_next          = d3;
            d4_next          = d4;
            ready_next       = ready;
        end else if (set_ready) begin
            sign_next        = sign;
            binary_val_next  = binary_val;
            bcd_val_next     = bcd_val;
            shift_count_next = shift_count;
            sel_digit_next   = 4'd0;
            d0_next          = d0;
            d1_next          = d1;
            d2_next          = d2;
            d3_next          = d3;
            d4_next          = d4;
            ready_next       = 1'b1;
        end else begin
            sign_next        = sign;
            binary_val_next  = binary_val;
            bcd_val_next     = bcd_val;
            shift_count_next = shift_count;
            sel_digit_next   = sel_digit;
            d0_next          = d0;
            d1_next          = d1;
            d2_next          = d2;
            d3_next          = d3;
            d4_next          = d4;
            ready_next       = ready;
        end
    end

    
    always @(state, sel_digit, sign, d0, d1, d2, d3, d4) begin
        case (state)
            2'd3: begin  // OUTPUT
                case (sel_digit)
                    4'd0: ascii_char = sign;
                    4'd1: ascii_char = {4'b0011, d0};
                    4'd2: ascii_char = {4'b0011, d1};
                    4'd3: ascii_char = {4'b0011, d2};
                    4'd4: ascii_char = {4'b0011, d3};
                    4'd5: ascii_char = {4'b0011, d4};
                    4'd6: ascii_char = 8'h0D;
                    4'd7: ascii_char = 8'h0A;
                    default: ascii_char = 8'b0;
                endcase
                write_char = (sel_digit < 4'd8) ? 1'b1 : 1'b0;
            end
            default: begin
                ascii_char = 8'b0;
                write_char = 1'b0;
            end
        endcase
    end
endmodule