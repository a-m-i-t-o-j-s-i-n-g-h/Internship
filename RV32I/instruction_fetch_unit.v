`timescale 1ns / 1ps

module instruction_fetch_unit(
                                input clk,                          
                                input reset,                        
                                input [31:0] imm_address,           
                                input [31:0] imm_address_jump,      
                                input beq,                          
                                input bneq,                         
                                input bge,                          
                                input blt,                          
                                input jump,                         
                                output reg [31:0] pc,               
                                output reg [31:0] current_pc        
    );
    
    always@(posedge clk)
        begin
            if(reset == 0)
                begin
                    pc <= 0;
                end
            else if(beq == 0 && bneq == 0 && bge == 0 && blt == 0 && jump == 0)
                    pc <= pc + 4;
                    
            else if(beq == 1 || bneq == 1 || bge == 1 || blt == 1)
                    pc <= pc + imm_address;
          
            else if(jump)
                    pc <= pc + imm_address_jump;
         end

         always@(posedge clk)
            begin
            if(reset == 0)
                begin
                    current_pc <= 0;
                 end
                 
                else if(jump == 0)
                    current_pc <= current_pc + 4;
                else
                    current_pc <= current_pc;
            end
    
endmodule
