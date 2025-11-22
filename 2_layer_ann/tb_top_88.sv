`timescale 1ns / 1ps

module tb_top;

    // Parameters
    localparam layers = 2;
    localparam datawidth = 16;
    localparam int_part_input = 8;
    localparam int_part_weight = 8;
    localparam rows0 = 50, rows1 = 10;
    localparam cols0 = 64, cols1 = 50;
    localparam max_rows = 50;
    localparam max_cols = 64;
    localparam max_inputs = 200;
    localparam lut_width = 22;
    

    // Signals
    logic clk;
    logic rst_vals, rst_overall, pretrained, enable_inference;
    logic [rows1-1:0] expected_output, obtained_output;
    logic [8:0] accuracy;

    // For accessing DUT internals
    logic [2*datawidth-1:0] single_bias;
    int i;

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Instantiate DUT
    top #(layers, datawidth, int_part_input, int_part_weight,
          '{rows0, rows1}, max_rows,
          '{cols0, cols1}, max_cols,
          '{0, 0}, lut_width, max_inputs)
    dut (
        .clk(clk),
        .rst_vals(rst_vals),
        .rst_overall(rst_overall),
        .pretrained(pretrained),
        .enable_inference(enable_inference),
        .expected_output(expected_output),
        .obtained_output(obtained_output),
        .accuracy(accuracy)
    );

    // Test sequence
  always @(posedge clk) begin
            wait (dut.input_loaded)
             $display ("Input Loaded, Input = %b", dut.inference_weights.input_values);
             $display ("Verify Layer 0 Input = %b", dut.inference_weights.gen_layers[0].layer_inst.values);
             wait (dut.inference_weights.layer_done_latched[0]);
             $display ("Layer Internal Output = %b", dut.inference_weights.gen_layers[0].layer_inst.outp_east_all);
             $display ("Layer Internal Output = %b", dut.inference_weights.gen_layers[0].layer_inst.outputs);
             $display ("Layer done = %b, Done = %b, Layer Out = %b, Trunc In = %b", dut.inference_weights.layer_done_latched, dut.inference_weights.done, dut.inference_weights.gen_layers[0].layer_inst.out, dut.inference_weights.gen_layers[0].trunc_inst.layer_out_pre);
            wait (dut.inference_weights.trunc_done_latched[0]);
                          $display ("Trunc done = %b, Done = %b, Trunc Out = %b, RELU In = %b", dut.inference_weights.trunc_done_latched, dut.inference_weights.done, dut.inference_weights.gen_layers[0].trunc_inst.layer_out_trunc, dut.inference_weights.gen_layers[0].relu_case.relu_inst.in);
                          wait (dut.inference_weights.done[0]);
             #30;
             $display ("Layer done = %b, Done = %b, Curr Layer = %b, Layer 1 enable = %b, Layer 1 enabled (en) = %b, RELU Out = %b, Layer In = %b", dut.inference_weights.layer_done_latched, dut.inference_weights.done, dut.inference_weights.curr_layer, dut.inference_weights.layer_en[1], dut.inference_weights.gen_layers[1].layer_inst.en, dut.inference_weights.gen_layers[0].relu_case.relu_inst.out, dut.inference_weights.gen_layers[1].layer_inst.values);
             wait (dut.inference_weights.layer_done_latched[1]);
             $display ("Layer done = %b, Done = %b, Layer Out = %b, Trunc In = %b", dut.inference_weights.layer_done_latched, dut.inference_weights.done, dut.inference_weights.gen_layers[1].layer_inst.out, dut.inference_weights.gen_layers[1].trunc_inst.layer_out_pre);
            wait (dut.inference_weights.trunc_done_latched[1]);
                         $display ("Trunc done = %b, Done = %b, Trunc Out = %b, RELU In = %b", dut.inference_weights.trunc_done_latched, dut.inference_weights.done, dut.inference_weights.gen_layers[1].trunc_inst.layer_out_trunc, dut.inference_weights.gen_layers[1].relu_case.relu_inst.in);
                         wait (dut.inference_weights.done[1]);
             #30;
             $display ("Layer done = %b, Done = %b, Out = %b", dut.inference_weights.layer_done_latched, dut.inference_weights.done, dut.inference_weights.gen_layers[1].relu_case.relu_inst.out);
             wait (dut.inference_weights.complete);
             $display ("Layer done = %b, Done = %b", dut.inference_weights.layer_done_latched, dut.inference_weights.done);
                            end
    initial begin
        $display("============================================================");
        $display("[TB] Starting Testbench...");

        // Initial states
        clk = 0;
        rst_overall = 1;
        rst_vals = 0;
        pretrained = 0;
        enable_inference = 0;

        #20;
        rst_overall = 0;
        $display("[TB] Deasserted rst_overall");

        #20;
        rst_vals = 1;
        #20;
        rst_vals = 0;
        $display("[TB] Pulsed rst_vals");

        // Send pretrained pulse
        #10;
        pretrained = 1;
        $display("[TB] Pretrained pulse sent");
        #10;
        pretrained = 0;
        enable_inference = 1;
        
        
        // Wait for upload_done
        wait (dut.upload_done == 1);
        $display("[TB] Upload done signal received!");
        $display("Label = %0d", dut.input_loader.label);

        // Print some weights and biases for debug
      //  $display("------------------------------------------------------------");
     // //  $display("[TB] Layer Select = %0d | Row Select = %0d", dut.layer_select, dut.row_sel);
     //   $display("[TB] Weight Update : %b", dut.weight_update);
     //   $display("[TB] Bias Updates  : %b", dut.bias_updates_wire);

    //    for (i = 0; i < 5; i++) begin
    //        single_bias = dut.bias_updates_wire[(rows1-i-1)*2*datawidth +: 2*datawidth];
     //       $display("[TB] Bias[%0d] = %b", i, single_bias);
     //   end
     //   $display("------------------------------------------------------------");

        // Enable inference
        $display("[TB] Inference enabled");
     //   #30;
     //   enable_inference = 0;
        
        // Monitor results
        
    end
    
  //  logic [rows1-1:0] expected_pipe [0:layers-1];
  //  logic [rows1-1:0] aligned_expected;
    
   // always_ff @(posedge clk) begin
  //      expected_pipe[0] <= expected_output;
  //     for (int i = 1; i < layers - 1; i++) begin
 //           expected_pipe[i] <= expected_pipe[i-1];
//        end
 //       aligned_expected <= expected_pipe[layers-1];
//    end

    
   always @(posedge clk) begin
                if (dut.begin_next) begin
                if (dut.count < max_inputs) begin
                   $display("  Expected: %b", expected_output);
                    $display("  Obtained: %b", dut.obtained_output);
                    $display("  Accuracy: %0d%%", accuracy);
                    $display("  Input_label: %b", dut.input_loader.label);
                   $display("------------------------------------------------------------");
                end
                else if (dut.count == max_inputs)
                $finish;
                end
            end

endmodule
