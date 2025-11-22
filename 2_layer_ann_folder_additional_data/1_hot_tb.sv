`timescale 1ns / 1ps

module tb_training_label;

  // Parameters
  parameter layers = 3;
  parameter int rows[0:layers-1] = '{50, 30, 10};

  // Signals
  logic rst_vals;
  logic [$clog2(rows[layers-1]-1)-1:0] value;
  logic [rows[layers-1]-1:0] label;

  // DUT
  training_label #(
  .layers(3),
  .rows('{50, 30, 10})
) uut (
  .rst_vals(rst_vals),
  .value(value),
  .label(label)
);


  // Test sequence
  initial begin
    $display("Starting 1-hot encoder test...");

    rst_vals = 1;
    value = 0;
    #10;
    $display("Reset: label = %b", label);

    rst_vals = 0;
    value = 3;
    #10;
    $display("Value = 3: label = %b", label);

    value = 7;
    #10;
    $display("Value = 7: label = %b", label);

    value = 9;
    #10;
    $display("Value = 9: label = %b", label);

    value = 10; // out of range (should be ignored or undefined)
    #10;
    $display("Value = 10: label = %b", label);

    $finish;
  end

endmodule
