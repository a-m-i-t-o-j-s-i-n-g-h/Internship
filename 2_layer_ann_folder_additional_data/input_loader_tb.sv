`timescale 1ns/1ps

module tb_input_loader;

    // Parameters matching your DUT
    localparam int datawidth = 11;
    localparam int input_vector_length = 64;
    localparam int output_rows = 10;
    localparam int max_inputs = 200;
    localparam int layers = 2;
    localparam int rows [0:layers-1] = '{30, 10};

    localparam int label_bits = $clog2(rows[layers-1]);
    localparam int vector_bits = datawidth * input_vector_length;

    // DUT I/O signals
    logic clk;
    logic rst_vals;
    logic rst_overall;
    logic upload_done;
    logic enable_inference;
    logic final_done;
    logic [vector_bits-1:0] input_values;
    logic [label_bits-1:0] label;
    logic input_loaded;

    // Instantiate DUT
    top_input_loader #(
        .datawidth(datawidth),
        .input_vector_length(input_vector_length),
        .output_rows(output_rows),
        .max_inputs(max_inputs),
        .layers(layers)
    ) uut (
        .clk(clk),
        .rst_vals(rst_vals),
        .rst_overall(rst_overall),
        .upload_done(upload_done),
        .enable_inference(enable_inference),
        .final_done(final_done),
        .input_values(input_values),
        .label(label),
        .input_loaded(input_loaded)
    );

    // Clock generator
    initial clk = 0;
    always #5 clk = ~clk;  // 10 ns clock period

    // Test sequence
    initial begin
        $display("===== Starting Testbench for top_input_loader =====");

        // Initialize signals
        rst_vals = 1;
        rst_overall = 0;
        upload_done = 0;
        enable_inference = 0;
        final_done = 0;

        @(posedge clk);
        rst_vals = 0;

        // Small delay
        repeat (2) @(posedge clk);

        // Drive signals to load input row
        enable_inference = 1;
        upload_done = 1;

        @(posedge clk);
        upload_done = 0;
        $display("Time %0t: Label = %0d", $time, label);
        $display("Time %0t: input_values[10:0] = %0d, input loaded = %b", $time, input_values[10:0], input_loaded);

        // Trigger another load (simulate final_done)
        repeat (2) @(posedge clk);
        final_done = 1;

        @(posedge clk);
        final_done = 0;
        $display("Time %0t: Label = %0d", $time, label);
        $display("Time %0t: input_values[10:0] = %0d, input loaded = %b", $time, input_values[10:0], input_loaded);

        // Run a few cycles to check wrapping of input_index
        repeat (10) begin
            upload_done = 1;
            @(posedge clk);
            upload_done = 0;
            $display("Label = %0d, first pixel = %0d, input loaded = %b", label, input_values[10:0], input_loaded);
             @(posedge clk);
             $display("Label = %0d, first pixel = %0d, input loaded = %b", label, input_values[10:0], input_loaded);
            
        end

        $display("===== End of Testbench =====");
        $finish;
    end

endmodule
