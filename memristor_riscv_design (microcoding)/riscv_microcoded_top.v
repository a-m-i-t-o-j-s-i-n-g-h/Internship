`timescale 1ns / 1ps

`define MICROCODE_WIDTH 64

module riscv_microcoded_top (
    input clk,
    input reset,
    output wire [`MICROCODE_WIDTH-1:0] final_microcode_word,
    output wire [31:0] current_instruction
);

    wire [3:0] r_type_rom_addr;
    wire [2:0] i_type_rom_addr;
    wire [2:0] load_type_rom_addr;
    wire [2:0] store_type_rom_addr;
    wire [2:0] branch_type_rom_addr;
    wire [0:0] jump_type_rom_addr;
    wire [0:0] lui_type_rom_addr;
    
    wire r_type_rom_en;
    wire i_type_rom_en;
    wire load_type_rom_en;
    wire store_type_rom_en;
    wire branch_type_rom_en;
    wire jump_type_rom_en;
    wire lui_type_rom_en;

    wire [`MICROCODE_WIDTH-1:0] r_type_microcode;
    wire [`MICROCODE_WIDTH-1:0] i_type_microcode;
    wire [`MICROCODE_WIDTH-1:0] load_type_microcode;
    wire [`MICROCODE_WIDTH-1:0] store_type_microcode;
    wire [`MICROCODE_WIDTH-1:0] branch_type_microcode;
    wire [`MICROCODE_WIDTH-1:0] jump_type_microcode;
    wire [`MICROCODE_WIDTH-1:0] lui_type_microcode;
    
    instruction_fetch_and_decode ifd_unit (
        .clk(clk),
        .reset(reset),
        .r_type_rom_addr(r_type_rom_addr),
        .i_type_rom_addr(i_type_rom_addr),
        .load_type_rom_addr(load_type_rom_addr),
        .store_type_rom_addr(store_type_rom_addr),
        .branch_type_rom_addr(branch_type_rom_addr),
        .jump_type_rom_addr(jump_type_rom_addr),
        .lui_type_rom_addr(lui_type_rom_addr),
        .r_type_rom_en(r_type_rom_en),
        .i_type_rom_en(i_type_rom_en),
        .load_type_rom_en(load_type_rom_en),
        .store_type_rom_en(store_type_rom_en),
        .branch_type_rom_en(branch_type_rom_en),
        .jump_type_rom_en(jump_type_rom_en),
        .lui_type_rom_en(lui_type_rom_en),
        .instruction_out(current_instruction)
    );

    r_type_microcode_rom r_rom (.address(r_type_rom_addr), .microcode(r_type_microcode));
    i_type_microcode_rom i_rom (.address(i_type_rom_addr), .microcode(i_type_microcode));
    load_type_microcode_rom load_rom (.address(load_type_rom_addr), .microcode(load_type_microcode));
    store_type_microcode_rom store_rom (.address(store_type_rom_addr), .microcode(store_type_microcode));
    branch_type_microcode_rom branch_rom (.address(branch_type_rom_addr), .microcode(branch_type_microcode));
    jump_type_microcode_rom jump_rom (.address(jump_type_rom_addr), .microcode(jump_type_microcode));
    lui_type_microcode_rom lui_rom (.address(lui_type_rom_addr), .microcode(lui_type_microcode));
    
    assign final_microcode_word = 
        (r_type_rom_en)      ? r_type_microcode :
        (i_type_rom_en)      ? i_type_microcode :
        (load_type_rom_en)   ? load_type_microcode :
        (store_type_rom_en)  ? store_type_microcode :
        (branch_type_rom_en) ? branch_type_microcode :
        (jump_type_rom_en)   ? jump_type_microcode :
        (lui_type_rom_en)    ? lui_type_microcode :
        `MICROCODE_WIDTH'h0;

endmodule
