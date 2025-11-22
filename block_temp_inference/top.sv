`timescale 1 ns/ 1ps

module top #(
    parameter layers = 3,
    parameter datawidth = 16,
    parameter int_part_input = 8,
    parameter int_part_weight = 8,
    parameter integer rows[0:layers-1] = '{50, 30, 10},
    parameter max_rows = 50,
    parameter integer cols[0:layers-1] = '{64, 50, 30},
    parameter max_cols = 64,
    parameter integer activation[0:layers-1] = '{0, 0, 0},
    parameter lut_width = 22,
    parameter max_inputs = 200
)(
    input wire clk,
    input wire rst_vals,
    input wire rst_overall,
    input wire pretrained,
    input wire enable_inference,
    output logic [rows[layers-1]-1:0] expected_output,
    output logic [rows[layers-1]-1:0] obtained_output,
    output logic [8:0] accuracy
);

wire [max_rows*2*datawidth-1:0] bias_updates_wire;
wire [max_cols*datawidth-1:0] weight_update;
wire [$clog2(max_rows)-1:0] row_sel;
wire [$clog2(layers)-1:0] layer_select;
wire [cols[0]*datawidth-1:0] input_values;
wire [rows[layers-1]-1:0] final_out;
wire [$clog2(rows[layers-1])-1:0] label;
wire final_done;
wire upload_done;
wire train;
wire input_loaded;
logic begin_next;
logic enable_acc;

logic enable_for_weights;
logic inference_triggered;

always @(posedge clk or posedge rst_overall) begin
    if (rst_overall) begin
        inference_triggered <= 0;
     //   enable_for_weights <= 0;
        end
    else if (enable_inference && upload_done)
        inference_triggered <= 1;
   // else if (inference_triggered == 1) begin
  ////  enable_for_weights <= 1;
    inference_triggered <= 0;
  //  end
end

assign enable_for_weights = 1;


    weight_layers #(
        .layers(layers), .datawidth(datawidth),
        .int_part_input(int_part_input), .int_part_weight(int_part_weight),
        .rows(rows), .max_rows(max_rows), .cols(cols), .max_cols(max_cols),
        .activation(activation), .lut_width(lut_width)
    ) inference_weights (
        .clk(clk),
        .rst_vals(rst_vals),
        .rst_overall(rst_overall),
        .en(enable_for_weights),
        .train (train),
        .train_layer_select(layer_select),
        .row_sel(row_sel),
        .input_values(input_values),
        .weight_update(weight_update),
        .bias_updates(bias_updates_wire),
        .final_out(final_out),
        .final_done(final_done),
        .input_loaded(input_loaded)
    );

top_input_loader #(.datawidth(datawidth),
                    .input_vector_length(cols[0]),
                    .output_rows(rows[layers-1]),
                    .max_inputs(max_inputs), 
                    .layers(layers), 
                    .rows(rows)) 
                    input_loader (
    .clk(clk),
    .rst_vals(rst_vals),
    .rst_overall(rst_overall),
    .upload_done(upload_done),
    .enable_inference(enable_inference),
    .final_done(begin_next),
    .input_values(input_values),
    .label(label),
    .input_loaded(input_loaded)
);

wire [rows[layers-1]-1:0] expected_value;

training_label #(.layers(layers), .rows(rows)) train_value (
  .rst_vals(rst_vals),
  .clk(clk),
  .input_loaded(input_loaded),
  .value(label),
  .label(expected_value)
);

    weight_updater #(
        .layers(layers), .datawidth(datawidth),
        .int_part_input(int_part_input), .int_part_weight(int_part_weight),
        .rows(rows), .max_rows(max_rows),
        .cols(cols), .max_cols(max_cols),
        .activation(activation)
    ) weights_and_biases (
        .clk(clk),
        .rst_overall(rst_overall),
        .rst_vals(rst_vals),
        .pretrained(pretrained),
        .layer_select(layer_select),
        .row_select(row_sel),
        .weight_update(weight_update),
        .bias_updates(bias_updates_wire),
        .upload_done(upload_done),
        .train (train)
    );

reg [$clog2(max_inputs)-1:0] correct_count;
reg [$clog2(max_inputs)-1:0] count;

always @(posedge clk or posedge rst_vals) begin
    if (rst_vals) begin
        correct_count <= 0;
        count <= 0;
    end
    else if (final_done) begin
        if (expected_value == final_out) begin
            correct_count <= correct_count + 1;
            end
            count <= count + 1;
            enable_acc <= 1;

    end
end
always_ff @(posedge clk) begin
    if (rst_vals || count == 0)
        accuracy <= 0;
    else if (count != 0 && enable_acc) begin
        accuracy <= (correct_count * 100) / count;
        enable_acc <= 0;
        begin_next <= 1;
        expected_output <= expected_value;
        obtained_output <= final_out;
    end
    else if (begin_next == 1)
    begin_next <= 0;
end

endmodule