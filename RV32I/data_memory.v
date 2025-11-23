`timescale 1ns / 1ps

module data_memory(
    input clk,
    input reset,
    input [31:0] data_out_2_dm,
    input [31:0] alu_result_address,
    input sw,
    input lb,
    output [31:0] data_out
);

reg [31:0] data_reg [31:0]; 

integer i;

initial begin
    for (i = 0; i < 32; i = i + 1) begin
        data_reg[i] <= i;
    end
end

assign data_out = data_reg[alu_result_address[4:0]];

always@(posedge clk) begin
    if (sw) begin
        data_reg[alu_result_address[4:0]] <= data_out_2_dm;
    end
end

endmodule
