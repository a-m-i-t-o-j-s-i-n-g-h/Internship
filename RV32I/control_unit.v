`timescale 1ns / 1ps

module control_unit(
                    input reset, 
                    input [6 :0] funct7,
                    input [2:0] funct3,
                    input [6:0] opcode,        
                    output reg [5:0] alu_control,
                    output reg lb,
                    output reg mem_to_reg,
                    output reg bneq_control,
                    output reg beq_control,
                    output reg bgeq_control,
                    output reg blt_control,
                    output reg jump,
                    output reg sw,
                    output reg lui_control
                   );
 
        always@(reset)
            begin
                if(reset == 0)
                    alu_control = 0;
            end

        always@(funct7 or funct3 or opcode  )
            begin
                if(opcode == 7'b0110011)
                    begin
                    mem_to_reg = 0;
                    beq_control = 0;
                    bneq_control = 0;
                    bgeq_control = 0;
                    blt_control = 0;
                    jump = 0;
                    lui_control = 0;

                case(funct3)
                    3'b000:
                        begin

                            if(funct7 == 0)
                                alu_control = 6'b000001;
                                                                           
                            else if(funct7 == 64)
                                alu_control = 6'b000010; 
                        end
                        
                    3'b001 :
                          begin
                             if(funct7 == 0)
                                alu_control = 6'b000011;                           
                           end

                      3'b010 :
                         begin
                              if(funct7 == 0)
                                  alu_control = 6'b000100; 
                           end
                           
                       3'b011 :
                            begin
                                if(funct7 == 0)
                                    alu_control = 6'b000101; 
                             end
                            
                       3'b100 :
                            begin
                                if(funct7 == 0)
                                    alu_control = 6'b000110; 
                                end

                      3'b101 :
                            begin
                                if(funct7 == 0)
                                    alu_control = 6'b000111; 
                                else
                                    if(funct7 == 64)
                                        alu_control = 6'b001000;   // shift right arthimetic
                             end
    
                      3'b110 :
                            begin
                                if(funct7 == 0)
                                   alu_control = 6'b001001; // or operation
                             end
                                 
                      3'b111 :
                            begin
                                if(funct7 == 0)
                                    alu_control = 6'b001010; //and operation
                             end
                  endcase
                  end
                 
                  else if(opcode == 7'b001_0011)// I TYPE
                  begin
                  
                  mem_to_reg = 0;
                  beq_control = 0;
                  bneq_control = 0;
                  jump = 0;
                  lb = 0;
                  sw = 0;
                        
                       case(funct3)
                                3'b000 :
                                        begin
                                            alu_control = 6'b001011; // add immediate
                                        end

                                3'b001 :
                                        begin
                                            alu_control = 6'b001100; // shift left logical immediate
                                        end
                                                                             
                                3'b010  :
                                        begin
                                            alu_control = 6'b001101; // SHIFT LEFT IMMEDIATE
                                         end
                                         
                                 3'b011 :
                                        begin
                                            alu_control = 6'b001110; // and immediate
                                         end
                                 3'b100 :
                                        begin
                                            alu_control = 6'b001111; //xor immediate
                                        end
                                        
                                  3'b101 :
                                        begin
                                            alu_control = 6'b010000; //shift right logic imm
                                         end
                                         
                                   3'b110 :
                                        begin
                                            alu_control = 6'b010001; // OR IMMEDIATE
                                        end
                                   
                                   3'b111 :
                                        begin
                                            alu_control = 6'b010010; // AND IMMEDIATE
                                        end
                               endcase
                            end
                        
                        else if(opcode == 7'b000_0011) // I type (load instructions)
                        begin
                        
                            case(funct3)
                                3'b000 :
                                        begin
                                            mem_to_reg = 1;           
                                            beq_control = 0;                  
                                            bneq_control = 0;                 
                                            jump = 0;  
                                            lb = 1;               
                                            alu_control = 6'b010011; // load byte
                                         end
                                3'b001 :
                                    begin
                                        alu_control = 6'b010100; // load_half
                                        mem_to_reg = 1;        
                                        beq_control = 0;               
                                        bneq_control = 0;              
                                        jump = 0;              
                                     end
                                     
                                3'b010 :begin
                                        
                                        alu_control = 6'b010101; //load_word
                                        mem_to_reg = 1;        
                                        beq_control = 0;               
                                        bneq_control = 0;              
                                        jump = 0;              
                                        end
                                        
                                3'b011 :begin

                                        mem_to_reg = 1;        
                                        beq_control = 0;               
                                        bneq_control = 0;              
                                        jump = 0;              
                                        alu_control = 6'b010110;//load_byte unsigned
                                        end
                                                                                
                                3'b100 :begin
                                        mem_to_reg = 1;        
                                        beq_control = 0;               
                                        bneq_control = 0;              
                                        jump = 0;
                                        alu_control = 6'b010111; // load_half unsigned    
                                        end
                                    endcase
                                    end
                                    
                          else if(opcode == 7'b0100_011)
                            begin
                            case(funct3)
                                3'b010 :begin
                                        mem_to_reg = 1;        
                                        beq_control = 0;               
                                        bneq_control = 0;              
                                        jump = 0;
                                        sw = 1;
                                        alu_control = 6'b011000; // store byte
                                        end
                                        
                                3'b110 :begin
                                        mem_to_reg = 1;        
                                        beq_control = 0;               
                                        bneq_control = 0;              
                                        jump = 0;
                                        alu_control = 6'b011001; // store half word
                                        end
                                        
                                3'b111 :begin
                                        mem_to_reg = 1;        
                                        beq_control = 0;               
                                        bneq_control = 0;              
                                        jump = 0;
                                        sw = 1;
                                        alu_control = 6'b011010; // store word
                                        end
                           endcase
                       end
                       
                       else if(opcode == 7'b110_0011)
                       begin
                            case(funct3)
                            //BRANCH EQUAL INSTRUCTION
                                3'b000 :
                                    begin
                                    alu_control = 6'b011011; 
                                    beq_control = 1;
                                    bneq_control = 0;
                                    blt_control = 0;
                                    bgeq_control = 0;
                                    
                                    end
                                    
                               //BRANCH UNEQUAL     
                                3'b001 :
                                    begin
                                    alu_control = 6'b011100; //branch unequal
                                    bneq_control = 1;
                                    beq_control = 0;
                                    blt_control = 0;
                                    bgeq_control = 0;
                                    
                                    end
                                    
                                 3'b010 :
                                    alu_control = 6'b011101; //branch less than
                                    
                                 3'b100 :
                                    
                                    begin
                                    alu_control = 6'b100000; //BRANCH LESS THAN INSTRUCTION
                                    blt_control = 1;
                                    beq_control = 0;
                                    bneq_control = 0;
                                    bgeq_control = 0;
                                    end
                                    
                                  3'b101 :
                                   begin
                                    alu_control = 6'b011111; // BRANCH IF GREATER THAN OR EQUAL TO 
                                    bgeq_control = 1;
                                    blt_control = 0;
                                    beq_control = 0;
                                    bneq_control = 0;
                                    end
                                 3'b110 :
                                    alu_control = 6'b011110; // branch greater than or equal to  unsigned 
                                    
                                endcase
                       end
 
                       //LUI INSTRUCTION
                       else if(opcode == 7'b011_0111)
                            begin
                               alu_control = 6'b100001;
                               lui_control = 1;
                               sw = 0;
                               lb = 0;
                               beq_control = 0;
                               blt_control = 0;
                               bneq_control = 0;
                               bgeq_control = 0;
                            end

                      //JUMP AND LINK OPERATION  
                       else if(opcode == 7'b110_1111)
                            begin
                                alu_control = 6'b100010;
                                jump = 1;
                                lui_control = 0;
                                sw = 0;
                                lb = 0;
                                beq_control = 0;
                                blt_control = 0;
                                bneq_control = 0;
                                bgeq_control = 0;
                             end          
               end 
                
        
endmodule
