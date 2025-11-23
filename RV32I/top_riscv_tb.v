`timescale 1ns / 1ps
module top_riscv_tb;

    reg clk;
    reg reset;
    wire [31:0] out;

    top_riscv uut (
        .clk(clk),
        .reset(reset),
        .out(out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset = 1;
        $display("-----------------------------------------------------------------------------------------------------------------------------------");
        $display("Time (ns) \t PC (Hex) \t Instruction (Hex) \t Result (Out)");
        $display("-----------------------------------------------------------------------------------------------------------------------------------");

        #10 reset = 0; 
        
        #10 reset = 1; 

        $display("%0t \t %h \t\t %h \t %h \t (Instruction: ADD)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: SUB)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: SLL)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: XOR)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: SRL)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: SRA)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: AND)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: OR)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: ADDI)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: SLLI)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: XORI)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: SLTI)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: SRLI)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: ORI)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: ANDI)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: LB)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: SB)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: BEQ)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: BNE)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: BGE)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: BLT)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: LUI)", $time, uut.pc, uut.instruction_out, out);
        
        #10 $display("%0t \t %h \t\t %h \t %h \t (Instruction: JAL)", $time, uut.pc, uut.instruction_out, out);
        
        #20 $display("-----------------------------------------------------------------------------------------------------------------------------------");
        $stop;
    end

endmodule
