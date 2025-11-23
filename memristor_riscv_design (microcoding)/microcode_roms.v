`timescale 1ns / 1ps

`define MICROCODE_WIDTH 64

// R-Type Instructions (add, sub, sll, slt, sltu, xor, srl, sra, or, and)
module r_type_microcode_rom (
    input [3:0] address,
    output reg [`MICROCODE_WIDTH-1:0] microcode
);
    always @(*) begin
        case (address)
            // Address - {funct7[5], funct3}
            4'b0000: microcode = `MICROCODE_WIDTH'h0; // ADD
            4'b1000: microcode = `MICROCODE_WIDTH'h0; // SUB
            4'b0001: microcode = `MICROCODE_WIDTH'h0; // SLL
            4'b0010: microcode = `MICROCODE_WIDTH'h0; // SLT
            4'b0011: microcode = `MICROCODE_WIDTH'h0; // SLTU
            4'b0100: microcode = `MICROCODE_WIDTH'h0; // XOR
            4'b0101: microcode = `MICROCODE_WIDTH'h0; // SRL
            4'b1101: microcode = `MICROCODE_WIDTH'h0; // SRA
            4'b0110: microcode = `MICROCODE_WIDTH'h0; // OR
            4'b0111: microcode = `MICROCODE_WIDTH'h0; // AND
            default: microcode = `MICROCODE_WIDTH'h0;
        endcase
    end
endmodule


// I-Type (Immediate Arithmetic) Instructions (addi, slti, sltiu, xori, ori, andi, slli, srli, srai)
module i_type_microcode_rom (
    input [2:0] address, // funct3
    output reg [`MICROCODE_WIDTH-1:0] microcode
);
    always @(*) begin
        case (address)
            3'b000: microcode = `MICROCODE_WIDTH'h0; // ADDI
            3'b010: microcode = `MICROCODE_WIDTH'h0; // SLTI
            3'b011: microcode = `MICROCODE_WIDTH'h0; // SLTIU
            3'b100: microcode = `MICROCODE_WIDTH'h0; // XORI
            3'b110: microcode = `MICROCODE_WIDTH'h0; // ORI
            3'b111: microcode = `MICROCODE_WIDTH'h0; // ANDI
            // SLLI, SRLI, SRAI have same funct3 as their R-type counterparts
            // but different opcodes, handled by the main decoder.
            3'b001: microcode = `MICROCODE_WIDTH'h0; // SLLI
            3'b101: microcode = `MICROCODE_WIDTH'h0; // SRLI/SRAI
            default: microcode = `MICROCODE_WIDTH'h0;
        endcase
    end
endmodule


// Load Instructions (lb, lh, lw, lbu, lhu)
module load_type_microcode_rom (
    input [2:0] address, // funct3
    output reg [`MICROCODE_WIDTH-1:0] microcode
);
    always @(*) begin
        case (address)
            3'b000: microcode = `MICROCODE_WIDTH'h0; // LB
            3'b001: microcode = `MICROCODE_WIDTH'h0; // LH
            3'b010: microcode = `MICROCODE_WIDTH'h0; // LW
            3'b100: microcode = `MICROCODE_WIDTH'h0; // LBU
            3'b101: microcode = `MICROCODE_WIDTH'h0; // LHU
            default: microcode = `MICROCODE_WIDTH'h0;
        endcase
    end
endmodule


// Store Instructions (sb, sh, sw)
module store_type_microcode_rom (
    input [2:0] address, // funct3
    output reg [`MICROCODE_WIDTH-1:0] microcode
);
    always @(*) begin
        case (address)
            3'b000: microcode = `MICROCODE_WIDTH'h0; // SB
            3'b001: microcode = `MICROCODE_WIDTH'h0; // SH
            3'b010: microcode = `MICROCODE_WIDTH'h0; // SW
            default: microcode = `MICROCODE_WIDTH'h0;
        endcase
    end
endmodule


// Branch Instructions (beq, bne, blt, bge, bltu, bgeu)
module branch_type_microcode_rom (
    input [2:0] address, // funct3
    output reg [`MICROCODE_WIDTH-1:0] microcode
);
    always @(*) begin
        case (address)
            3'b000: microcode = `MICROCODE_WIDTH'h0; // BEQ
            3'b001: microcode = `MICROCODE_WIDTH'h0; // BNE
            3'b100: microcode = `MICROCODE_WIDTH'h0; // BLT
            3'b101: microcode = `MICROCODE_WIDTH'h0; // BGE
            3'b110: microcode = `MICROCODE_WIDTH'h0; // BLTU
            3'b111: microcode = `MICROCODE_WIDTH'h0; // BGEU
            default: microcode = `MICROCODE_WIDTH'h0;
        endcase
    end
endmodule


// Jump Instructions (JAL, JALR)
module jump_type_microcode_rom (
    input [0:0] address,
    output reg [`MICROCODE_WIDTH-1:0] microcode
);
    always @(*) begin
        case (address)
            1'b0: microcode = `MICROCODE_WIDTH'h0; // JAL
            1'b1: microcode = `MICROCODE_WIDTH'h0; // JALR
            default: microcode = `MICROCODE_WIDTH'h0;
        endcase
    end
endmodule


// LUI Instruction
module lui_type_microcode_rom (
    input [0:0] address,
    output reg [`MICROCODE_WIDTH-1:0] microcode
);
    always @(*) begin
        case(address)
            1'b0: microcode = `MICROCODE_WIDTH'h0; // LUI
            default: microcode = `MICROCODE_WIDTH'h0;
        endcase
    end
endmodule
