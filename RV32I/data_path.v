`timescale 1ns / 1ps

module data_path(
    input clk,
    input rst,
    input [4:0] read_reg_num1,
    input [4:0] read_reg_num2,
    input [4:0] write_reg_num1,
    input [5:0] alu_control,
    input jump,beq_control,bne_control,
    input [31:0] imm_val,
    input [4:0] shamt,
    input lb,
    input sw,
    input bgeq_control,
    input blt_control,
    input lui_control,
    input [31:0] imm_val_lui,
    input [31:0] imm_val_jump,
    input [31:0] return_address,
    output  beq,bneq,bge,blt,
    output [31:0] write_data_alu_2
    );

    wire [31:0] read_data1;
    
    wire [31:0] read_data2;
    
    wire [4:0] read_data_addr_dm_2;
    
    wire [31:0] write_data_alu;

    wire [31:0] data_out;
    
    wire [31:0]  data_out_2_dm;
    
    register_file rfu (clk,rst,write_data_alu,read_reg_num1,read_reg_num2,write_reg_num1,data_out,lb,lui_control,imm_val_lui,return_address,jump,read_data1,read_data2,read_data_addr_dm_2,data_out_2_dm,sw);
    
    alu alu_unit(clk, rst, read_data1,read_data2,alu_control,imm_val,shamt,write_data_alu);
    
    data_memory dmu(clk,rst,data_out_2_dm,write_data_alu,sw,lb,data_out);
    
     assign beq = (write_data_alu == 32'b1 && beq_control == 1) ? 1 : 0;
     
     assign bneq = (write_data_alu == 32'b1 && bne_control == 1) ? 1 : 0;
     
     assign bge = (write_data_alu == 32'b1 && bgeq_control == 1) ? 1 : 0 ;
     
     assign blt = (write_data_alu == 32'b1 && blt_control == 1) ? 1 : 0;

     assign write_data_alu_2 = write_data_alu;
     
     
     
         
endmodule
