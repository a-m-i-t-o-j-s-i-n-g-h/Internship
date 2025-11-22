`timescale 1ns/ 1ps

module top_input_loader #(parameter datawidth = 11,
                               parameter input_vector_length = 64,
                               parameter output_rows = 10,
                               parameter max_inputs = 200,
                               parameter layers = 2,
                               parameter integer rows[0:layers-1] = '{30, 10})
(
    input  logic clk,
    input  logic rst_vals,
    input  logic rst_overall,
    input  logic upload_done,
    input  logic enable_inference,
    input  logic final_done,
    output logic signed [datawidth*input_vector_length-1:0] input_values,
    output logic [$clog2(rows[layers-1])-1:0] label,
    output logic input_loaded
);

    localparam label_bits  = $clog2(rows[layers-1]);
    localparam vector_bits = input_vector_length * datawidth;
    (* rom_style = "block" *) logic signed [(vector_bits + label_bits)-1:0] input_memory [0:max_inputs-1];

    // Counter to keep track of which row to load
    logic [$clog2(max_inputs)-1:0] input_index;

    // Load memory from file at simulation start
    initial begin
        $readmemb("test_88.mem", input_memory);
    end

    // Load new input row on upload_done or final_done
    always_ff @(posedge clk or posedge rst_overall or posedge rst_vals) begin
        if (rst_overall || rst_vals) begin
            input_index <= 0;
            input_values <= '0;
            label <= 0; end
            else if ((enable_inference && upload_done) || final_done) begin
                input_values <= input_memory[input_index] [label_bits +: vector_bits];
                label <= input_memory[input_index] [0 +: label_bits];
                input_loaded <= 1;
                if (input_index < max_inputs)
                input_index <= input_index + 1;
                end
            else input_loaded <= 0;
            end
    

endmodule
