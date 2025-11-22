`timescale 1ns / 1ps

module tb_top;

    // Parameters
    localparam layers = 2;
    localparam datawidth = 11;
    localparam int_part_input = 5;
    localparam int_part_weight = 5;
    localparam rows0 = 30, rows1 = 10;
    localparam cols0 = 64, cols1 = 30;
    localparam max_rows = 30;
    localparam max_cols = 64;
    localparam max_inputs = 300;
    localparam lut_width = 22;

    // Signals
    logic clk;
    logic rst_vals, rst_overall, pretrained, enable_inference;
    logic [rows1-1:0] expected_output, obtained_output;
    logic [8:0] accuracy;

    // For internal inspection
    logic [2*datawidth-1:0] single_bias;
    logic [datawidth-1:0] single_weight;
    int i;

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz

    // DUT instantiation
    top #(layers, datawidth, int_part_input, int_part_weight,
          '{rows0, rows1}, max_rows,
          '{cols0, cols1}, max_cols,
          '{0, 1}, lut_width, max_inputs)
    dut (
        .clk(clk),
        .rst_vals(rst_vals),
        .rst_overall(rst_overall),
        .pretrained(pretrained),
        .enable_inference(enable_inference),
        .expected_output(expected_output),
        .obtained_output(obtained_output),
        .accuracy(accuracy)
    );

    // Test Sequence
    initial begin
        $display("============================================================");
        $display("[TB] Starting Testbench...");

        // Reset sequence
        rst_overall = 1;
        rst_vals = 0;
        pretrained = 0;
        enable_inference = 0;

        #20;
        rst_overall = 0;
        $display("[TB] Deasserted rst_overall");

        #20;
        rst_vals = 1;
        #20;
        rst_vals = 0;
        $display("[TB] Pulsed rst_vals");

        // Pretrained mode
        #10;
        pretrained = 1;
        $display("[TB] Pretrained pulse sent");

        // Wait until upload is complete
        wait (dut.upload_done == 1);
        $display("[TB] Upload done signal received!");
        pretrained = 0;

        // Dump sample weights and biases
        $display("------------------------------------------------------------");
        $display("[TB] Checking example weights and biases:");

        // Print 5 weights from current row
        for (i = 0; i < 5; i++) begin
            single_weight = dut.weight_update[(cols0 - i - 1)*datawidth +: datawidth];
            $display("[TB] Weight[%0d] = %b", i, single_weight);
        end

        // Print 5 biases from current layer
        for (i = 0; i < 5; i++) begin
            single_bias = dut.bias_updates_wire[(rows1 - i - 1)*2*datawidth +: 2*datawidth];
            $display("[TB] Bias[%0d] = %b", i, single_bias);
        end

        $display("------------------------------------------------------------");

        // Begin inference
        #20;
        enable_inference = 1;
        $display("[TB] Inference enabled");

        // Monitor outputs
        forever begin
            @(posedge clk);
            if (dut.final_done) begin
                $display("[TB] Output Inferred:");
                $display("  Expected = %b", expected_output);
                $display("  Obtained = %b", obtained_output);
                $display("  Accuracy = %0d%%", accuracy);
                $display("------------------------------------------------------------");
            end
        end
    end

endmodule
