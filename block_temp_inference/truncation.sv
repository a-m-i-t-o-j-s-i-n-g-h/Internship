`timescale 1ns/1ps

module truncation #(
    parameter layers = 2,
    parameter integer row = 30,
    parameter datawidth = 11,
    parameter int_part_input = 5,
    parameter int_part_weight = 5,
    parameter max_rows = 30
)(
    input logic clk,
    input logic rst_vals,
    input logic rst_overall,
    input logic layer_done,
    input logic signed [row*2*datawidth-1:0] layer_out_pre,
    output logic signed [row*datawidth-1:0] layer_out_trunc,
    output logic trunc_done
);

    // Internal constants
    localparam full_width = 2 * datawidth;

    localparam int INP_FRAC_BITS = datawidth - int_part_input; 
    localparam int WT_FRAC_BITS = datawidth - int_part_weight;
    localparam int CURRENT_FULL_FRAC_BITS = INP_FRAC_BITS + WT_FRAC_BITS;
    localparam int TARGET_TRUNC_FRAC_BITS = INP_FRAC_BITS;
    
    localparam int BITS_TO_DROP = CURRENT_FULL_FRAC_BITS - TARGET_TRUNC_FRAC_BITS;

    localparam signed [full_width-1:0] MAX_VAL = (1 <<< (full_width - 1)) - 1;
    localparam signed [full_width-1:0] MIN_VAL = -(1 <<< (full_width - 1));

    // FSM states
    typedef enum logic [1:0] {
        IDLE = 2'd0,
        PROCESS = 2'd1,
        DONE = 2'd2
    } state_t;

    state_t state;
    integer row_cnt;

    always_ff @(posedge clk or posedge rst_vals or posedge rst_overall) begin
        if (rst_vals || rst_overall) begin
            layer_out_trunc <= '0;
            trunc_done <= 1'b0;
            row_cnt <= 0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (layer_done) begin
                        row_cnt <= 0;
                        trunc_done <= 0;
                        state <= PROCESS;
                    end
                end

                PROCESS: begin
                    if (row_cnt < row) begin
                        // Extract value
                        logic signed [full_width-1:0] full_val;
                        logic signed [full_width-1:0] saturated_val;
                        logic signed [full_width:0]   val_with_rounding_added;
                        logic sign_bit;
                        logic [int_part_input-2:0] int_bits;
                        logic [datawidth - int_part_input - 1:0] frac_bits;
                        logic signed [int_part_weight - 1:0] int_val;

                        full_val = layer_out_pre[(row - row_cnt - 1) * full_width +: full_width];
                        int_val = saturated_val[full_width - int_part_weight +: int_part_weight];
                        // Saturation
                        if (full_val > MAX_VAL)
                            saturated_val = MAX_VAL;
                        else if (full_val < MIN_VAL)
                            saturated_val = MIN_VAL;
                        else
                            saturated_val = full_val;

                         val_with_rounding_added = $signed(saturated_val) + (1'b1 << (BITS_TO_DROP - 1));
                      

                        // Extract components
                        sign_bit = val_with_rounding_added[full_width - 1];
                        int_bits = val_with_rounding_added[full_width - int_part_input - int_part_weight +: int_part_input - 1];
                        frac_bits = val_with_rounding_added[full_width - int_part_input - int_part_weight - 1 -: datawidth - int_part_input];

                        // Store truncated result
                        layer_out_trunc[(row - row_cnt - 1) * datawidth +: datawidth] <= 
                            {sign_bit, int_bits, frac_bits};
               //   layer_out_trunc[(row - row_cnt - 1) * datawidth +: datawidth] <= saturated_val[datawidth +: datawidth];

                        row_cnt <= row_cnt + 1;
                    end else begin
                        trunc_done <= 1;
                        state <= DONE;
                    end
                end

                DONE: begin
                    if (!layer_done) begin
                        state <= IDLE;
                        trunc_done <= 0;
                    end
                end
            endcase
        end
    end

endmodule
