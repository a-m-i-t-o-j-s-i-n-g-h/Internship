`timescale 1ns/ 1ps

module training_label #(parameter layers = 3, parameter integer rows[0:layers-1] = {50, 30, 10})(
  input        rst_vals,
  input clk,
  input input_loaded,
  input  [$clog2(rows[layers-1]-1)-1:0] value,
  output reg [0:rows[layers-1]-1] label
);

  always_ff @(posedge clk) begin
    if (rst_vals) begin
      label <= 0;
    end else if (input_loaded) begin
      label <= 0;
      label[value] <= 1'b1;
    end
  end

endmodule
