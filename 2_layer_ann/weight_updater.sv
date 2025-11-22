`timescale 1ns/ 1ps

module weight_updater #(
    parameter layers=3, 
    parameter datawidth = 11, 
    parameter int_part_input = 5, 
    parameter int_part_weight = 5,
    parameter integer rows[0:layers-1] = '{30, 10, 2}, 
    parameter integer max_rows = 30,
    parameter integer cols[0:layers-1] = '{64, 30, 5}, 
    parameter integer max_cols = 64,
    parameter integer activation [0:layers-1] = '{0, 0, 1})(
    input wire clk,
    input wire rst_overall,
    input wire rst_vals,
    input wire pretrained,
    output reg [$clog2(layers)-1:0] layer_select,
    output reg [$clog2(max_rows)-1:0] row_select,
    output reg signed [max_cols*datawidth-1:0] weight_update,
    output reg signed [max_rows*2*datawidth-1:0] bias_updates,
    output reg upload_done,
    output reg train );

reg signed [datawidth*cols[0]-1:0] weight_mem_0 [0:rows[0]-1];
reg signed [datawidth*cols[1]-1:0] weight_mem_1 [0:rows[1]-1];
//reg signed [datawidth*cols[2]-1:0] weight_mem_2 [0:rows[2]-1];

reg signed [2*datawidth*rows[0]-1:0] bias_mem_0;
reg signed [2*datawidth*rows[1]-1:0] bias_mem_1;
//reg signed [2*datawidth*rows[2]-1:0] bias_mem_2;

reg signed [2*datawidth-1:0] bias_temp_mem_0 [0:rows[0]-1];
reg signed [2*datawidth-1:0] bias_temp_mem_1 [0:rows[1]-1];
//reg signed [2*datawidth-1:0] bias_temp_mem_2 [0:rows[2]-1];
integer i;
initial begin
    $readmemb("layer1_biases.mem", bias_temp_mem_0);
    for (int i = 0; i < rows[0]; i = i + 1) begin
        bias_mem_0[(rows[0]-i-1)*2*datawidth +: 2*datawidth] = bias_temp_mem_0[i];
    end
end
initial begin
    $readmemb("layer2_biases.mem", bias_temp_mem_1);
    for (int i = 0; i < rows[1]; i = i + 1) begin
        bias_mem_1[(rows[1]-i-1)*2*datawidth +: 2*datawidth] = bias_temp_mem_1[i];
    end
end
//initial begin
 //   $readmemb("layer3_biases.mem", bias_temp_mem_2);
 ///   for (int i = 0; i < rows[2]; i = i + 1) begin
  //      bias_mem_2[(rows[2]-i-1)*2*datawidth +: 2*datawidth] = bias_temp_mem_2[i];
 //   end
//end

initial begin
    $readmemb("layer1_weights.mem", weight_mem_0);
    $readmemb("layer2_weights.mem", weight_mem_1);
   // $readmemb("layer3_weights.mem", weight_mem_2);
end

    typedef enum logic [1:0] {IDLE, LOAD_LAYER, DONE} state_t;
    state_t state, next_state;

    reg pretrained_latched;
    reg [$clog2(layers)-1:0] layer_count;
    reg [$clog2(max_rows)-1:0] row_count;

    always @(posedge clk or posedge rst_overall or posedge rst_vals) begin
        if (rst_overall || rst_vals) begin
            pretrained_latched <= 0;
        end else if (pretrained) begin
            pretrained_latched <= 1;
        end else if (state == DONE) begin
            pretrained_latched <= 0;
        end
    end

    always @(posedge clk or posedge rst_overall or posedge rst_vals) begin
        if (rst_overall || rst_vals) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (pretrained_latched) next_state = LOAD_LAYER;
            LOAD_LAYER: if (layer_count == layers-1 && row_count == rows[layer_count]) next_state = DONE;
            DONE: next_state = IDLE;
        endcase
    end


always @(posedge clk or posedge rst_overall or posedge rst_vals) begin
    if (rst_overall|| rst_vals) begin
        layer_count <= 0;
        row_count <= 0;
        upload_done <= 0;
        weight_update <= 0;
        bias_updates <= 0;
        layer_select <= 0;
        row_select <= 0;
        train <= 0;
    end else begin
        case (state)
                LOAD_LAYER: begin
                    train <= 1;
                    case (layer_count)
                        0: begin
                            bias_updates <= bias_mem_0;
                            if (row_count < rows[0]) begin
                                weight_update <= {{(max_cols-cols[0])*datawidth{1'b0}}, weight_mem_0[row_count]};
                                row_select <= row_count;
                                layer_select <= layer_count;
                                row_count <= row_count + 1;
                            end else begin
                                row_count <= 0;
                                layer_count <= layer_count + 1;
                            end
                        end
                  //      1: begin
                  //                                  bias_updates <= bias_mem_1;
                 //                                   if (row_count < rows[1]) begin
                 //                                       weight_update <= {{(max_cols-cols[1])*datawidth{1'b0}}, weight_mem_1[row_count]};
                 //                                       row_select <= row_count;
                  //                                      layer_select <= layer_count;
                 //                                       row_count <= row_count + 1;
                 //                                   end else begin
                 //                                       row_count <= 0;
                  //                                      layer_count <= layer_count + 1;
                //                                    end
                //                                end
                        1: begin
                            bias_updates <= bias_mem_1;
                            if (row_count < rows[1]) begin
                                weight_update <= {{(max_cols-cols[1])*datawidth{1'b0}}, weight_mem_1[row_count]};
                                row_select <= row_count;
                                layer_select <= layer_count;
                                row_count <= row_count + 1;
                            end else begin
                                row_count <= 0;
                                layer_count <= 0;
                                train <= 0;
                            end
                        end
                    endcase
                    upload_done <= 0;
                end
                DONE: begin
                    upload_done <= 1;
                    train <= 0;
                end
                default: begin
                    weight_update <= 0;
                    bias_updates <= 0;
                    row_select <= 0;
                    layer_select <= 0;
                    upload_done <= 0;
                    train <= 0;
                end
            endcase
        end
    end

endmodule