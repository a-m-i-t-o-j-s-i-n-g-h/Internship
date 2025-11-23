`timescale 1ns / 1ps

module top_riscv(
                    input clk,
                    input reset,
                    output [31:0] out
    );

    wire [31:0] pc;
    wire [31:0] instruction_out;
    wire  [5:0] alu_control;
    wire  mem_to_reg;           
    wire  bneq_control;                 
    wire  beq_control;    
    wire  jump;
    wire lb;
    wire sw;
    wire [31:0] imm_val_branch_top;
    wire beq,bneq;
    wire bgeq_control;
    wire blt_control;
    wire bge;      
    wire blt;
    wire lui_control;
    wire [31:0] imm_val_lui;
    wire [31:0] imm_val_jump;
    wire [31:0] current_pc;
	wire [31:0]immediate_value_store;

    instruction_fetch_unit ifu(clk,
                               reset,
                               imm_val_branch_top,
                               imm_val_jump,
                               beq,
                               bneq,
                               bge,
                               blt,
                               jump,
                               pc,
                               current_pc);

    instruction_memory imu(clk,
                           pc,
                           reset,
                           instruction_out);
                           
    control_unit cu(reset,
                    instruction_out[31:25],
                    instruction_out[14:12],
                    instruction_out[6:0],
                    alu_control,
                    lb,
                    mem_to_reg,
                    bneq_control,
                    beq_control,
                    bgeq_control,
                    blt_control,
                    jump,
                    sw,
                    lui_control);
        
        data_path dpu(clk,reset,
                  instruction_out[19:15],
                  instruction_out[24 : 20],
                  instruction_out[11 : 7],
                  alu_control,
                  jump,
                  beq_control,
                  bneq_control,
                  immediate_value_store,
                  instruction_out[24:20],
                  lb,
                  sw,
                  bgeq_control,
                  blt_control,
                  lui_control,
                  imm_val_lui,
                  imm_val_jump,
                  current_pc,
                  beq,
                  bneq,
                  bge,
                  blt,
                  out);

    assign imm_val_branch_top = {{21{instruction_out[31]}},instruction_out[7],instruction_out[30:25],instruction_out[11:8]};
    assign imm_val_lui = {12'b0,instruction_out[31:12]};

	assign imm_val_jump = {{12{instruction_out[31]}},
                        instruction_out[19:12],
                        instruction_out[20],
                        instruction_out[30:21],
                        1'b0};
	assign immediate_value_store = {{20{instruction_out[31]}},instruction_out[31:20]};

endmodule