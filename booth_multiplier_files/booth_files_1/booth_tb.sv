`timescale 1ns/1ps

module tb_booth_multiplier;

    parameter int DATAWIDTH = 8;

    // DUT signals
    logic clk;
    logic rst_vals, rst_overall;
    logic start;
    logic signed [DATAWIDTH-1:0] a, b;
    logic signed [2*DATAWIDTH-1:0] product;
    logic done;

    // Instantiate DUT
    booth_multiplier #(
        .DATAWIDTH(DATAWIDTH)
    ) dut (
        .clk(clk),
        .rst_vals(rst_vals),
        .rst_overall(rst_overall),
        .start(start),
        .a(a),
        .b(b),
        .product(product),
        .done(done)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 10ns period

    // Task to run a test
    task run_test(input logic signed [DATAWIDTH-1:0] op_a,
                  input logic signed [DATAWIDTH-1:0] op_b);
        logic signed [2*DATAWIDTH-1:0] expected;
        begin
            expected = op_a * op_b;

            // Apply inputs + pulse start
            @(negedge clk);
            a     = op_a;
            b     = op_b;
            start = 1;
            @(negedge clk);
            start = 0;

            // Wait until done is asserted
            @(posedge done);
            #20; // small delay to ensure product is stable

            if (product !== expected) begin
                $display("MISMATCH: a=%0d b=%0d | DUT=%0d Expected=%0d",
                          op_a, op_b, product, expected);
            end else begin
                $display("PASS: a=%0d b=%0d | Product=%0d",
                          op_a, op_b, product);
            end
        end
    endtask

    // Stimulus
    initial begin
        $display("=== Booth Multiplier Testbench Start ===");

        // Reset
        rst_vals    = 1;
        rst_overall = 0;
        start       = 0;
        a           = 0;
        b           = 0;
        repeat(2) @(negedge clk);
        rst_vals = 0;

        // Basic tests
        run_test(5, 3);         
        run_test(-5, 3);        
        run_test(5, -3);        
        run_test(-5, -3);       
        run_test(0, 12);        
        run_test(12, 0);        

        // Edge cases
        run_test(127, 2);       
        run_test(-128, 2);      
        run_test(127, -128);    
        run_test(-128, -128);   

        // Random tests
        repeat (10) begin
            run_test($urandom_range(-128,127), $urandom_range(-128,127));
        end

        $display("=== Booth Multiplier Testbench End ===");
        $finish;
    end

endmodule
