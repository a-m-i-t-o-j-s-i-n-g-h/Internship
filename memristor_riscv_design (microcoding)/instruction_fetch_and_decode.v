`timescale 1ns / 1ps

module instruction_fetch_and_decode (
    input clk,
    input reset,

    output reg [3:0] r_type_rom_addr,
    output reg [2:0] i_type_rom_addr,
    output reg [2:0] load_type_rom_addr,
    output reg [2:0] store_type_rom_addr,
    output reg [2:0] branch_type_rom_addr,
    output reg [0:0] jump_type_rom_addr,
    output reg [0:0] lui_type_rom_addr,
    
    output reg r_type_rom_en,
    output reg i_type_rom_en,
    output reg load_type_rom_en,
    output reg store_type_rom_en,
    output reg branch_type_rom_en,
    output reg jump_type_rom_en,
    output reg lui_type_rom_en,

    output wire [31:0] instruction_out
);

    reg [31:0] pc;
    wire [31:0] instruction;

    instruction_memory imu (
        .clk(clk),
        .pc(pc),
        .reset(reset),
        .instruction_code(instruction)
    );
    
    assign instruction_out = instruction;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 32'h00000000;
        end else begin
            pc <= pc + 4;
        end
    end

    wire [6:0] opcode = instruction[6:0];
    wire [2:0] funct3 = instruction[14:12];
    wire [6:0] funct7 = instruction[31:25];

    always @(*) begin
        r_type_rom_en      = 1'b0;
        i_type_rom_en      = 1'b0;
        load_type_rom_en   = 1'b0;
        store_type_rom_en  = 1'b0;
        branch_type_rom_en = 1'b0;
        jump_type_rom_en   = 1'b0;
        lui_type_rom_en    = 1'b0;

        r_type_rom_addr      = 4'b0;
        i_type_rom_addr      = 3'b0;
        load_type_rom_addr   = 3'b0;
        store_type_rom_addr  = 3'b0;
        branch_type_rom_addr = 3'b0;
        jump_type_rom_addr   = 1'b0;
        lui_type_rom_addr    = 1'b0;
        
        case (opcode)
            7'b0110011: begin 
                r_type_rom_en = 1'b1;
                r_type_rom_addr = {funct7[5], funct3};
            end
            
            7'b0010011: begin 
                i_type_rom_en = 1'b1;
                i_type_rom_addr = funct3;
            end

            7'b0000011: begin 
                load_type_rom_en = 1'b1;
                load_type_rom_addr = funct3;
            end
            
            7'b0100011: begin 
                store_type_rom_en = 1'b1;
                store_type_rom_addr = funct3;
            end

            7'b1100011: begin 
                branch_type_rom_en = 1'b1;
                branch_type_rom_addr = funct3;
            end
            
            7'b1101111: begin
                jump_type_rom_en = 1'b1;
                jump_type_rom_addr = 1'b0;
            end

            7'b1100111: begin
                jump_type_rom_en = 1'b1;
                jump_type_rom_addr = 1'b1;
            end
            
            7'b0110111: begin 
                lui_type_rom_en = 1'b1;
                lui_type_rom_addr = 1'b0;
            end
            
            default: begin

            end
        endcase
    end
endmodule
