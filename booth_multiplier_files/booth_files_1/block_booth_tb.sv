`timescale 1ns/1ps

module tb_block;

    parameter int datawidth = 11;
    parameter int columns   = 64;
    localparam totalwidth   = 2*datawidth;
    localparam accwidth     = totalwidth + $clog2(columns);

    // Testbench signals
    reg  signed [datawidth-1:0] value;
    reg  signed [accwidth-1:0] inp_west;
    reg  clk;
    reg  en;
    reg  rst_vals;
    reg  rst_overall;
    reg  train_en;
    reg  signed [datawidth-1:0] weight_update;
    wire signed [accwidth-1:0] outp_east;

    // Instantiate DUT
    block #(
        .row_no(0),
        .column_no(0),
        .columns(columns),
        .datawidth(datawidth)
    ) dut (
        .value(value),
        .inp_west(inp_west),
        .clk(clk),
        .en(en),
        .rst_vals(rst_vals),
        .rst_overall(rst_overall),
        .train_en(train_en),
        .weight_update(weight_update),
        .outp_east(outp_east)
    );

    // Clock generator
    initial clk = 0;
    always #5 clk = ~clk;

    // Helper task: wait until mul_done has updated the output
    task wait_mul_done;
        @(posedge clk); // Wait at least one cycle for booth_multiplier
        repeat (datawidth+2) @(posedge clk); // Wait enough cycles for Booth to finish
    endtask

    initial begin
        reg signed [totalwidth-1:0] multi;
        reg signed [accwidth-1:0] expected, acc;
        reg signed [datawidth-1:0] current_weight;

        $display("===== Starting Block Module Test =====");

        // Reset
        en          = 0;
        rst_overall = 1;
        rst_vals    = 0;
        train_en    = 0;
        value       = 0;
        inp_west    = 0;
        weight_update = 0;

        @(posedge clk);
        rst_overall = 0;
        current_weight = 0;

        @(posedge clk);
        $display("Reset done. outp_east=%0d (Expected=0)", outp_east);

        // === Test 1: Training + multiply ===
        rst_vals = 0;
        value    = 5;
        inp_west = 10;
        train_en = 1;
        weight_update = 1;
        current_weight = current_weight + weight_update;
        @(posedge clk);
        train_en = 0;

        // Start multiplication
        en = 1;
        wait_mul_done();

        multi = value * current_weight;
        acc   = $signed({{($clog2(columns)){multi[totalwidth-1]}}, multi}) + $signed(inp_west);
        expected = acc;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        $display("Test1: value=%0d, weight=%0d", value, current_weight);
//        $display("Mul_start=%0d, mul_done=%0d, Value = %0d, Weight = %0d, Product = %0d", dut.booth_mul_inst.start, dut.mul_done, dut.booth_mul_inst.a, dut.booth_mul_inst.b, dut.booth_mul_inst.product);
        $display("Expected=%0d, Obtained=%0d, Product = %0d", expected, outp_east, dut.multi);
        en = 0;
        @(posedge clk);
        // === Test 2: Further training ===
        train_en = 1;
        weight_update = 3;
        @(posedge clk);
        train_en = 0;
        current_weight = current_weight + weight_update;

        en = 1;
        wait_mul_done();

        multi = value * current_weight;
        acc   = $signed({{($clog2(columns)){multi[totalwidth-1]}}, multi}) + $signed(inp_west);
        expected = acc;

        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        $display("Test2: After training, weight=%0d", current_weight);
        $display("Expected=%0d, Obtained=%0d, Product = %0d", expected, outp_east, dut.multi);
        en = 0;
        @(posedge clk);
        // === Test 3: Positive saturation ===
        value    = (1 << (datawidth-2));
        inp_west = (1 << (totalwidth-2));

        en = 1;
        wait_mul_done();

        multi = value * current_weight;
        acc   = $signed({{($clog2(columns)){multi[totalwidth-1]}}, multi}) + $signed(inp_west);

        if (acc > {1'b0,{(accwidth-1){1'b1}}})
            expected = {1'b0,{(accwidth-1){1'b1}}};
        else
            expected = acc;

        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        $display("Test3: Positive saturation");
        $display("Expected=%0d, Obtained=%0d, Product = %0d", expected, outp_east, dut.multi);
        
        en = 0;
        @(posedge clk);


        // === Test 4: Negative saturation ===
        value    = -(1 << (datawidth-2));
        inp_west = -(1 << (totalwidth-2));

        en = 1;
        wait_mul_done();

        multi = value * current_weight;
        acc   = $signed({{($clog2(columns)){multi[totalwidth-1]}}, multi}) + $signed(inp_west);

        if (acc < {1'b1,{(accwidth-1){1'b0}}})
            expected = {1'b1,{(accwidth-1){1'b0}}};
        else
            expected = acc;
        
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        $display("Test4: Negative saturation");
        $display("Expected=%0d, Obtained=%0d, Product = %0d", expected, outp_east, dut.multi);
        en = 0;
        @(posedge clk);
        // === Reset again ===
        rst_overall = 1;
        @(posedge clk);
        rst_overall = 0;
        @(posedge clk);
        $display("After rst_overall: outp_east=%0d (Expected=0)", outp_east);

        $display("===== End of Block Module Test =====");
        $finish;
    end

endmodule
