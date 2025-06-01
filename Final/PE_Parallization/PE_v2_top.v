`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/14/2025 11:31:18 PM
// Design Name: 
// Module Name: PE_v2_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module PE_v2_top #(
    parameter KERNEL_SIZE                   = 3,
              INPUT_TILE_SIZE               = 4,
              INPUT_TRANSFORMED_DATA_WIDTH  = 8,
              KERNEL_DATA_WIDTH             = 8,
              CHANNELS                      = 4,
              Pm                            = 4,
              Pn                            = 2
)(
    input clk,
    input reset,
    input newInp,
    
    // Kernel Loading
    input signed [(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * Pm * Pn) - 1 : 0] Kernel,
    
    // Input Tile
    input signed [(INPUT_TILE_SIZE * INPUT_TILE_SIZE * INPUT_TRANSFORMED_DATA_WIDTH * Pm * Pn) - 1 : 0] inpData,
    
    // Output
    output reg signed [((INPUT_TILE_SIZE - KERNEL_SIZE + 1) * (INPUT_TILE_SIZE - KERNEL_SIZE + 1) * (KERNEL_DATA_WIDTH + INPUT_TRANSFORMED_DATA_WIDTH + 13) * Pn) - 1 : 0] outData,
    output reg [Pn - 1 : 0] o_valid
);

    // Internal Constants
    localparam FLATTENED_IMAGE_LENGTH = INPUT_TILE_SIZE * INPUT_TILE_SIZE * INPUT_TRANSFORMED_DATA_WIDTH;
    localparam FLATTENED_KERNEL_LENGTH = KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH;
    localparam KERNEL_TRANSFORMED_WIDTH = KERNEL_DATA_WIDTH + 2;
    localparam KERNEL_TRANSFORMATION_WIDTH_FINAL = KERNEL_TRANSFORMED_WIDTH + 2;
    localparam EWMM_WIDTH = KERNEL_TRANSFORMATION_WIDTH_FINAL + INPUT_TRANSFORMED_DATA_WIDTH;
    localparam OUTPUT_REG_WIDTH = EWMM_WIDTH + 2;
    localparam OUTPUT_REG_WIDTH_1 = OUTPUT_REG_WIDTH + 2;
    localparam OUTPUT_FINAL_WIDTH = OUTPUT_REG_WIDTH_1 + 1;
    localparam PE_OUTPUT_WIDTH = OUTPUT_FINAL_WIDTH;
    localparam ACC_OUT_WIDTH = PE_OUTPUT_WIDTH + Pm;

    // Internal Registers
    reg signed [(FLATTENED_IMAGE_LENGTH - 1) : 0] inpDataFlattened [Pn - 1 : 0][Pm - 1 : 0];
    reg signed [(FLATTENED_KERNEL_LENGTH - 1) : 0] kernelDataFlattened [Pn - 1 : 0][Pm - 1 : 0];
    wire signed [(PE_OUTPUT_WIDTH - 1) : 0] pe_outs [Pn - 1 : 0][Pm - 1 : 0];
    reg signed [(ACC_OUT_WIDTH - 1) : 0] accumulated_out [Pn - 1 : 0];
    reg signed [(ACC_OUT_WIDTH - 1) : 0] temp_sum;

    integer i, j;

    // Unpack inpData
    always @(posedge clk) begin
        if (reset || newInp) begin
            for (i = 0; i < Pn; i = i + 1)
                for (j = 0; j < Pm; j = j + 1)
                    inpDataFlattened[i][j] <= 0;
        end else begin
            for (i = 0; i < Pn; i = i + 1)
                for (j = 0; j < Pm; j = j + 1)
                    inpDataFlattened[i][j] <= inpData[((i * Pm * FLATTENED_IMAGE_LENGTH) + (j * FLATTENED_IMAGE_LENGTH)) +: FLATTENED_IMAGE_LENGTH];
        end
    end

    // Unpack kernelData
    always @(posedge clk) begin
        if (reset || newInp) begin
            for (i = 0; i < Pn; i = i + 1)
                for (j = 0; j < Pm; j = j + 1)
                    kernelDataFlattened[i][j] <= 0;
        end else begin
            for (i = 0; i < Pn; i = i + 1)
                for (j = 0; j < Pm; j = j + 1)
                    kernelDataFlattened[i][j] <= Kernel[((i * Pm * FLATTENED_KERNEL_LENGTH) + (j * FLATTENED_KERNEL_LENGTH)) +: FLATTENED_KERNEL_LENGTH];
        end
    end

    // Accumulation logic
    always @(posedge clk) begin
        if (reset || newInp) begin
            for (i = 0; i < Pn; i = i + 1)
                accumulated_out[i] <= 0;
        end else begin
            for (i = 0; i < Pn; i = i + 1) begin
                temp_sum = 0;
                for (j = 0; j < Pm; j = j + 1)
                    temp_sum = temp_sum + pe_outs[i][j];
                accumulated_out[i] <= temp_sum;
            end
        end
    end

    // Instantiate PEs
    genvar gv_i, gv_j;
    generate
        for (gv_i = 0; gv_i < Pn; gv_i = gv_i + 1) begin : OUT_CH_LOOP
            for (gv_j = 0; gv_j < Pm; gv_j = gv_j + 1) begin : IN_CH_LOOP
                PE_v2 pe_inst (
                    .clk(clk),
                    .reset(reset),
                    .Kernel(kernelDataFlattened[gv_i][gv_j]),
                    .inpData(inpDataFlattened[gv_i][gv_j]),
                    .outData(pe_outs[gv_i][gv_j])
                );
            end
        end
    endgenerate

    // Output logic (you may expand this based on actual layout)
    always @(posedge clk) begin
        if (reset) begin
            outData <= 0;
            o_valid <= 0;
        end else begin
            for (i = 0; i < Pn; i = i + 1) begin
                outData[i * ACC_OUT_WIDTH +: ACC_OUT_WIDTH] <= accumulated_out[i];
                o_valid[i] <= 1;
            end
        end
    end

endmodule
