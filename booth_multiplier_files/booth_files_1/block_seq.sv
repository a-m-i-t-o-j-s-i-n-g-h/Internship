`timescale 1ns/1ps

module block #(
    parameter int row_no    = 0,
    parameter int column_no = 0,
    parameter int columns   = 64,
    parameter int datawidth = 11
)(  input  logic signed [datawidth-1:0] value,
    input  logic signed [2*datawidth + $clog2(columns)-1:0] inp_west,
    input  logic clk,
    input  logic en,
    input  logic rst_vals,
    input  logic rst_overall,
    input  logic train_en,
    input  logic signed [datawidth-1:0] weight_update,
    output logic signed [2*datawidth + $clog2(columns)-1:0] outp_east,
    output logic done);

    localparam int OUTW = 2*datawidth + $clog2(columns);
    localparam logic signed [OUTW-1:0] POS_SAT = {1'b0, {(OUTW-1){1'b1}}};
    localparam logic signed [OUTW-1:0] NEG_SAT = {1'b1, {(OUTW-1){1'b0}}};

    localparam logic signed [datawidth-1:0] POS_SAT_WT = {1'b0, {(datawidth-1){1'b1}}};
    localparam logic signed [datawidth-1:0] NEG_SAT_WT = {1'b1, {(datawidth-1){1'b0}}};

    logic signed [2*datawidth-1:0]            multi;     
    logic signed [2*datawidth-1:0]            multi_temp;
    logic signed [OUTW  :0]                   acc_temp;   // OUTW+1 wide for overflow detect
    logic signed [datawidth-1:0]              weight;
    logic signed [datawidth    :0]            temp_weight; // one bit wider for add
  //  logic [$clog2(datawidth)-1:0]             count;

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] { S_IDLE, S_MULT, S_DONE } state_t;
    state_t state, next_state;

    // State register with async resets (match your original intent)
    always_ff @(posedge clk or posedge rst_overall or posedge rst_vals) begin
        if (rst_overall || rst_vals)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    // Next-state logic
    always_comb begin
        next_state = state;
        unique case (state)
            S_IDLE: if (en)     next_state = S_MULT;
            S_MULT:             next_state = S_DONE;
            S_DONE:             next_state = S_IDLE;
            default:            next_state = S_IDLE;
        endcase
    end

    // -------------------------------------------------------------------------
    // Datapath
    // -------------------------------------------------------------------------
    // Sequential datapath with separate rst handling
    always_ff @(posedge clk or posedge rst_overall) begin
        if (rst_overall) begin
            multi     <= '0;
            done      <= 1'b0;
       //     count <= 0;
        end else if (rst_vals) begin
            // Reset only datapath/outputs (keep weight intact)
            multi     <= '0;
            done      <= 1'b0;
      //      count <= 0;
        end else begin
             // default

            unique case (state)
                S_IDLE: begin
                    done <= 1'b0;
    //                count <= 0;
                    // wait for en
                end

                S_MULT: begin
                    // Single-cycle DSP multiply
                    multi_temp = value * weight;
      //              count <= count + 1;
      //              if (count == $clog2(datawidth)) 
      multi <= multi_temp;
                end

                S_DONE: begin
                    done <= 1'b1; // result valid this cycle
                end
            endcase
        end
    end

always_ff @(posedge clk or posedge rst_overall) begin
    if (rst_overall || rst_vals) begin
        acc_temp  <= '0;
        outp_east <= '0;
    end else begin
        // accumulate
        acc_temp <= $signed({{($clog2(columns)){multi[2*datawidth-1]}}, multi}) 
                  + $signed(inp_west);

        // saturate
        if (acc_temp > $signed(POS_SAT))
            outp_east <= POS_SAT;
        else if (acc_temp < $signed(NEG_SAT))
            outp_east <= NEG_SAT;
        else
            outp_east <= acc_temp[OUTW-1:0];
    end
end

    // -------------------------------------------------------------------------
    // Weight update path (separate; keeps your train_en gating)
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or posedge rst_overall) begin
        if (rst_overall) begin
            weight      <= '0;
            temp_weight <= '0;
        end else if (train_en) begin
            temp_weight = $signed(weight) + $signed(weight_update);
            if (temp_weight > POS_SAT_WT)
                weight <= POS_SAT_WT;
            else if (temp_weight < NEG_SAT_WT)
                weight <= NEG_SAT_WT;
            else
                weight <= temp_weight[datawidth-1:0];
        end
    end

endmodule
