
`timescale 1ns/ 1ps

module layer #(parameter layer_no = 0, 
    parameter rows = 30,
    parameter columns = 64,
    parameter max_rows = 30,
    parameter max_columns = 64,
    parameter datawidth = 11)
    (
    input wire signed [columns*datawidth-1:0] values,
    input wire [$clog2(max_rows)-1:0] row_sel,
    input wire signed [max_columns*datawidth-1:0] weight_update,
    input wire signed [max_rows*2*datawidth-1:0] bias_updates,
    input wire clk,
    input wire rst_vals,
    input wire rst_overall,
    input wire en,
    input wire train_en,
    output reg signed [rows*(2*datawidth+$clog2(columns))-1:0] out,
    output reg done
);

reg signed [2*datawidth+$clog2(columns)-1:0] outputs [0:rows-1];
reg signed [2*datawidth-1:0] bias_values [0:rows-1];

genvar i,j;

generate
    for (i = 0; i < rows; i = i + 1)
        begin: gen_rows
        
        for (j = 0; j < columns; j = j + 1)
                begin: gen_columns

                    wire signed [datawidth-1:0] value;
                    wire signed [2*datawidth+$clog2(columns)-1:0] inp_west;
                    wire signed [datawidth-1:0] weight_up_val;
                    wire signed [2*datawidth+$clog2(columns)-1:0] outp_east;

                    assign value = values[(columns-j-1)*datawidth +: datawidth];
                    assign weight_up_val = weight_update[(columns-j-1)*datawidth +: datawidth];

                    if (j == 0) begin : first_column
                    assign inp_west = 0;
                    end 
                    else begin : subsequent_columns
                    assign inp_west = gen_rows[i].gen_columns[j-1].outp_east;
                    end
                    
                    

                    block #(.row_no(i), .column_no(j), .columns(columns), .datawidth(datawidth))
                        u_block(.value(value), 
                        .inp_west(inp_west), 
                        .clk(clk), 
                        .rst_vals(rst_vals), 
                        .rst_overall(rst_overall), 
                        .train_en(train_en && (row_sel == i)), 
                        .weight_update(weight_up_val), 
                        .outp_east(outp_east));
                    
                end    
            end
endgenerate

wire signed [2*datawidth+$clog2(columns)-1:0] outp_east_all [0:rows-1];

generate
    for (i = 0; i < rows; i = i + 1) begin : assign_outputs
        assign outp_east_all[i] = gen_rows[i].gen_columns[columns-1].outp_east;
    end
endgenerate

integer count;
integer t;

always @(posedge clk or posedge rst_overall or posedge rst_vals) begin
    if (rst_overall || rst_vals)
        count <= 0;
    else begin
            if (en && count < columns + 10)
                count <= count + 1;
    end
end

wire outputs_ready = (count == columns + 10);


    // State machine for output latching and bias addition
    typedef enum logic [1:0] {
        IDLE,
        LATCH,
        ACCUMULATE,
        DONE
    } layer_state_t;

    layer_state_t state, next_state;

    // Sequential logic for state register and edge detection
    always @(posedge clk or posedge rst_vals or posedge rst_overall) begin
        if (rst_vals || rst_overall) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

logic done_temp;
logic latch_done;
integer curr_row;
    // Combinational next-state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (outputs_ready)
                    next_state = LATCH;
            end
            LATCH: begin
            if (latch_done)
                next_state = ACCUMULATE;
            end
            ACCUMULATE: begin
            if (done_temp)
                next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    localparam signed [2*datawidth+$clog2(columns)-1:0] POS_SAT = {1'b0, {(2*datawidth+$clog2(columns)-1){1'b1}}};
    localparam signed [2*datawidth+$clog2(columns)-1:0] NEG_SAT = {1'b1, {(2*datawidth+$clog2(columns)-1){1'b0}}};
    logic [rows*(2*datawidth+$clog2(columns))-1:0] out_temp;
    // Main sequential operations
    integer k;
    logic signed [2*datawidth+$clog2(columns):0] temp;
    always @(posedge clk) begin
        case (state)
            IDLE: begin
                done <= 0;
                latch_done <= 0;
                done_temp <= 0;
                curr_row <= 0;
            end

            LATCH: begin
                            if ((&outp_east_all[curr_row][2*datawidth+$clog2(columns)-1 : 2*datawidth]) || 
                                    !(|outp_east_all[curr_row][2*datawidth+$clog2(columns)-1 : 2*datawidth])) begin
                                    // No overflow: take lower 2*datawidth bits
                                    outputs[curr_row] <= outp_east_all[curr_row][2*datawidth+$clog2(columns)-1:0];
                                end else begin
                                    // Overflow: clamp to max or min
                                    outputs[curr_row] <= {outp_east_all[curr_row][2*datawidth+$clog2(columns)-1], {(2*datawidth+$clog2(columns)-1){!outp_east_all[curr_row][2*datawidth+$clog2(columns)-1]}}};
                                end
               curr_row <= curr_row + 1;
                    if (curr_row == rows)
                    latch_done <= 1;
                end

            ACCUMULATE: begin
            for (k = 0; k < rows; k = k + 1) begin
            // Temporary addition result
            logic signed [2*datawidth+$clog2(columns):0] sum_ext;
            sum_ext = $signed(outputs[k]) + $signed(bias_values[k]);  // one extra bit for overflow

            // Overflow detection
            if (sum_ext > POS_SAT)
            out_temp[(rows-k-1)*(2*datawidth+$clog2(columns)) +: 2*datawidth+$clog2(columns)] <= POS_SAT;  // positive overflow
            else if (sum_ext < NEG_SAT)
            out_temp[(rows-k-1)*(2*datawidth+$clog2(columns)) +: 2*datawidth+$clog2(columns)] <= NEG_SAT;  // negative overflow
            else
            out_temp[(rows-k-1)*(2*datawidth+$clog2(columns)) +: 2*datawidth+$clog2(columns)] <= sum_ext[2*datawidth+$clog2(columns)-1:0];  // normal
        end
        done_temp <= 1;
        count <= 0;
    end
            
            DONE: begin
            done <= 1;
            latch_done <= 0;
            done_temp <= 0;
            out <= out_temp;
            count <= 0;
            end
        endcase
    end

    // Training updates: update bias when train_en rising edge
    integer m;
    reg train_en_prev;
    wire train_en_rising = train_en && !train_en_prev;
    always @(posedge clk) begin
        train_en_prev <= train_en;
        if (train_en_rising) begin
            for (m = 0; m < rows; m = m + 1) begin
                bias_values[m] <= bias_values[m] + 
                    bias_updates[(rows-m-1)*2*datawidth +: 2*datawidth];
            end
        end
    end

    // Reset logic for arrays
    integer n;
    always @(posedge clk or posedge rst_vals or posedge rst_overall) begin
        if (rst_vals) begin
            for (n = 0; n < rows; n = n + 1) begin
                out[n*(2*datawidth+$clog2(columns)) +: 2*datawidth+$clog2(columns)] <= 0;
                outputs[n] <= 0;
            end
        end

        else if (rst_overall) begin
            for (n = 0; n < rows; n = n + 1) begin
                out[n*(2*datawidth+$clog2(columns)) +: 2*datawidth+$clog2(columns)] <= 0;
                bias_values[n] <= 0;
                outputs[n] <= 0;
            end
        end
    end

endmodule