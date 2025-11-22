`timescale 1ns / 1ps

module softmax_block #(
    parameter datawidth = 11,
    parameter rows = 10,
    parameter lut_width = 22
)(
    input  wire signed [rows*datawidth-1:0] in,
    output logic signed [rows*datawidth-1:0] out
);
    integer m;
    reg [lut_width-1:0] exp_vals [0:rows-1];
    reg [lut_width+4:0] sum_exp;
    reg [lut_width-1:0] softmax_vals [0:rows-1];
    reg [lut_width+datawidth-1:0] softmax_scaled;
    reg [lut_width-1:0] exp_lut [0:(1<<datawidth)-1];

    initial begin
         $readmemb("exp_lut.mem", exp_lut);
    end

    always @(*) begin
    sum_exp = 0;

    for (m = 0; m < rows; m = m + 1) begin
        logic signed [datawidth-1:0] val;
        val = in[(rows-m-1)*datawidth +: datawidth];
        exp_vals[m] = exp_lut[val];

        sum_exp = sum_exp + exp_vals[m];
    end

    if (sum_exp == 0)
        sum_exp = 1;

    if (sum_exp[lut_width+4] == 1)
        sum_exp = {1'b0, {(lut_width+4){1'b1}}};

    for (m = 0; m < rows; m = m + 1) begin
            // Fixed-point division: scale numerator before division
            softmax_scaled = (exp_vals[m] << datawidth) / sum_exp;

            // Debug print
            $display("[DEBUG] Input[%0d] = %0d | exp = %0d | sum_exp = %0d | softmax_scaled = %0d",
                     m, in[(rows - m - 1)*datawidth +: datawidth], exp_vals[m], sum_exp, softmax_scaled);

            // Slice top bits to match output datawidth
            out[(rows - m - 1)*datawidth +: datawidth] = softmax_scaled[lut_width-1 -: datawidth];
        end
end

endmodule

