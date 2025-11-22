`timescale 1ns / 1ps

module tb_softmax_block;

    // Parameters
    localparam datawidth = 11;
    localparam rows = 10;
    localparam lut_width = 22;

    // DUT I/O
    reg signed [rows*datawidth-1:0] in;
    wire signed [rows*datawidth-1:0] out;

    // Instantiate DUT
    softmax_block #(
        .datawidth(datawidth),
        .rows(rows),
        .lut_width(lut_width)
    ) dut (
        .in(in),
        .out(out)
    );

    // Task to print input and output values
    task print_softmax_result;
        input [255:0] testname;
        integer i;
        reg signed [datawidth-1:0] in_val, out_val;
        begin
            $display("--------------------------------------------------");
            $display("Test: %s", testname);
            for (i = 0; i < rows; i = i + 1) begin
                in_val  = in[i*datawidth +: datawidth];
                out_val = out[i*datawidth +: datawidth];
                $display("Input[%0d] = %0d | Output[%0d] = %0d", i, in_val, i, out_val);
            end
            $display("--------------------------------------------------\n");
        end
    endtask

    // Simulation procedure
    integer i;
    reg signed [datawidth-1:0] temp_vals [0:9];

    initial begin
        $display("====== Softmax Testbench Start ======");

        // Stage 1: Ascending input
        for (i = 0; i < rows; i = i + 1)
            in[i*datawidth +: datawidth] = $signed(i);
        #10;
        print_softmax_result("Ascending: [0..9]");

        // Stage 2: Descending input
        for (i = 0; i < rows; i = i + 1)
            in[i*datawidth +: datawidth] = $signed(rows - 1 - i);
        #10;
        print_softmax_result("Descending: [9..0]");

        // Stage 3: All 5s
        for (i = 0; i < rows; i = i + 1)
            in[i*datawidth +: datawidth] = $signed(5);
        #10;
        print_softmax_result("All fives");

        // Stage 4: Random mix: {-1, 5, 2, 6, 4, -2, 0, 1, 7, 3}
        temp_vals[0] = -1;
        temp_vals[1] = 5;
        temp_vals[2] = 2;
        temp_vals[3] = 6;
        temp_vals[4] = 4;
        temp_vals[5] = -2;
        temp_vals[6] = 0;
        temp_vals[7] = 1;
        temp_vals[8] = 7;
        temp_vals[9] = 3;

        for (i = 0; i < rows; i = i + 1)
            in[i*datawidth +: datawidth] = temp_vals[i];
        #10;
        print_softmax_result("Random mix");

        // Stage 5: All negative: [0, -1, -2, ..., -9]
        for (i = 0; i < rows; i = i + 1)
            in[i*datawidth +: datawidth] = $signed(-i);
        #10;
        print_softmax_result("All negative");

        $display("====== Softmax Testbench Complete ======");
        $finish;
    end

endmodule
