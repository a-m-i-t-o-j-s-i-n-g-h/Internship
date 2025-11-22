`timescale 1ns/1ps

module tb_block;

    parameter datawidth = 11;
    localparam totalwidth = 2*datawidth;

    reg signed [datawidth-1:0] value;
    reg signed [totalwidth-1:0] inp_west;
    reg clk;
    reg rst_vals;
    reg rst_overall;
    reg train_en;
    reg [datawidth-1:0] weight_update;
    wire signed [totalwidth-1:0] outp_east;

    // Instantiate DUT
    block #(
        .row_no(0),
        .column_no(0),
        .datawidth(datawidth)
    ) dut (
        .value(value),
        .inp_west(inp_west),
        .clk(clk),
        .rst_vals(rst_vals),
        .rst_overall(rst_overall),
        .train_en(train_en),
        .weight_update(weight_update),
        .outp_east(outp_east)
    );

    // Clock generator
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
    reg signed [totalwidth-1:0] expected, multi, acc;
    reg signed [datawidth-1:0] current_weight;

    $display("===== Starting Block Module Test =====");

    // Apply overall reset first
    rst_overall = 1;
    rst_vals = 0;
    train_en = 0;
    value = 0;
    inp_west = 0;
    weight_update = 0;
    current_weight = 1;

    @(posedge clk);
    rst_overall = 0;
    @(posedge clk);

    $display("Reset done. outp_east=%0d (Expected=0)", outp_east);

        // Release rst_vals and apply inputs
        rst_vals = 0;
        value = 5;
        inp_west = 10;
        train_en = 1;
        weight_update = 1;
        @(posedge clk);
        train_en = 0;

        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        multi = value * current_weight;
        acc = multi + inp_west;
        expected = acc;
        $display("Test1: value=%0d, weight=%0d, inp_west=%0d", value, current_weight, inp_west);
        $display("Expected=%0d, Obtained=%0d", expected, outp_east);

        // Enable training
        train_en = 1;
        weight_update = 3;

        @(posedge clk);
        train_en = 0;
        current_weight = current_weight + weight_update;

        @(posedge clk);

        multi = value * current_weight;
        acc = multi + inp_west;
        expected = acc;

        @(posedge clk);
        @(posedge clk);
        
        $display("Test2: After training, weight=%0d", current_weight);
        $display("Expected=%0d, Obtained=%0d", expected, outp_east);

        // Positive saturation test
        value = (1 << (datawidth-2));   // Large positive number
        inp_west = (1 << (totalwidth-2)); // Large positive number

        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        multi = value * current_weight;
        acc = multi + inp_west;
        if (~multi[totalwidth-1] && ~inp_west[totalwidth-1] && acc[totalwidth-1])
            expected = {1'b0, {(totalwidth-1){1'b1}}};
        else
            expected = acc;

        $display("Test3: Positive saturation");
        $display("Expected=%0d, Obtained=%0d", expected, outp_east);

        // Negative saturation test
        value = -(1 << (datawidth-2));
        inp_west = -(1 << (totalwidth-2));

        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        multi = value * current_weight;
        acc = multi + inp_west;
        if (multi[totalwidth-1] && inp_west[totalwidth-1] && ~acc[totalwidth-1])
            expected = {1'b1, {(totalwidth-1){1'b0}}};
        else
            expected = acc;

        $display("Test4: Negative saturation");
        $display("Expected=%0d, Obtained=%0d", expected, outp_east);

        // Apply rst_overall
        rst_overall = 1;
        @(posedge clk);
        rst_overall = 0;
        @(posedge clk);
        $display("After rst_overall: outp_east=%0d (Expected=0)", outp_east);

        $display("===== End of Block Module Test =====");
        $finish;
    end

endmodule
