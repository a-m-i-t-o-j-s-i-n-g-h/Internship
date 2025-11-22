`timescale 1ns/1ps

module layer_tb;

    // Parameters matching layer module
    localparam layer_no      = 0;
    localparam rows          = 4;
    localparam columns       = 3;
    localparam max_rows      = 4;
    localparam max_columns   = 3;
    localparam datawidth     = 4;

    localparam VALUES_WIDTH      = columns * datawidth;
    localparam WEIGHT_WIDTH      = max_columns * datawidth;
    localparam BIAS_UPDATE_WIDTH = max_rows * 2 * datawidth;
    localparam OUT_WIDTH         = rows * 2 * datawidth;

    reg clk;
    reg rst_vals;
    reg rst_overall;
    reg signed [datawidth-1:0] test_values [0:columns-1];
    reg signed [datawidth-1:0] test_weights [0:columns-1];
    reg signed [2*datawidth-1:0] test_biases [0:rows-1];
    reg signed [2*datawidth-1:0] expected_outputs [0:rows-1];
    reg signed [2*datawidth-1:0] dot_product;
    reg signed [2*datawidth-1:0] mult_results [0:columns-1];
    reg en;
    reg train_en;
    reg [VALUES_WIDTH-1:0] values;
    reg [$clog2(max_rows)-1:0] row_sel;
    reg [WEIGHT_WIDTH-1:0] weight_update;
    reg [BIAS_UPDATE_WIDTH-1:0] bias_updates;
    wire [OUT_WIDTH-1:0] out;
    wire done;

    integer i;

    // Clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Instantiate DUT
    layer #(
        .layer_no(layer_no),
        .rows(rows),
        .columns(columns),
        .max_rows(max_rows),
        .max_columns(max_columns),
        .datawidth(datawidth)
    ) dut (
        .values(values),
        .row_sel(row_sel),
        .weight_update(weight_update),
        .bias_updates(bias_updates),
        .clk(clk),
        .rst_vals(rst_vals),
        .rst_overall(rst_overall),
        .en(en),
        .train_en(train_en),
        .out(out),
        .done(done)
    );

    initial begin
        $display("==== Starting Simulation ====");

        // Reset all signals
        rst_vals      = 0;
        rst_overall   = 1;
        en            = 0;
        train_en      = 0;
        values        = 0;
        row_sel       = 0;
        weight_update = 0;
        bias_updates  = 0;

        #20;
        rst_overall = 0;
        #10;

        //----------------------------------------
        // NEW TEST CONFIGURATION
        //----------------------------------------

        // New input values: [7, -3, 4]
        test_values[0] = 7;
        test_values[1] = -3;
        test_values[2] = 4;

        // New weights: [2, -1, 5]
        test_weights[0] = 2;
        test_weights[1] = -1;
        test_weights[2] = 5;

        // New biases for rows
        test_biases[0] = 100;
        test_biases[1] = -20;
        test_biases[2] = 35;
        test_biases[3] = -12;

        // Pack weight_update bus
        weight_update = {
            test_weights[0],
            test_weights[1],
            test_weights[2]
        };

        // Pack values bus

        bias_updates = {test_biases[0], test_biases[1], test_biases[2], test_biases[3]};


        $display("Values Bus = %h", values);
        $display("Weights Bus = %h", weight_update);
        $display("Bias Updates Bus = %h", bias_updates);
        //----------------------------------------
        // TRAINING: APPLY BIAS UPDATES


        for (i = 0; i < rows; i = i + 1) begin
            row_sel = i;
            train_en = 1;
            #10;
        end
        train_en = 0;
        values = {
            test_values[0],
            test_values[1],
            test_values[2]
        };
        //----------------------------------------
        // COMPUTE DOT PRODUCT
        //----------------------------------------
        mult_results[0] = test_values[0] * test_weights[0];
        mult_results[1] = test_values[1] * test_weights[1];
        mult_results[2] = test_values[2] * test_weights[2];

        dot_product = mult_results[0] + mult_results[1] + mult_results[2];

        $display("Computed partial products:");
        for (i = 0; i < columns; i = i + 1) begin
            $display("Mult[%0d] = %0d * %0d = %0d",
                i,
                (i==0) ? test_values[2] :
                (i==1) ? test_values[1] :
                         test_values[0],
                test_weights[i],
                mult_results[i]
            );
        end
        $display("Dot Product = %0d", dot_product);

        //----------------------------------------
        // EXPECTED OUTPUTS
        //----------------------------------------
        for (i = 0; i < rows; i = i + 1) begin
            expected_outputs[i] = dot_product + test_biases[i];
            $display("Expected output Row %0d = %0d (dot_product + bias %0d)",
                i, expected_outputs[i], test_biases[i]
            );
        end

        //----------------------------------------
        // ENABLE COMPUTATION
        //----------------------------------------
        #40;
        en = 1;
        wait(dut.done);
        $display("Done flag = %b", done);
        en = 0;

        //----------------------------------------
        // DISPLAY DUT RESULTS
        //----------------------------------------
        $display("\n==== Results ====");
        for (i = 0; i < rows; i = i + 1) begin
            $display("Row %0d => DUT out = %0d, Expected = %0d",
                i,
                $signed(out[(rows-i-1)*2*datawidth +: 2*datawidth]),
                expected_outputs[i]
            );

            if ($signed(out[(rows-i-1)*2*datawidth +: 2*datawidth]) === expected_outputs[i])
                $display("PASS: Row %0d matches expected.", i);
            else
                $display("FAIL: Row %0d does NOT match expected!", i);
        end

        $display("==== Simulation Complete ====");
        $finish;
    end

endmodule
