`timescale 1ns / 1ps

module alu( input clk, reset,
            input [31 :0] src1,
            input [31: 0] src2,
            input [5:0] alu_control,
            input [31:0] imm_val_r,
            input [4:0] shamt,
            output reg [31:0] result
    );
    
    always@(posedge clk)
        begin
         if (reset == 0)
                result <= 0;

        else begin
            case(alu_control)
                6'b000001 ://addition 
                        begin
                                result <= src1 + src2;
                        end

                6'b000010 : //subraction
                                result <= src1 - src2;

                6'b000011 : //shift left logical
                                result <= src1 << src2;
            
                6'b000100 : // set less than
                        begin
                                result <= ($signed(src1) < $signed(src2)) ? 32'b1 : 32'b0;
                        end
                        
                 6'b000101 : // set less than unsigned
                        begin
                                result <= (src1 < src2) ? 32'b1: 32'b0;
                        end
                        
                 6'b000110 : // xor operation
                        begin
                                result <= src1 ^ src2;
                        end
                        
                  6'b000111 : //shift right logical
                        begin
                                result <= src1 >> src2;
                         end
                   
                   6'b001000 : // shift right arthimetic
                        begin
                                result <= src1 >>> src2;
                         end
                         
                    6'b001001 : //or operation
                        begin
                                result <= src1 | src2;
                        end
                        
                    6'b001010 : // and operation    
                         begin
                                result <= (src1) & src2 ;
                          end
                          
                     6'b001011 :
                                result <= src1 + imm_val_r; // add immediate

                     6'b001100 :
                                result <= src1 << shamt; // shift left logical immediate

                     6'b001101 :
                                result <= (imm_val_r < src1) ? 32'b1 : 32'b0; // SET LESS THAN IMMEDIATE
                                        
                     6'b001110:
                                result <= src1 & imm_val_r;
              
                     6'b001111 :
                               result <= src1 ^ imm_val_r; // xor immediate
               
                    6'b010000 :              
                               result <= src1 >> shamt; // shift right logical immediate
                                
                    6'b010001 :    // OR IMMEDIATE
                              result <= src1 | imm_val_r;
                                         
                    6'b010010 :  
                               result <= src1 & imm_val_r;
                                   
                    // BRANCH INSTRUCTIONS
                    6'b011011 :
                                result  <=  (src1 == src2) ? 32'b1 : 32'b0;
                                                                   
                    6'b011100 :
                                result <= (src1 != src2) ? 32'b1 : 32'b0;
                                                              
                   6'b011111 :
                                result <= (src2 >= src1) ? 32'b1 : 32'b0 ; //bgeq;
                                
                   6'b100000 : //branch less than instruction
                                result <= (src1 < src2) ? 32'b1 : 32'b0 ; 
      
            endcase
           end
        end
 
endmodule
