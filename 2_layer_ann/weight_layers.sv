`timescale 1ns/1ps

module weight_layers #(
    parameter layers = 2,
    parameter datawidth = 11,
    parameter int_part_input = 5,
    parameter int_part_weight = 5, 
    parameter integer rows[0:layers-1] = '{30, 10},
    parameter max_rows = 30,
    parameter integer cols[0:layers-1] = '{64, 30},
    parameter max_cols = 64,
    parameter integer activation[0:layers-1] = '{0, 1},
    parameter lut_width = 22 // for softmax
)(
    input wire clk,
    input wire rst_vals,
    input wire rst_overall,
    input wire en,
    input wire train,
    input wire [$clog2(layers)-1:0] train_layer_select,
    input wire [$clog2(max_rows)-1:0] row_sel,
    input wire signed [cols[0]*datawidth-1:0] input_values,
    input wire signed [max_cols*datawidth-1:0] weight_update,
    input wire signed [max_rows*2*datawidth-1:0] bias_updates,
    output logic [rows[layers-1]-1:0] final_out,
    output logic final_done,
    input logic input_loaded
);

    genvar i, j;
    wire signed [max_rows*2*datawidth-1:0] layer_out_pre [0:layers-1];
    wire signed [max_rows*datawidth-1:0] layer_out_trunc [0:layers-1];
    wire signed [max_rows*datawidth-1:0] layer_out_act [0:layers-1];
    wire signed [max_cols*datawidth-1:0] layer_input [0:layers-1];
    wire [layers-1:0] layer_done;
    reg [layers-1:0] layer_done_latched;
    reg [layers-1:0] layer_en;
    logic [layers-1:0] done;
    logic [layers-1:0] done_latched;
    logic complete;
    reg [layers-1:0] trunc_done_latched;
    wire [layers-1:0] trunc_done;
    
    reg [rows[layers-1]-1:0] one_hot_prediction;
    reg signed [datawidth-1:0] max_val;
    reg [$clog2(rows[layers-1])-1:0] max_index;
    reg [max_rows-1:0] m;
    
    
   integer d,h,g;
    always_ff @(posedge clk or posedge rst_overall or posedge rst_vals) begin
   if (rst_overall || rst_vals) begin
   layer_done_latched <= '0;
   trunc_done_latched <= '0;
   done_latched <= '0;
   end
   // else if (final_done) begin
   // for (int e = 0; e<layers; e=e+1) begin
   //            layer_done_latched[e] <= 0;
   //            done[e] <= 0;
   //         end
    //        end
                        
    else begin
   for (int d=0; d<layers; d=d+1) begin
    if (layer_done[d])
   layer_done_latched[d] <= 1;
    end
    for (int h=0; h<layers; h=h+1) begin
        if (trunc_done[h])
       trunc_done_latched[h] <= 1;
        end
        for (int g=0; g<layers; g=g+1) begin
                if (done[g])
               done_latched[g] <= 1;
                end
    end
    end
    
   // reg act_rst;
    
   // always @(posedge clk or posedge rst_overall or posedge rst_vals) begin
   // if (rst_overall || rst_vals)
   // act_rst <= 0;
   // else if (final_done)
   // act_rst <= 1;
  //  else
    //act_rst <= 0;
  //  end
    
  //  integer d;
  //  always_comb begin
  //  if (act_rst == 1) begin
  //  for (d=0; d<layers; d=d+1) begin
  //  act_done[d] = 0;
  //  end
   // end
   // end
    
    typedef enum logic {
    IDLE  = 1'd0,
    ACTIVE = 1'd1
    } fsm_state_t;

    fsm_state_t fsm_state;
    integer curr_layer;

    integer l;
    always_ff @(posedge clk or posedge rst_overall or posedge rst_vals) begin
    if (rst_overall || rst_vals) begin
        layer_en <= '0;
        curr_layer <= 0;
        fsm_state <= IDLE;
    end else begin
        case (fsm_state)
            IDLE: begin
            layer_done_latched <= '0;
            trunc_done_latched <= '0;
            done_latched <= '0;
            curr_layer <= 0;
            complete <= 0;
                max_val <= '0;
                max_index <= '0;
                m <= '0;
                if (en && input_loaded) begin
                    layer_en[0] <= 1;
                    one_hot_prediction <= '0;
                    fsm_state <= ACTIVE;
                end
            end

            ACTIVE: begin
                if (done_latched[curr_layer]) begin
                    layer_en[curr_layer] <= 0;
                    curr_layer <= curr_layer + 1;
                    if (curr_layer + 1 < layers) begin
                        layer_en[curr_layer + 1] <= 1;
                    end
                end
                else if (complete) begin
                done <= '0;
                layer_en <= '0;
                layer_done_latched <= '0;
                trunc_done_latched <= '0;
                done_latched <= '0;
                complete <= 0;
                fsm_state <= IDLE;
                end
                else curr_layer <= curr_layer;
            end
        endcase
    end
end

    assign layer_input[0] = input_values;

    genvar x;
    generate
        for (x = 1; x < layers; x = x + 1) begin : assign_inputs
            assign layer_input[x] = layer_out_act[x-1];
        end
    endgenerate

    generate
        for (i = 0; i < layers; i = i + 1) begin : gen_layers
            
            // Instantiate layer
            layer #(
                .layer_no(i),
                .rows(rows[i]),
                .columns(cols[i]),
                .max_rows(max_rows),
                .max_columns(max_cols),
                .datawidth(datawidth)
            ) layer_inst (
                .values(layer_input[i][(cols[i]*datawidth)-1:0]),
                .row_sel(row_sel),
                .weight_update(weight_update),
                .bias_updates(bias_updates),
                .clk(clk),
                .rst_vals(rst_vals),
                .rst_overall(rst_overall),
                .en(layer_en[i]),
                .train_en(train_layer_select == i && train),
                .out(layer_out_pre[i][(rows[i]*2*datawidth)-1:0]),
                .done(layer_done[i])
            );

            // Truncation logic
             truncation #(.layers(layers),
             .row(rows[i]), 
             .datawidth(datawidth),
             .int_part_input(int_part_input),
             .int_part_weight(int_part_weight), 
             .max_rows(max_rows)) 
             trunc_inst (.clk(clk),
             .rst_vals(rst_vals),
             .rst_overall(rst_overall),
             .layer_done(layer_done_latched[i]),
             .layer_out_pre(layer_out_pre[i][(rows[i]*2*datawidth)-1:0]),
             .layer_out_trunc(layer_out_trunc[i][(rows[i]*datawidth)-1:0]),
             .trunc_done(trunc_done[i]));

            // Activation block instantiation
            if (activation[i] == 0) begin : relu_case
                relu_block #(
                    .datawidth(datawidth),
                    .rows(rows[i])
                ) relu_inst (
                    .clk(clk),
                    .rst_vals(rst_vals),
                    .rst_overall(rst_overall),
                    .layer_done(trunc_done_latched[i]),
                    .in(layer_out_trunc [i] [rows[i]*datawidth-1:0]),
                    .out(layer_out_act [i] [rows[i]*datawidth-1:0]),
                    .done(done[i])
                //   .act_done(act_done[i])
                );
            end else if (activation[i] == 1) begin : softmax_case
                softmax_block #(
                    .datawidth(datawidth),
                    .rows(rows[i]),
                    .lut_width(lut_width)
                ) softmax_inst (
                    .in(layer_out_trunc[i][rows[i]*datawidth-1:0]),
                    .out(layer_out_act[i][rows[i]*datawidth-1:0])
                );
            end

        end
    endgenerate

    // Output one-hot logic
    wire signed [datawidth-1:0] final_out_array [0:rows[layers-1]-1];

    genvar k;
    generate
        for (k = 0; k < rows[layers-1]; k = k + 1) begin : unpack_final_out
            assign final_out_array[k] = layer_out_act[layers-1][(rows[layers-1]-k-1)*datawidth +: datawidth];
        end
    endgenerate

    always_ff @(posedge clk or posedge rst_vals or posedge rst_overall) begin
    if (rst_vals || rst_overall) begin
    one_hot_prediction <= '0;
    max_val <= '0;
    max_index <= '0;
    m <= '0;
    complete <= 0;
    end
    else if (done_latched[layers-1]) begin
        if (m==0) begin
        max_val <= final_out_array[0];
        max_index <= rows[layers-1] - 1;
        m <= m+1;
        end
        else if (m < rows[layers - 1]) begin
            if (final_out_array[m] > max_val) begin
                max_val <= final_out_array[m];
                max_index <= rows[layers-1] - m - 1;
            end
            else begin
            max_index <= max_index;
            max_val <= max_val;
            end
            m <= m+1;
            end
        else if (m == rows[layers-1]) begin
            complete <= 1;
            one_hot_prediction[max_index] <= 1'b1;
            m <= m+1;
            end
       end
end

assign final_done = (complete == 1);
assign final_out = one_hot_prediction;

//always @(posedge clk or posedge rst_overall or posedge rst_vals) begin
  //  if (rst_overall||rst_vals)
    //    final_out <= 0;
   // else if (final_done)
     //   final_out <= one_hot_prediction;
//end

endmodule

