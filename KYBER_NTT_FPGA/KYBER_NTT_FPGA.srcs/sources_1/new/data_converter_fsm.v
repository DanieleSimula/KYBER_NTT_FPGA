`timescale 1ns / 1ps
module data_converter_fsm (
    input  wire       clk,
    input  wire       rst,
    input  wire       enable,
    input  wire       shift_done,    // shift_count == 16
    input  wire       output_done,   // sel_digit >= 8
    output reg        load_input,    // campiona data_in, azzeramento BCD/shift
    output reg        shift_en,      // esegue uno step Double Dabble
    output reg        extract_en,    // estrae nibble BCD in d0-d4
    output reg        inc_digit,     // incrementa sel_digit
    output reg        set_ready,     // porta ready=1 e azzera sel_digit
    output reg  [1:0] state
);

    parameter IDLE    = 2'd0,
              DABBLE  = 2'd1,
              EXTRACT = 2'd2,
              OUTPUT  = 2'd3;

    reg [1:0] state_next;

 
    always @(posedge clk or posedge rst) begin
        if (rst) state <= IDLE;
        else     state <= state_next;
    end


    always @(state, enable, shift_done, output_done) begin
        case (state)
            IDLE:    state_next = enable      ? DABBLE  : IDLE;
            DABBLE:  state_next = shift_done  ? EXTRACT : DABBLE;
            EXTRACT: state_next = OUTPUT;
            OUTPUT:  state_next = output_done ? IDLE    : OUTPUT;
            default: state_next = IDLE;
        endcase
    end


    always @(state, enable, shift_done, output_done) begin
        case (state)
            IDLE: begin
                load_input = enable ? 1'b1 : 1'b0;
                shift_en   = 1'b0;
                extract_en = 1'b0;
                inc_digit  = 1'b0;
                set_ready  = 1'b0;
            end
            DABBLE: begin
                load_input = 1'b0;
                shift_en   = shift_done ? 1'b0 : 1'b1;
                extract_en = 1'b0;
                inc_digit  = 1'b0;
                set_ready  = 1'b0;
            end
            EXTRACT: begin
                load_input = 1'b0;
                shift_en   = 1'b0;
                extract_en = 1'b1;
                inc_digit  = 1'b0;
                set_ready  = 1'b0;
            end
            OUTPUT: begin
                load_input = 1'b0;
                shift_en   = 1'b0;
                extract_en = 1'b0;
                inc_digit  = output_done ? 1'b0 : 1'b1;
                set_ready  = output_done ? 1'b1 : 1'b0;
            end
            default: begin
                load_input = 1'b0;
                shift_en   = 1'b0;
                extract_en = 1'b0;
                inc_digit  = 1'b0;
                set_ready  = 1'b0;
            end
        endcase
    end

endmodule
