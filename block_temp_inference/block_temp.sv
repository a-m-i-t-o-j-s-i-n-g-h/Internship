`timescale 1ns/ 1ps

module block #(parameter int row_no = 0,
	parameter int column_no = 0, 
	parameter columns = 64,
	parameter int datawidth = 11)
	(input logic signed [datawidth-1:0] value,
    input logic signed [2*datawidth + $clog2(columns)-1:0] inp_west,
    input logic clk,
    input logic rst_vals,
	input logic rst_overall,
	input logic train_en,
	input logic signed [datawidth-1:0] weight_update,
    output logic signed [2*datawidth + $clog2(columns) -1:0] outp_east);

	logic signed [2*datawidth-1:0] multi;

	logic signed [2*datawidth + $clog2(columns):0] acc_temp;
	logic signed [datawidth-1:0] weight;
	logic signed [datawidth:0] temp_weight;

	logic overflow_pos_acc, overflow_neg_acc;

	localparam signed [2*datawidth + $clog2(columns) -1:0] POS_SAT = {1'b0, {(2*datawidth+ $clog2(columns)-1){1'b1}}};
    localparam signed [2*datawidth+ $clog2(columns) -1:0] NEG_SAT = {1'b1, {(2*datawidth+ $clog2(columns)-1){1'b0}}};
	localparam signed [datawidth-1:0] POS_SAT_WT = {1'b0, {(datawidth-1){1'b1}}};
    localparam signed [datawidth-1:0] NEG_SAT_WT = {1'b1, {(datawidth-1){1'b0}}};

	always_comb begin
    multi = value * weight;
    acc_temp = $signed({{($clog2(columns)){multi[2*datawidth-1]}}, multi}) + $signed(inp_west);


    // Original sign-based overflow detection
//    overflow_pos_acc = (acc_temp > POS_SAT);
//    overflow_neg_acc = (acc_temp < NEG_SAT);

		if(rst_vals||rst_overall) begin
			multi = 0;
		end
    end

	always_ff @(posedge clk) begin
		if(rst_vals) begin
			outp_east <= 0;
		end
		else if(rst_overall) begin
			outp_east <= 0;
			weight <= 0;

		end
		else if (train_en) begin
temp_weight = $signed(weight) + $signed(weight_update);
if (temp_weight > POS_SAT_WT) weight <= {1'b0, {(datawidth-1){1'b1}}}; // max
else if (temp_weight < NEG_SAT_WT) weight <= {1'b1, {(datawidth-1){1'b0}}}; // min
else weight <= temp_weight[datawidth-1:0];
        end 
		else begin
		if (overflow_pos_acc) begin
            outp_east <= POS_SAT;
        end else if (overflow_neg_acc) begin
            outp_east <= NEG_SAT;
        end else begin
            outp_east <= acc_temp[2*datawidth+ $clog2(columns)-1:0];
		end
	end
	end

endmodule