`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/14/2025 06:14:04 PM
// Design Name: 
// Module Name: PE_v2
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


module PE_v2 #(
    parameter KERNEL_SIZE                   = 3,
              INPUT_TILE_SIZE               = 4,
              INPUT_TRANSFORMED_DATA_WIDTH  = 8,
              KERNEL_DATA_WIDTH             = 8
)(
    // Global Signals
    input clk,
    input reset,
    
    // Kernel Loading
    input signed [(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH) - 1 : 0] Kernel,
    
    // Output Loading
    input signed [(INPUT_TILE_SIZE * INPUT_TILE_SIZE * INPUT_TRANSFORMED_DATA_WIDTH ) - 1 : 0] inpData,
    output reg signed[(INPUT_TILE_SIZE - KERNEL_SIZE + 1) * (INPUT_TILE_SIZE - KERNEL_SIZE + 1) * (KERNEL_DATA_WIDTH + INPUT_TRANSFORMED_DATA_WIDTH + 13) - 1 : 0] outData

    );
    
    localparam KERNEL_TRANSFORMED_WIDTH = KERNEL_DATA_WIDTH + 2; // Complete Kernel Transformation requires 4 additions
    localparam KERNEL_TRANSFORMATION_WIDTH_FINAL = KERNEL_TRANSFORMED_WIDTH + 2;
    localparam EWMM_WIDTH = KERNEL_TRANSFORMATION_WIDTH_FINAL + INPUT_TRANSFORMED_DATA_WIDTH;
    localparam OUTPUT_REG_WIDTH = EWMM_WIDTH + 2;
    localparam OUTPUT_REG_WIDTH_1 = OUTPUT_REG_WIDTH + 2;
    localparam OUTPUT_FINAL_WIDTH = (OUTPUT_REG_WIDTH_1 + 1'b1);
    
    // Defining the registers
    reg signed [KERNEL_DATA_WIDTH - 1 : 0] kernel_reg [KERNEL_SIZE - 1 : 0] [KERNEL_SIZE - 1 : 0];
    reg signed [INPUT_TRANSFORMED_DATA_WIDTH - 1 : 0] input_transformed_reg [INPUT_TRANSFORMED_DATA_WIDTH - 1 : 0] [INPUT_TILE_SIZE - 1 : 0];
    
    // These two registers are used for transforming the Kernel
    reg signed [KERNEL_TRANSFORMED_WIDTH - 1 : 0] kernel_temp_reg [INPUT_TILE_SIZE - 1 : 0] [KERNEL_SIZE - 1 : 0];
    reg signed [KERNEL_TRANSFORMATION_WIDTH_FINAL - 1 : 0] kernel_transformed_reg [INPUT_TILE_SIZE - 1 : 0] [INPUT_TILE_SIZE - 1 : 0];
    
    reg signed [EWMM_WIDTH -1 : 0] ewmm_reg [INPUT_TILE_SIZE - 1 : 0] [INPUT_TILE_SIZE - 1 : 0]; // Element-Wise Matrix Multiplication

    // These two registers are used for transforming the output
    reg signed [OUTPUT_REG_WIDTH - 1 : 0] output_reg1 [INPUT_TILE_SIZE - KERNEL_SIZE : 0] [INPUT_TILE_SIZE - 1 : 0];
    reg signed [OUTPUT_REG_WIDTH_1 - 1 : 0] output_reg2 [INPUT_TILE_SIZE - KERNEL_SIZE : 0] [INPUT_TILE_SIZE - KERNEL_SIZE : 0];
    
    // This register stores the final output after the accumulation step
    reg signed [OUTPUT_FINAL_WIDTH - 1 : 0] output_final_reg [INPUT_TILE_SIZE - KERNEL_SIZE : 0] [INPUT_TILE_SIZE - KERNEL_SIZE : 0];
    reg signed [OUTPUT_FINAL_WIDTH - 1:0] temp_sum;

    
    reg LoadDone, TransStage1Done, TransStage2Done, ewmmDone, out1Done, out2Done;
 
    reg finalCompute;
    reg finalFlatten;
    
    
    integer i, j, k; // Defined as loop variables
    
    // This block loads the Kernel input data from a flattened 1D vector into a Kernel of proper size (K x K)
   always @(posedge clk)
    begin
        if(reset)
        begin
            LoadDone <= 1'b0;
            for (i = 0; i < KERNEL_SIZE; i = i + 1)
            begin
                for (j = 0; j < KERNEL_SIZE; j = j + 1)
                begin
                    kernel_reg[i][j] <= 0;
                end
            end
        end
        else
        begin
            for (i = 0; i < KERNEL_SIZE; i = i + 1)
            begin
                for (j = 0; j < KERNEL_SIZE; j = j + 1)
                begin
                    kernel_reg[i][j] <= Kernel[((i * KERNEL_SIZE + j) * KERNEL_DATA_WIDTH) +: KERNEL_DATA_WIDTH];
                end
            end
            LoadDone <= 1'b1;
        end
    end
    
     // This block loads the input data from a flattened 1D vector into a Image Transformed Matrix of proper size (N x N)
    always @(posedge clk)
    begin
        if(reset)
        begin
            for (i = 0; i < INPUT_TILE_SIZE; i = i + 1)
            begin
                for (j = 0; j < INPUT_TILE_SIZE; j = j + 1)
                begin
                    input_transformed_reg[i][j] <= 0;
                end
            end
        end
        else
        begin
            for (i = 0; i < INPUT_TILE_SIZE; i = i + 1)
            begin
                for (j = 0; j < INPUT_TILE_SIZE; j = j + 1)
                begin
                    input_transformed_reg[i][j] <= inpData[((i * INPUT_TILE_SIZE + j) * INPUT_TRANSFORMED_DATA_WIDTH) +: INPUT_TRANSFORMED_DATA_WIDTH];

                end
            end
        end
    end
    
    
    // Kernel Transformation
    always @(posedge clk)
    begin
        if (reset)
        begin
            TransStage1Done <= 1'b0;
            for(j = 0; j < KERNEL_SIZE; j = j + 1)
            begin
                for(i = 0; i < INPUT_TILE_SIZE; i = i + 1)
                begin
                    kernel_temp_reg[i][j] <= 0;
                end
            end
        end
        else
        begin
            for(j = 0; j < KERNEL_SIZE; j = j + 1)
            begin
                kernel_temp_reg[3][j] <= kernel_reg[2][j];
                kernel_temp_reg[2][j] <= (kernel_reg[2][j] + kernel_reg[1][j] + kernel_reg[0][j]) >>> 1;
                kernel_temp_reg[1][j] <= (kernel_reg[2][j] - kernel_reg[1][j] + kernel_reg[0][j]) >>> 1;
                kernel_temp_reg[0][j] <= kernel_reg[0][j];
            end
            if (LoadDone)
                TransStage1Done <= 1'b1;
        end
    end

    
    // Kernel Output Transformation
    always @(posedge clk)
    begin
        if (reset)
        begin
            TransStage2Done <= 1'b0;
            for(j = 0; j < INPUT_TILE_SIZE; j = j + 1)
            begin
                for(i = 0; i < INPUT_TILE_SIZE; i = i + 1)
                begin
                    kernel_transformed_reg[j][i][k] <= 0;
                end
            end
        end
        else
        begin
            for(j = 0; j < INPUT_TILE_SIZE; j = j + 1)
            begin
                kernel_transformed_reg[j][3] <= kernel_temp_reg[j][2];
                kernel_transformed_reg[j][2] <= (kernel_temp_reg[j][2] + kernel_temp_reg[j][1] + kernel_temp_reg[j][0]) >>> 1;
                kernel_transformed_reg[j][1] <= (kernel_temp_reg[j][2] - kernel_temp_reg[j][1] + kernel_temp_reg[j][0]) >>> 1;
                kernel_transformed_reg[j][0] <= kernel_temp_reg[j][0];
            end
            if (TransStage1Done)
                TransStage2Done <= 1'b1;
        end
    end
    
    // Element-Wise Matrix Multiplication (EWMM)
    always @(posedge clk)
    begin
        if (reset)
        begin
            ewmmDone <= 1'b0;

            for (i = 0; i < INPUT_TILE_SIZE; i = i + 1)
            begin
                for (j = 0; j < INPUT_TILE_SIZE; j = j + 1)
                begin
                    ewmm_reg[i][j] <= 0;
                end
            end

        end
        else
        begin

            for (i = 0; i < INPUT_TILE_SIZE; i = i + 1)
            begin
                for (j = 0; j < INPUT_TILE_SIZE; j = j + 1)
                begin
                    ewmm_reg[i][j] <= input_transformed_reg[i][j] * kernel_transformed_reg[i][j];
                end
            end

            if (TransStage2Done)
                ewmmDone <= 1'b1;
        end
    end

    
   // Output Transformation (Winograd Inverse Transform - Row Transformation)
    always @(posedge clk)
    begin
        if (reset)
        begin
            out1Done <= 1'b0;

            for (j = 0; j < INPUT_TILE_SIZE; j = j + 1)
            begin
                output_reg1[0][j] <= 0;
                output_reg1[1][j] <= 0;
            end

        end
        else
        begin

            for (j = 0; j < INPUT_TILE_SIZE; j = j + 1)
            begin
                output_reg1[1][j] <= ewmm_reg[1][j] + ewmm_reg[2][j] + ewmm_reg[3][j];
                output_reg1[0][j] <= ewmm_reg[2][j] - ewmm_reg[1][j] - ewmm_reg[0][j];
            end

            if (ewmmDone)
                out1Done <= 1'b1;
        end
    end
    
    
   // Output Transformation - Column Transformation
    always @(posedge clk)
    begin
        if (reset)
        begin
            out2Done <= 1'b0;

            for (j = 0; j < INPUT_TILE_SIZE - KERNEL_SIZE + 1; j = j + 1)
            begin
                output_reg2[j][0] <= 0;
                output_reg2[j][1] <= 0;
            end

        end
        else
        begin

            for (j = 0; j < INPUT_TILE_SIZE - KERNEL_SIZE + 1; j = j + 1)
            begin
                output_reg2[j][1] <= output_reg1[j][3] + output_reg1[j][2] + output_reg1[j][1];
                output_reg2[j][0] <= output_reg1[j][2] - output_reg1[j][1] - output_reg1[j][0];
            end

            if (out1Done)
                out2Done <= 1'b1;
        end
    end

    // This block performs the accumulation step where multiple channel outputs are added together into one single channel
    always @(posedge clk)
    begin
        if (reset)
        begin
            finalCompute <= 1'b0;
            for (i = 0; i < INPUT_TILE_SIZE - KERNEL_SIZE + 1; i = i + 1)
            begin
                for (j = 0; j < INPUT_TILE_SIZE - KERNEL_SIZE + 1; j = j + 1)
                begin
                        output_final_reg[i][j] <= 0;
                end
            end
        end
        else
        begin
            if (out2Done)
            begin
                for (i = 0; i < INPUT_TILE_SIZE - KERNEL_SIZE + 1; i = i + 1) 
                begin
                    for (j = 0; j < INPUT_TILE_SIZE - KERNEL_SIZE + 1; j = j + 1) begin
                        temp_sum = 0;
                        temp_sum = temp_sum + output_reg2[i][j];
                        output_final_reg[i][j] <= temp_sum;
                    end
                end
                
                finalCompute <= 1'b1;
            end
        end
    end

    
    // This block is used to convert the (R x R) output tile into a flattened 1D vector for output
    always @(posedge clk)
    begin
        if (reset)
        begin
            finalFlatten <= 1'b0;
        end
        if (finalCompute)
        begin
            for (i = 0; i < INPUT_TILE_SIZE - KERNEL_SIZE + 1; i = i + 1)
            begin
                for (j = 0; j < INPUT_TILE_SIZE - KERNEL_SIZE + 1; j = j + 1)
                begin
                    outData[(i * (INPUT_TILE_SIZE - KERNEL_SIZE + 1) + j) * OUTPUT_FINAL_WIDTH +: OUTPUT_FINAL_WIDTH] <= output_final_reg[i][j];
                end
                finalFlatten <= 1'b1;
            end
        end
    end
endmodule
