`timescale 1ns/1ps
module layer #(
    parameter int layer_no   = 0,
    parameter int rows       = 30,
    parameter int columns    = 64,
    parameter int max_rows   = 30,
    parameter int max_columns= 64,
    parameter int datawidth  = 11
)(
    input  wire signed [columns*datawidth-1:0]       values,
    input  wire [$clog2(max_rows)-1:0]               row_sel,
    input  wire signed [max_columns*datawidth-1:0]   weight_update,
    input  wire signed [max_rows*2*datawidth-1:0]    bias_updates,
    input  wire                                      clk,
    input  wire                                      rst_vals,
    input  wire                                      rst_overall,
    input  wire                                      en,
    input  wire                                      train_en,
    output reg signed [rows*(2*datawidth)-1:0]       out,
    output reg                                      done
);
    // Internal arrays for partial products and sums
    wire signed [2*datawidth-1:0] all_block_outp_easts [0:rows-1][0:columns-1];
    logic signed [2*datawidth-1:0] bias_values [0:rows-1];
    // Extended sum width: add log2(columns) extra bits to avoid overflow
    localparam int EXTRA      = $clog2(columns);
    localparam int SUM_WIDTH  = 2*datawidth + EXTRA;
    logic signed [SUM_WIDTH-1:0] sum_row [0:rows-1];

    // Generate block instances per row and column
    genvar i,j;
    generate
      for (i = 0; i < rows; i = i + 1) begin: gen_rows
        for (j = 0; j < columns; j = j + 1) begin: gen_cols
            // Extract input value and weight update for this block
            wire signed [datawidth-1:0] value       = values[(columns-1-j)*datawidth +: datawidth];
            wire signed [datawidth-1:0] weight_up   = weight_update[(columns-1-j)*datawidth +: datawidth];
            block #(
              .row_no    (i),
              .column_no (j),
              .columns   (max_columns),
              .datawidth (datawidth)
            ) u_block (
              .value        (value),
              .clk          (clk),
              .rst_vals     (rst_vals),
              .rst_overall  (rst_overall),
              .train_en     (train_en && (row_sel == i)),
              .weight_update(weight_up),
              .outp_east    (all_block_outp_easts[i][j])
            );
        end
      end
    endgenerate

    // State machine for accumulate -> round/saturate -> add bias
    typedef enum logic [1:0] {IDLE, ACCUM, DONE} state_t;
    state_t state, next_state;
    integer r, c;

    // State register
    always_ff @(posedge clk or posedge rst_vals or posedge rst_overall) begin
        if (rst_vals || rst_overall) begin
            state <= IDLE;
            done  <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next-state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE:    if (en)           next_state = ACCUM;
            ACCUM:   next_state = DONE;
            DONE:    next_state = IDLE;
        endcase
    end

    // Accumulate and then round+saturate
    always_ff @(posedge clk) begin
        if (state == ACCUM) begin
            // For each row, sum all block outputs (with sign)
            for (r = 0; r < rows; r = r + 1) begin
                sum_row[r] = 0;
                for (c = 0; c < columns; c = c + 1) begin
                    sum_row[r] = sum_row[r] + all_block_outp_easts[r][c];
                end
                // Rounding: add half LSB of the extra bits
                if (EXTRA > 0) begin
                    if (sum_row[r] >= 0)
                        sum_row[r] = sum_row[r] + (1 <<< (EXTRA-1));
                    else
                        sum_row[r] = sum_row[r] - (1 <<< (EXTRA-1));
                end
                // Saturate & truncate to 2*datawidth bits
                // If any of the top EXTRA bits differ from sign bit => overflow
                if ((&sum_row[r][SUM_WIDTH-1 : 2*datawidth]) || !(|sum_row[r][SUM_WIDTH-1 : 2*datawidth])) begin
                    // No overflow: just take lower 2*datawidth bits
                    // (All upper bits are sign bits or zero)
                    sum_row[r] = sum_row[r][2*datawidth-1:0];
                end else begin
                    // Overflow: clamp to max or min 2*datawidth value
                    sum_row[r] = {sum_row[r][SUM_WIDTH-1], {(2*datawidth-1){!sum_row[r][SUM_WIDTH-1]}}};
                end
                // Store the (saturated) 2*datawidth sum temporarily
                // Using 'sum_row' itself as it now holds 2*datawidth-sign-extended result
                sum_row[r] = sum_row[r][2*datawidth-1:0];
            end
        end
    end

                localparam signed [2*datawidth-1:0] POS_SAT = {1'b0, {(2*datawidth-1){1'b1}}};
                localparam signed [2*datawidth-1:0] NEG_SAT = {1'b1, {(2*datawidth-1){1'b0}}};
                logic signed [2*datawidth:0] temp;
    // Add bias and finalize outputs when done
    always_ff @(posedge clk) begin
        if (state == DONE) begin
            // Each bias is 2*datawidth bits (already matched format)
            for (r = 0; r < rows; r = r + 1) begin
                // Combine accumulated sum and bias, then saturate again
                temp = $signed(sum_row[r]) + $signed(bias_values[r]);
                if (temp > POS_SAT)
                    out[(rows-1-r)*(2*datawidth) +: 2*datawidth] <= POS_SAT;
                else if (temp < NEG_SAT)
                    out[(rows-1-r)*(2*datawidth) +: 2*datawidth] <= NEG_SAT;
                else
                    out[(rows-1-r)*(2*datawidth) +: 2*datawidth] <= temp[2*datawidth-1:0];
            end
            done <= 1;
        end else if (state == IDLE) begin
            // Clear outputs on reset or idle
            done <= 0;
        end
    end

    // Training: update bias values on a rising edge of train_en
    reg train_en_prev;
    wire train_en_rising = train_en && !train_en_prev;
    integer m;
    always_ff @(posedge clk) begin
        train_en_prev <= train_en;
        if (rst_overall) begin
            for (m = 0; m < rows; m = m + 1) begin
                bias_values[m] <= 0;
            end
        end else if (train_en_rising) begin
            // Add bias updates (2*datawidth bits per row)
            for (m = 0; m < rows; m = m + 1) begin
                bias_values[m] <= bias_values[m] + bias_updates[(rows-1-m)*2*datawidth +: 2*datawidth];
            end
        end
    end

endmodule
