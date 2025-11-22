module relu_block #(
    parameter datawidth = 11,
    parameter rows = 10
)(
    input clk,
    input rst_vals,
    input rst_overall,
    input layer_done,
    input wire signed [rows*datawidth-1:0] in,
    output logic signed [rows*datawidth-1:0] out,
   output logic done
);
    integer i;
    
    always_ff @(posedge clk) begin
        if (rst_overall||rst_vals) begin
            out <= 0;
            done <= 0;
        end
        else if (layer_done == 1) begin
        for (i = 0; i < rows; i = i + 1) begin
            if (in[(rows-i-1)*datawidth + datawidth - 1] == 1'b0) begin
                out[(rows-i-1)*datawidth +: datawidth] <= in[(rows-i-1)*datawidth +: datawidth];
            end else begin
                out[(rows-i-1)*datawidth +: datawidth] <= {datawidth{1'b0}};
            end
            end
        done <= 1;
        end
        else if (done == 1)
        done <= 0;
    //  else begin
    //  out <= 0;
    //  act_done <= 0;
    //  end
    end

    
    
   // always @(posedge clk) begin
   // if (done) begin
   // out <= out_temp;
   // act_done <= 1;
   // end
   // else begin
     //   out <= out_temp;
      //  act_done <= 1;
  //  end
  //  end
    
endmodule
