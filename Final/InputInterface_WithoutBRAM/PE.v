`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/14/2025 10:16:54 AM
// Design Name: 
// Module Name: PE
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






module PE #(
    parameter KERNEL_SIZE       = 3,
              INPUT_TILE_SIZE   = 4,
              INPUT_DATA_WIDTH  = 8,
              KERNEL_DATA_WIDTH = 8,
              CHANNELS          = 3
)(
    // Global Signals
    input clk,
    input reset,
    
    // Valid Signal
    input o_valid, // This signal essentially tells me if my input is valid or not
    // Kernel Loading
    input signed [(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * CHANNELS) - 1 : 0] Kernel,
    
    // Output Loading
    input signed [(INPUT_TILE_SIZE * INPUT_TILE_SIZE * INPUT_DATA_WIDTH * CHANNELS) - 1 : 0] inpData,
    output reg signed[(INPUT_TILE_SIZE - KERNEL_SIZE + 1) * (INPUT_TILE_SIZE - KERNEL_SIZE + 1) * (KERNEL_DATA_WIDTH + INPUT_DATA_WIDTH + 13) - 1 : 0] outData,
    output reg finalCompute,
    output reg finalFlatten
    );
    
    // Local Parameters
    
    localparam INPUT_TRANSFORMED_WIDTH = INPUT_DATA_WIDTH + 1; // Complete Input Transformation requires 2 additions
    localparam INPUT_TRANSFORMATION_WIDTH_FINAL = INPUT_TRANSFORMED_WIDTH + 1;
    localparam KERNEL_TRANSFORMED_WIDTH = KERNEL_DATA_WIDTH + 2; // Complete Kernel Transformation requires 4 additions
    localparam KERNEL_TRANSFORMATION_WIDTH_FINAL = KERNEL_TRANSFORMED_WIDTH + 2;
    localparam EWMM_WIDTH = KERNEL_TRANSFORMATION_WIDTH_FINAL + INPUT_TRANSFORMATION_WIDTH_FINAL;
    localparam OUTPUT_REG_WIDTH = EWMM_WIDTH + 2;
    localparam OUTPUT_REG_WIDTH_1 = OUTPUT_REG_WIDTH + 2;
    localparam OUTPUT_FINAL_WIDTH = (OUTPUT_REG_WIDTH_1 + CHANNELS - 1'b1) ;
    
    // Defining the registers
    reg signed [KERNEL_DATA_WIDTH - 1 : 0] kernel_reg [KERNEL_SIZE - 1 : 0] [KERNEL_SIZE - 1 : 0] [CHANNELS - 1 : 0]; // This register will hold all the Kernel Values in correct format
    reg signed [INPUT_DATA_WIDTH - 1 : 0] input_reg [INPUT_TILE_SIZE - 1 : 0] [INPUT_TILE_SIZE - 1 : 0] [CHANNELS - 1 : 0]; // This register will hold all the Input Values in correct format
    
    // These two registers are used for transforming the input
    reg signed [INPUT_TRANSFORMED_WIDTH - 1 : 0] input_temp_reg [INPUT_TILE_SIZE - 1 : 0] [INPUT_TILE_SIZE - 1 : 0] [CHANNELS - 1 : 0]; // (Bd g) = D
    reg signed [INPUT_TRANSFORMATION_WIDTH_FINAL - 1 : 0] input_transformed_reg [INPUT_TILE_SIZE - 1 : 0] [INPUT_TILE_SIZE - 1 : 0] [CHANNELS - 1 : 0]; // (D Bd') = Transformed Input
    
    // These two registers are used for transforming the Kernel
    reg signed [KERNEL_TRANSFORMED_WIDTH - 1 : 0] kernel_temp_reg [INPUT_TILE_SIZE - 1 : 0] [KERNEL_SIZE - 1 : 0] [CHANNELS - 1 : 0];
    reg signed [KERNEL_TRANSFORMATION_WIDTH_FINAL - 1 : 0] kernel_transformed_reg [INPUT_TILE_SIZE - 1 : 0] [INPUT_TILE_SIZE - 1 : 0] [CHANNELS - 1 : 0];
        
    reg signed [EWMM_WIDTH -1 : 0] ewmm_reg [INPUT_TILE_SIZE - 1 : 0] [INPUT_TILE_SIZE - 1 : 0] [CHANNELS - 1 : 0]; // Element-Wise Matrix Multiplication
    
    // These two registers are used for transforming the output
    reg signed [OUTPUT_REG_WIDTH - 1 : 0] output_reg1 [INPUT_TILE_SIZE - KERNEL_SIZE : 0] [INPUT_TILE_SIZE - 1 : 0] [CHANNELS - 1 : 0];
    reg signed [OUTPUT_REG_WIDTH_1 - 1 : 0] output_reg2 [INPUT_TILE_SIZE - KERNEL_SIZE : 0] [INPUT_TILE_SIZE - KERNEL_SIZE : 0] [CHANNELS - 1 : 0];
    
    // This register stores the final output after the accumulation step
    reg signed [OUTPUT_FINAL_WIDTH - 1 : 0] output_final_reg [INPUT_TILE_SIZE - KERNEL_SIZE : 0] [INPUT_TILE_SIZE - KERNEL_SIZE : 0];
    reg signed [OUTPUT_FINAL_WIDTH - 1:0] temp_sum;

    
    reg LoadDone, TransStage1Done, TransStage2Done, ewmmDone, out1Done, out2Done;
    reg inpValid1, inpValid2, inpValid3, inpValid4, inpValid5, inpValid6; // Valid Signals of all stages
    
    
    
    integer i, j, k; // Defined as loop variables
    
    always @(posedge clk)
    begin
        if (reset)
        begin
            inpValid1 <= 1'b0;
            inpValid2 <= 1'b0;
            inpValid3 <= 1'b0;
            inpValid4 <= 1'b0;
            inpValid5 <= 1'b0;
            inpValid6 <= 1'b0;
        end
        
        else
        begin
            inpValid1 <= o_valid;
            inpValid2 <= inpValid1;
            inpValid3 <= inpValid2;
            inpValid4 <= inpValid3;
            inpValid5 <= inpValid4;
            inpValid6 <= inpValid5;
        end
    end
    
    // This block loads the Kernel input data from a flattened 1D vector into a Kernel of proper size (K x K x M)
   always @(posedge clk)
    begin
        if(reset)
        begin
            LoadDone <= 1'b0;
            for (i = 0; i < KERNEL_SIZE; i = i + 1)
            begin
                for (j = 0; j < KERNEL_SIZE; j = j + 1)
                begin
                    for (k = 0; k < CHANNELS; k = k + 1)
                    begin
                        kernel_reg[i][j][k] <= 0;
                    end
                end
            end
        end
        else
        begin
            for (i = 0; i < KERNEL_SIZE; i = i + 1)
            begin
                for (j = 0; j < KERNEL_SIZE; j = j + 1)
                begin
                    for (k = 0; k < CHANNELS; k = k + 1)
                    begin
                        kernel_reg[i][j][k] <= Kernel[((k * KERNEL_SIZE * KERNEL_SIZE + i * KERNEL_SIZE + j) * KERNEL_DATA_WIDTH) +: KERNEL_DATA_WIDTH];
                    end
                end
            end
            LoadDone <= 1'b1;
        end
    end
    
    // This block loads the input data from a flattened 1D vector into a Image Matrix of proper size (N x N x M)
    always @(posedge clk)
    begin
        if(reset)
        begin
            for (i = 0; i < INPUT_TILE_SIZE; i = i + 1)
            begin
                for (j = 0; j < INPUT_TILE_SIZE; j = j + 1)
                begin
                    for (k = 0; k < CHANNELS; k = k + 1)
                    begin
                        input_reg[i][j][k] <= 0;
                    end
                end
            end
        end
        else
        begin
            if (inpValid1)
            begin
                for (i = 0; i < INPUT_TILE_SIZE; i = i + 1)
                begin
                    for (j = 0; j < INPUT_TILE_SIZE; j = j + 1)
                    begin
                        for (k = 0; k < CHANNELS; k = k + 1)
                        begin
                            input_reg[i][j][k] <= inpData[((k * INPUT_TILE_SIZE * INPUT_TILE_SIZE + i * INPUT_TILE_SIZE + j) * INPUT_DATA_WIDTH) +: INPUT_DATA_WIDTH];
                        end
                    end
                end
            end
            
        end
    end

    
    // Winograd transformation: (Bd * g)
    // For 4x4 input tile and 3x3 kernel
    always @(posedge clk)
    begin
        if (reset)
        begin
            for(k = 0; k < CHANNELS; k = k + 1)
            begin
                for(j = 0; j < INPUT_TILE_SIZE; j = j + 1)
                begin
                    for(i = 0; i < INPUT_TILE_SIZE; i = i + 1)
                    begin
                        input_temp_reg[i][j][k] <= 0;
                    end
                end
            end
        end
        else
        begin
            if (inpValid2)
            begin
                for(k = 0; k < CHANNELS; k = k + 1)
                begin
                    for(j = 0; j < INPUT_TILE_SIZE; j = j + 1)
                    begin
                        input_temp_reg[3][j][k] <= input_reg[3][j][k] - input_reg[1][j][k];
                        input_temp_reg[2][j][k] <= input_reg[2][j][k] + input_reg[1][j][k];
                        input_temp_reg[1][j][k] <= -input_reg[2][j][k] + input_reg[1][j][k];
                        input_temp_reg[0][j][k] <= input_reg[2][j][k] - input_reg[0][j][k];
                    end
                end
            end
        end
    end

    
    // This block is responsible for the second part (D Bd') of the input transformation
    // The Kernel transformtaion and the output transformation also follow similar logic
    // Second part of Winograd Transformation : (D * Bd')
    always @(posedge clk)
    begin
        if (reset)
        begin
            for(k = 0; k < CHANNELS; k = k + 1)
            begin
                for(j = 0; j < INPUT_TILE_SIZE; j = j + 1)
                begin
                    for(i = 0; i < INPUT_TILE_SIZE; i = i + 1)
                    begin
                        input_transformed_reg[j][i][k] <= 0;
                    end
                end
            end
        end
        else
        begin
            if (inpValid3)
            begin
                for(k = 0; k < CHANNELS; k = k + 1)
                begin
                    for(j = 0; j < INPUT_TILE_SIZE; j = j + 1)
                    begin
                        input_transformed_reg[j][3][k] <= input_temp_reg[j][3][k] - input_temp_reg[j][1][k];
                        input_transformed_reg[j][2][k] <= input_temp_reg[j][2][k] + input_temp_reg[j][1][k];
                        input_transformed_reg[j][1][k] <= -input_temp_reg[j][2][k] + input_temp_reg[j][1][k];
                        input_transformed_reg[j][0][k] <= input_temp_reg[j][2][k] - input_temp_reg[j][0][k];
                    end
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
            for(k = 0; k < CHANNELS; k = k + 1)
            begin
                for(j = 0; j < KERNEL_SIZE; j = j + 1)
                begin
                    for(i = 0; i < INPUT_TILE_SIZE; i = i + 1)
                    begin
                        kernel_temp_reg[i][j][k] <= 0;
                    end
                end
            end
        end
        else
        begin
            for(k = 0; k < CHANNELS; k = k + 1)
            begin
                for(j = 0; j < KERNEL_SIZE; j = j + 1)
                begin
                    kernel_temp_reg[3][j][k] <= kernel_reg[2][j][k];
                    kernel_temp_reg[2][j][k] <= (kernel_reg[2][j][k] + kernel_reg[1][j][k] + kernel_reg[0][j][k]) >>> 1;
                    kernel_temp_reg[1][j][k] <= (kernel_reg[2][j][k] - kernel_reg[1][j][k] + kernel_reg[0][j][k]) >>> 1;
                    kernel_temp_reg[0][j][k] <= kernel_reg[0][j][k];
                end
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
            for(k = 0; k < CHANNELS; k = k + 1)
            begin
                for(j = 0; j < INPUT_TILE_SIZE; j = j + 1)
                begin
                    for(i = 0; i < INPUT_TILE_SIZE; i = i + 1)
                    begin
                        kernel_transformed_reg[j][i][k] <= 0;
                    end
                end
            end
        end
        else
        begin
            for(k = 0; k < CHANNELS; k = k + 1)
            begin
                for(j = 0; j < INPUT_TILE_SIZE; j = j + 1)
                begin
                    kernel_transformed_reg[j][3][k] <= kernel_temp_reg[j][2][k];
                    kernel_transformed_reg[j][2][k] <= (kernel_temp_reg[j][2][k] + kernel_temp_reg[j][1][k] + kernel_temp_reg[j][0][k]) >>> 1;
                    kernel_transformed_reg[j][1][k] <= (kernel_temp_reg[j][2][k] - kernel_temp_reg[j][1][k] + kernel_temp_reg[j][0][k]) >>> 1;
                    kernel_transformed_reg[j][0][k] <= kernel_temp_reg[j][0][k];
                end
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
            for (k = 0; k < CHANNELS; k = k + 1)
            begin
                for (i = 0; i < INPUT_TILE_SIZE; i = i + 1)
                begin
                    for (j = 0; j < INPUT_TILE_SIZE; j = j + 1)
                    begin
                        ewmm_reg[i][j][k] <= 0;
                    end
                end
            end
        end
        else
        begin
            if (inpValid4)
            begin
                for (k = 0; k < CHANNELS; k = k + 1)
                begin
                    for (i = 0; i < INPUT_TILE_SIZE; i = i + 1)
                    begin
                        for (j = 0; j < INPUT_TILE_SIZE; j = j + 1)
                        begin
                            ewmm_reg[i][j][k] <= input_transformed_reg[i][j][k] * kernel_transformed_reg[i][j][k];
                        end
                    end
                end
                if (TransStage2Done)
                    ewmmDone <= 1'b1;
            end
        end
    end

    
   // Output Transformation (Winograd Inverse Transform - Row Transformation)
    always @(posedge clk)
    begin
        if (reset)
        begin
            out1Done <= 1'b0;
            for (k = 0; k < CHANNELS; k = k + 1)
            begin
                for (j = 0; j < INPUT_TILE_SIZE; j = j + 1)
                begin
                    output_reg1[0][j][k] <= 0;
                    output_reg1[1][j][k] <= 0;
                end
            end
        end
        else
        begin
            if (inpValid5)
            begin
                for (k = 0; k < CHANNELS; k = k + 1)
                begin
                    for (j = 0; j < INPUT_TILE_SIZE; j = j + 1)
                    begin
                        output_reg1[1][j][k] <= ewmm_reg[1][j][k] + ewmm_reg[2][j][k] + ewmm_reg[3][j][k];
                        output_reg1[0][j][k] <= ewmm_reg[2][j][k] - ewmm_reg[1][j][k] - ewmm_reg[0][j][k];
                    end
                end
                if (ewmmDone)
                    out1Done <= 1'b1;
            end
        end
    end
    
    
   // Output Transformation - Column Transformation
    always @(posedge clk)
    begin
        if (reset)
        begin
            out2Done <= 1'b0;
            for (k = 0; k < CHANNELS; k = k + 1)
            begin
                for (j = 0; j < INPUT_TILE_SIZE - KERNEL_SIZE + 1; j = j + 1)
                begin
                    output_reg2[j][0][k] <= 0;
                    output_reg2[j][1][k] <= 0;
                end
            end
        end
        else
        begin
            if (inpValid6)
            begin
                for (k = 0; k < CHANNELS; k = k + 1)
                begin
                    for (j = 0; j < INPUT_TILE_SIZE - KERNEL_SIZE + 1; j = j + 1)
                    begin
                        output_reg2[j][1][k] <= output_reg1[j][3][k] + output_reg1[j][2][k] + output_reg1[j][1][k];
                        output_reg2[j][0][k] <= output_reg1[j][2][k] - output_reg1[j][1][k] - output_reg1[j][0][k];
                    end
                end
                if (out1Done)
                    out2Done <= 1'b1;
            end
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
        else if (finalFlatten)
            output_final_reg[i][j] <= 0;
        else
        begin
            if (out2Done)
            begin
                for (i = 0; i < INPUT_TILE_SIZE - KERNEL_SIZE + 1; i = i + 1) 
                begin
                    for (j = 0; j < INPUT_TILE_SIZE - KERNEL_SIZE + 1; j = j + 1) begin
                        temp_sum = 0;
                        for (k = 0; k < CHANNELS; k = k + 1) begin
                            temp_sum = temp_sum + output_reg2[i][j][k];
                        end
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
        if (reset || finalFlatten)
        begin
            finalFlatten <= 1'b0;
        end
        else if (finalCompute)
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
