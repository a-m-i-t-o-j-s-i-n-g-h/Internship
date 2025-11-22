`timescale 1ns / 1ps

module tb_weight_layers;

    // Parameters
    localparam layers = 2;
    localparam datawidth = 8;
    localparam int_part_input = 6;     // Q3.5 format
    localparam int_part_weight = 6;
    localparam max_rows = 2;
    localparam max_cols = 3;
    localparam lut_width = 22;

    // Layer-wise configuration
    localparam int rows0 = 2;
    localparam int rows1 = 2;
    localparam int cols0 = 3;
    localparam int cols1 = 2;
    localparam int activation0 = 0;
    localparam int activation1 = 0;

    // Derived widths
    localparam INPUT_WIDTH  = cols0 * datawidth;
    localparam WEIGHT_WIDTH = max_cols * datawidth;
    localparam BIAS_WIDTH   = max_rows * 2 * datawidth;

    // DUT signals
    logic clk = 0;
    logic rst_vals, rst_overall, en;
    logic [$clog2(layers)-1:0] train_layer_select;
    logic train;
    logic [$clog2(max_rows)-1:0] row_sel;
    logic [INPUT_WIDTH-1:0] input_values;
    logic [WEIGHT_WIDTH-1:0] weight_update;
    logic [BIAS_WIDTH-1:0] bias_updates;
    logic [rows1-1:0] final_out;
    logic final_done;
    logic input_loaded;

    // Clock
    always #5 clk = ~clk;

    // DUT instance
    weight_layers #(
        .layers(layers),
        .datawidth(datawidth),
        .int_part_input(int_part_input),
        .int_part_weight(int_part_weight),
        .rows('{rows0, rows1}),
        .cols('{cols0, cols1}),
        .max_rows(max_rows),
        .max_cols(max_cols),
        .activation('{activation0, activation1}),
        .lut_width(lut_width)
    ) dut (
        .clk(clk),
        .rst_vals(rst_vals),
        .rst_overall(rst_overall),
        .en(en),
        .train (train),
        .train_layer_select(train_layer_select),
        .row_sel(row_sel),
        .input_values(input_values),
        .weight_update(weight_update),
        .bias_updates(bias_updates),
        .final_out(final_out),
        .final_done(final_done),
        .input_loaded(input_loaded)
    );

    // Intermediate outputs
    logic signed [datawidth-1:0] trunc_row0, trunc_row1;
    logic signed [2*datawidth-1:0] pre_row0, pre_row1, relu_0;
    logic signed [datawidth-1:0] act1_row0, act1_row1;
    logic signed [2*datawidth-1:0] pre1_row0, pre1_row1;
    logic signed [2*datawidth-1:0] out_0;
    logic signed [2*datawidth-1:0] act_row0;

    always@(posedge clk) begin
        $display("Latched 0 = %b, Latched 1 = %b", dut.layer_done_latched[0], dut.layer_done_latched[1]);
        
        $display("Latched act 0 = %b, Latched act 1 = %b, curr_layer = %b, Layer en 1 = %b", dut.done[0], dut.done[1], dut.curr_layer, dut.layer_en[1]);
    end
    initial begin
        // === Reset ===
        rst_overall = 1; rst_vals = 0; en = 0; train = 0;
        #10; rst_overall = 0;
        $display("[INFO] Reset complete");

        rst_vals = 1; #10; rst_vals = 0;
        $display("[INFO] Value reset done");
        train = 1;
        // === Layer 0 Weights ===
        train_layer_select = 0;
        bias_updates = 0;

        row_sel = 0;
        weight_update = {
            8'b00001100, // 3.0
            8'b00001000, // 2.0
            8'b00000100  // 1.0
        };
        #10;
        $display("[INFO] Weights for Layer 0 Row 0: [1.0 2.0 3.0]");

        row_sel = 1;
        weight_update = {
            8'b00011000, // 6.0
            8'b00010100, // 5.0
            8'b00010000  // 4.0
        };
        #10;
        $display("[INFO] Weights for Layer 0 Row 1: [4.0 5.0 6.0]");

        // === Layer 1 Weights ===
        train_layer_select = 1;
        row_sel = 0;
        weight_update = {
            8'b00001000, // 2.0
            8'b00000100  // 1.0
        };
        #10;
        $display("[INFO] Weights for Layer 1 Row 0: [1.0 2.0]");

        row_sel = 1;
        weight_update = {
            8'b00010000, // 4.0
            8'b00001100  // 3.0
        };
        #10;
        $display("[INFO] Weights for Layer 1 Row 1: [3.0 4.0]");
        $display("Wt updates = %0d", dut.gen_layers[0].layer_inst.weight_update);
        $display("Layer weights = %0d", dut.gen_layers[0].layer_inst.gen_rows[0].gen_columns[0].u_block.weight);
        $display("Layer weights = %0d", dut.gen_layers[0].layer_inst.gen_rows[0].gen_columns[1].u_block.weight);
        $display("Layer weights = %0d", dut.gen_layers[0].layer_inst.gen_rows[0].gen_columns[2].u_block.weight);
        $display("Layer weights = %0d", dut.gen_layers[0].layer_inst.gen_rows[1].gen_columns[0].u_block.weight);
        $display("Layer weights = %0d", dut.gen_layers[0].layer_inst.gen_rows[1].gen_columns[1].u_block.weight);
        $display("Layer weights = %0d", dut.gen_layers[0].layer_inst.gen_rows[1].gen_columns[2].u_block.weight);
        weight_update = 0;
        train = 0;

        // === Input Vector [1.0 2.0 3.0] ===
        input_values = {
            8'b00001100, // 3.0
            8'b00001000, // 2.0
            8'b00000100  // 1.0
        };
        $display("[INFO] Input Vector: [1.0 2.0 3.0]");

        // === Start execution ===
        en = 1;
        input_loaded = 1;
        #10;
        en = 0;
        input_loaded = 0;
        // === Wait for Layer 0 ===
        wait (dut.layer_done[0]);
        #10;
        $display("Ip updates = %0d", dut.gen_layers[0].layer_inst.gen_rows[0].gen_columns[0].u_block.value);
        $display("Ip updates = %0d", dut.gen_layers[0].layer_inst.gen_rows[0].gen_columns[1].u_block.value);
        $display("Ip updates = %0d", dut.gen_layers[0].layer_inst.gen_rows[0].gen_columns[2].u_block.value);
        $display("Ip updates = %0d", dut.gen_layers[0].layer_inst.gen_rows[1].gen_columns[0].u_block.value);
        $display("Ip updates = %0d", dut.gen_layers[0].layer_inst.gen_rows[1].gen_columns[1].u_block.value);
        $display("Ip updates = %0d", dut.gen_layers[0].layer_inst.gen_rows[0].gen_columns[2].u_block.value);
        $display("Layer weights = %0d", dut.gen_layers[0].layer_inst.gen_rows[0].gen_columns[0].u_block.weight);
        $display("Layer weights = %0d", dut.gen_layers[0].layer_inst.gen_rows[0].gen_columns[1].u_block.weight);
        $display("Layer weights = %0d", dut.gen_layers[0].layer_inst.gen_rows[0].gen_columns[2].u_block.weight);
        $display("Layer weights = %0d", dut.gen_layers[0].layer_inst.gen_rows[1].gen_columns[0].u_block.weight);
        $display("Layer weights = %0d", dut.gen_layers[0].layer_inst.gen_rows[1].gen_columns[1].u_block.weight);
        $display("Layer weights = %0d", dut.gen_layers[0].layer_inst.gen_rows[1].gen_columns[2].u_block.weight);
        $display("Ip updates = %0d", dut.gen_layers[0].layer_inst.gen_rows[0].gen_columns[0].u_block.outp_east);
        $display("Ip updates = %0d", dut.gen_layers[0].layer_inst.gen_rows[0].gen_columns[1].u_block.outp_east);
        $display("Ip updates = %0d", dut.gen_layers[0].layer_inst.gen_rows[0].gen_columns[2].u_block.outp_east);
        $display("Ip updates = %0d", dut.gen_layers[0].layer_inst.gen_rows[1].gen_columns[0].u_block.outp_east);
        $display("Ip updates = %0d", dut.gen_layers[0].layer_inst.gen_rows[1].gen_columns[1].u_block.outp_east);
        $display("Ip updates = %0d", dut.gen_layers[0].layer_inst.gen_rows[1].gen_columns[2].u_block.outp_east);
        assign pre_row0 = dut.layer_out_pre[0][(4*datawidth)-1 -: 2*datawidth];
        assign pre_row1 = dut.layer_out_pre[0][(2*datawidth)-1 -: 2*datawidth];
        assign trunc_row0 = dut.layer_out_trunc[0][(2*datawidth)-1 -: datawidth];
        assign trunc_row1 = dut.layer_out_trunc[0][(1*datawidth)-1 -: datawidth];
        assign relu_0 = dut.gen_layers[0].relu_case.relu_inst.in[2*datawidth-1:0];
        assign act_row0 = dut.layer_out_act[0][2*datawidth-1:0];
        assign out_0 = dut.gen_layers[0].relu_case.relu_inst.out[2*datawidth-1:0];
        $display("\n[DEBUG] Layer 0 Output:");
        $display("Expected Row 0 = 1*1 + 2*2 + 3*3 = 14");
        $display("Expected Row 1 = 1*4 + 2*5 + 3*6 = 32");
        $display("Actual Pre-Activation Row 0 = %0d", pre_row0);
        $display("Actual Pre-Activation Row 1 = %0d", pre_row1);
        $display("Actual Trunc-Activation Row 0 = %0d", trunc_row0);
        $display("Actual Trunc-Activation Row 1 = %0d", trunc_row1);
        $display("Actual Pre-ReLU      = %0d", relu_0);
        $display("Actual Out-ReLU      = %0d", out_0);
        $display("Actual Post-ReLU Row 0      = %0d", act_row0);
        $display ("Layer done 0 = %d", dut.layer_done[0]);
        $display ("Act done 0 = %d", dut.done[0]);


        // === Wait for Layer 1 ===
        wait (dut.layer_done[1]);
        #10;
        assign pre1_row0 = dut.layer_out_pre[1][(4*datawidth)-1 -: 2*datawidth];
        assign pre1_row1 = dut.layer_out_pre[1][(2*datawidth)-1 -: 2*datawidth];
        assign act1_row0 = dut.layer_out_act[1][(2*datawidth)-1 -: datawidth];
        assign act1_row1 = dut.layer_out_act[1][(1*datawidth)-1 -: datawidth];

        $display("\n[DEBUG] Layer 1 Output:");
        $display("Expected Row 0 = 14*1 + 32*2 = 78");
        $display("Expected Row 1 = 14*3 + 32*4 = 182");
        
        $display("Input 1 = %0d", dut.layer_input[1]);
        
        $display("Ip updates = %0d", dut.gen_layers[1].layer_inst.gen_rows[0].gen_columns[0].u_block.value);
        $display("Ip updates = %0d", dut.gen_layers[1].layer_inst.gen_rows[0].gen_columns[1].u_block.value);
        $display("Ip updates = %0d", dut.gen_layers[1].layer_inst.gen_rows[1].gen_columns[0].u_block.value);
        $display("Ip updates = %0d", dut.gen_layers[1].layer_inst.gen_rows[1].gen_columns[1].u_block.value);
        $display("Layer weights = %0d", dut.gen_layers[1].layer_inst.gen_rows[0].gen_columns[0].u_block.weight);
        $display("Layer weights = %0d", dut.gen_layers[1].layer_inst.gen_rows[0].gen_columns[1].u_block.weight);
        $display("Layer weights = %0d", dut.gen_layers[1].layer_inst.gen_rows[1].gen_columns[0].u_block.weight);
        $display("Layer weights = %0d", dut.gen_layers[1].layer_inst.gen_rows[1].gen_columns[1].u_block.weight);
        $display("Acc updates = %0d", dut.gen_layers[1].layer_inst.gen_rows[0].gen_columns[0].u_block.acc);
        $display("Acc updates = %0d", dut.gen_layers[1].layer_inst.gen_rows[0].gen_columns[1].u_block.acc);
        $display("Acc updates = %0d", dut.gen_layers[1].layer_inst.gen_rows[1].gen_columns[0].u_block.acc);
        $display("Acc updates = %0d", dut.gen_layers[1].layer_inst.gen_rows[1].gen_columns[1].u_block.acc);
        $display("Outp_east updates = %0d", dut.gen_layers[1].layer_inst.gen_rows[0].gen_columns[0].u_block.outp_east);
        $display("Outp_east updates = %0d", dut.gen_layers[1].layer_inst.gen_rows[0].gen_columns[1].u_block.outp_east);
        $display("Outp_east updates = %0d", dut.gen_layers[1].layer_inst.gen_rows[1].gen_columns[0].u_block.outp_east);
        $display("Outp_east updates = %0d", dut.gen_layers[1].layer_inst.gen_rows[1].gen_columns[1].u_block.outp_east);
        $display("Actual Pre-Activation Row 0 = %0d", pre1_row0);
        $display("Actual Pre-Activation Row 1 = %0d", pre1_row1);
        $display("Actual Post-ReLU Row 0      = %0d", act1_row0);
        $display("Actual Post-ReLU Row 1      = %0d", act1_row1);
        
        

        // === Final Output ===
        wait (dut.final_done);
        $display("\n================== FINAL RESULT ==================");
        $display("Final Output: %b", dut.final_out_array[0]);
        $display ("Act done 1 = %d", dut.done[1]);
        $display("Final Output: %b", dut.final_out_array[1]);
        $display("Final Output One-Hot: %b", dut.final_out);
        $display("Current layer: %b", dut.curr_layer);
        $display("Current FSM state: %b", dut.fsm_state);
        $display("Final Done: %b", dut.final_done);
        if (dut.one_hot_prediction == 2'b10)
            $display("[PASS] Correct prediction: Index 1 selected.");
        else
            $display("[FAIL] Incorrect prediction. Expected index 1.");
            
            $display ("Layer done latched = %b, Done = %b", dut.layer_done_latched[0], dut.done[0]);
            
            $display ("Layer done latched = %b, Done = %b", dut.layer_done_latched[1], dut.done[1]);

            #10;
            $display ("Layer done latched = %b, Done = %b", dut.layer_done_latched[0], dut.done[0]);
            
        $display("Final Output One-Hot: %b", dut.final_out);
            $display ("Layer done latched = %b, Done = %b", dut.layer_done_latched[1], dut.done[1]);
            
        $display("Final Done: %b", dut.final_done);
            #10;
            $display ("Layer done latched = %b, Done = %b", dut.layer_done_latched[0], dut.done[0]);
            
            $display ("Layer done latched = %b, Done = %b", dut.layer_done_latched[1], dut.done[1]);
            
        $display("Final Done: %b", dut.final_done);
            
        $display("Current FSM state: %b", dut.fsm_state);
        #10;
            $display ("Layer done latched = %b, Done = %b", dut.layer_done_latched[0], dut.done[0]);
            
            $display ("Layer done latched = %b, Done = %b", dut.layer_done_latched[1], dut.done[1]);
            
        $display("Final Done: %b", dut.final_done);
            
        $display("Current FSM state: %b", dut.fsm_state);
        #10;
            $display ("Layer done latched = %b, Done = %b", dut.layer_done_latched[0], dut.done[0]);
            
            $display ("Layer done latched = %b, Done = %b", dut.layer_done_latched[1], dut.done[1]);
            
        $display("Final Done: %b", dut.final_done);
            
        $display("Current FSM state: %b", dut.fsm_state);
        $display("==================================================");

        $finish;
    end

endmodule
