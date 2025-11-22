`timescale 1ns / 1ps

module tb_relu_block;

    // Parameters
    localparam datawidth = 11;
    localparam rows = 4;  // Minimal case for demo

    // Signals
    logic signed [rows*datawidth-1:0] in;
    logic signed [rows*datawidth-1:0] out;
    logic rst_vals;
    logic rst_overall;
    logic layer_done;
    logic done;


    // Instantiate DUT
    relu_block #(
        .datawidth(datawidth),
        .rows(rows)
    ) dut (
        .rst_vals(rst_vals),
        .rst_overall(rst_overall),
        .layer_done(layer_done),
        .in(in),
        .out(out),
        .done(done)
    );

    // Task to display input/output
    task print_result;
        integer i;
        logic signed [datawidth-1:0] in_i, out_i;
        begin
            $display("--------------------------------------------------");
            for (i = 0; i < rows; i++) begin
                in_i  = in[i*datawidth +: datawidth];
                out_i = out[i*datawidth +: datawidth];
                $display("Input[%0d] = %0d | Output[%0d] = %0d | Expected = %0d, Done = %b",
                         i, in_i, i, out_i, (in_i < 0) ? 0 : in_i, done);
            end
            $display("--------------------------------------------------");
        end
    endtask

    initial begin
        $display("==== Testbench for relu_block ====");
        rst_vals = 1;
        rst_overall = 0;
        #10;
        rst_vals = 0;
        layer_done = 1;
        // Test vector: { -15, 5, -2, 20 }
        in[0*datawidth +: datawidth] = -15;
        in[1*datawidth +: datawidth] = 5;
        in[2*datawidth +: datawidth] = -2;
        in[3*datawidth +: datawidth] = 20;

        #1;
        
        print_result();

        // Another test vector: { 0, -1, 7, -8 }
        in[0*datawidth +: datawidth] = 0;
        in[1*datawidth +: datawidth] = -1;
        in[2*datawidth +: datawidth] = 7;
        in[3*datawidth +: datawidth] = -8;

        #1;
        print_result();

        $finish;
    end

endmodule
