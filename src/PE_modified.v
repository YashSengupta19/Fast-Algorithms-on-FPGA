`timescale 1ns / 1ps

module PE_new #( 
    parameter KERNEL_SIZE       = 3,
    INPUT_TILE_SIZE   = 4,
    INPUT_DATA_WIDTH  = 8,
    KERNEL_DATA_WIDTH = 8,
    CHANNELS          = 3
)(
    // Global Signals
    input clk,
    input reset,
    
    // Kernel Loading
    input signed [(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * CHANNELS) - 1 : 0] Kernel,
    
    // Output Loading
    input signed [(INPUT_TILE_SIZE * INPUT_TILE_SIZE * INPUT_DATA_WIDTH * CHANNELS) - 1 : 0] inpData,
    output reg signed[(INPUT_TILE_SIZE - KERNEL_SIZE + 1) * (INPUT_TILE_SIZE - KERNEL_SIZE + 1) * (KERNEL_DATA_WIDTH + INPUT_DATA_WIDTH + 13) - 1 : 0] outData,
    output reg finalCompute
);
    
    // Local Parameters
    localparam INPUT_TRANSFORMED_WIDTH = INPUT_DATA_WIDTH + 1; // Complete Input Transformation requires 2 additions
    localparam INPUT_TRANSFORMATION_WIDTH_FINAL = INPUT_TRANSFORMED_WIDTH + 1;
    localparam KERNEL_TRANSFORMED_WIDTH = KERNEL_DATA_WIDTH + 3; // Complete Kernel Transformation requires 4 additions
    localparam KERNEL_TRANSFORMATION_WIDTH_FINAL = KERNEL_TRANSFORMED_WIDTH + 3;
    localparam EWMM_WIDTH = INPUT_TRANSFORMED_WIDTH + KERNEL_TRANSFORMED_WIDTH;
    localparam OUTPUT_REG_WIDTH = EWMM_WIDTH + 2;
    localparam OUTPUT_REG_WIDTH_1 = OUTPUT_REG_WIDTH + 2;
    localparam OUTPUT_FINAL_WIDTH = OUTPUT_REG_WIDTH_1 + 1;
    
    // Fixed-point implementation with Q8.8 format (8 integer bits, 8 fractional bits)
    // Parameters for fixed-point representation
    localparam INT_BITS = 8;
    localparam FRAC_BITS = 8;
    localparam TOTAL_BITS = INT_BITS + FRAC_BITS;
    
    // Fixed-point constant for 0.5 in Q8.8 format = 0.5 * 2^8 = 128
    localparam signed [TOTAL_BITS-1:0] HALF = 16'h0080; 
    
    // Defining the registers
    reg signed [KERNEL_DATA_WIDTH - 1 : 0] kernel_reg [KERNEL_SIZE - 1 : 0] [KERNEL_SIZE - 1 : 0] [CHANNELS - 1 : 0]; // Original kernel values
    reg signed [INPUT_DATA_WIDTH - 1 : 0] input_reg [INPUT_TILE_SIZE - 1 : 0] [INPUT_TILE_SIZE - 1 : 0] [CHANNELS - 1 : 0]; // Original input values
    
    // Fixed-point versions of the kernel and intermediate results
    reg signed [TOTAL_BITS-1:0] kernel_fixed [KERNEL_SIZE - 1 : 0] [KERNEL_SIZE - 1 : 0] [CHANNELS - 1 : 0];
    reg signed [TOTAL_BITS-1:0] kernel_temp_fixed [INPUT_TILE_SIZE - 1 : 0] [KERNEL_SIZE - 1 : 0] [CHANNELS - 1 : 0];
    reg signed [TOTAL_BITS-1:0] kernel_transformed_fixed [INPUT_TILE_SIZE - 1 : 0] [INPUT_TILE_SIZE - 1 : 0] [CHANNELS - 1 : 0];
    
    // Input transformation registers (standard integers for input part)
    reg signed [INPUT_TRANSFORMED_WIDTH - 1 : 0] input_temp_reg [INPUT_TILE_SIZE - 1 : 0] [INPUT_TILE_SIZE - 1 : 0] [CHANNELS - 1 : 0];
    reg signed [INPUT_TRANSFORMATION_WIDTH_FINAL - 1 : 0] input_transformed_reg [INPUT_TILE_SIZE - 1 : 0] [INPUT_TILE_SIZE - 1 : 0] [CHANNELS - 1 : 0];
    
    // Element-wise multiplication and output registers
    reg signed [EWMM_WIDTH + FRAC_BITS - 1 : 0] ewmm_reg [INPUT_TILE_SIZE - 1 : 0] [INPUT_TILE_SIZE - 1 : 0] [CHANNELS - 1 : 0]; // Needs extra bits for fractional part
    reg signed [OUTPUT_REG_WIDTH - 1 : 0] output_reg1 [INPUT_TILE_SIZE - KERNEL_SIZE : 0] [INPUT_TILE_SIZE - 1 : 0] [CHANNELS - 1 : 0];
    reg signed [OUTPUT_REG_WIDTH_1 - 1 : 0] output_reg2 [INPUT_TILE_SIZE - KERNEL_SIZE : 0] [INPUT_TILE_SIZE - KERNEL_SIZE : 0] [CHANNELS - 1 : 0];
    reg signed [OUTPUT_FINAL_WIDTH - 1 : 0] output_final_reg [INPUT_TILE_SIZE - KERNEL_SIZE : 0] [INPUT_TILE_SIZE - KERNEL_SIZE : 0];
    
    reg LoadDone, TransStage1Done, TransStage2Done, ewmmDone, out1Done, out2Done;
    
    integer i, j, k; // Loop variables
    
    // 1. Load kernel data
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
                        kernel_fixed[i][j][k] <= 0;
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
                        // Load original kernel values
                        kernel_reg[i][j][k] <= Kernel[((k * KERNEL_SIZE * KERNEL_SIZE + i * KERNEL_SIZE + j) * KERNEL_DATA_WIDTH) +: KERNEL_DATA_WIDTH];
                        // Convert to fixed-point by shifting left by FRAC_BITS
                        kernel_fixed[i][j][k] <= Kernel[((k * KERNEL_SIZE * KERNEL_SIZE + i * KERNEL_SIZE + j) * KERNEL_DATA_WIDTH) +: KERNEL_DATA_WIDTH] << FRAC_BITS;
                    end
                end
            end
            LoadDone <= 1'b1;
        end
    end
    
    // 2. Load input data
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
    
    // 3. Input transformation (BT_d = B'.d) - keep as integer arithmetic
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
    
    // 4. Complete input transformation (BdB = (BT_d).B)
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
    
    // 5. Kernel transformation stage 1 (fixed-point) - G_g = G.g
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
                        kernel_temp_fixed[i][j][k] <= 0;
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
                    // G(0,0) = 1
                    kernel_temp_fixed[0][j][k] <= kernel_fixed[0][j][k];
                    
                    // G(1,0) = 0.5, G(1,1) = 0.5, G(1,2) = 0.5
                    // Using fixed-point multiplication: val * HALF then normalize by right shift
                    kernel_temp_fixed[1][j][k] <= 
                        ((kernel_fixed[0][j][k] * HALF) >> FRAC_BITS) + 
                        ((kernel_fixed[1][j][k] * HALF) >> FRAC_BITS) + 
                        ((kernel_fixed[2][j][k] * HALF) >> FRAC_BITS);
                    
                    // G(2,0) = 0.5, G(2,1) = -0.5, G(2,2) = 0.5
                    kernel_temp_fixed[2][j][k] <= 
                        ((kernel_fixed[0][j][k] * HALF) >> FRAC_BITS) + 
                        (((-kernel_fixed[1][j][k]) * HALF) >> FRAC_BITS) + 
                        ((kernel_fixed[2][j][k] * HALF) >> FRAC_BITS);
                    
                    // G(3,2) = 1
                    kernel_temp_fixed[3][j][k] <= kernel_fixed[2][j][k];
                end
            end
            if (LoadDone)
                TransStage1Done <= 1'b1;
        end
    end
    
    // 6. Kernel transformation stage 2 (fixed-point) - GgG = (G_g).G'
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
                        kernel_transformed_fixed[j][i][k] <= 0;
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
                    // G'(0,0) = 1
                    kernel_transformed_fixed[j][0][k] <= kernel_temp_fixed[j][0][k];
                    
                    // G'(0,1) = 0.5, G'(1,1) = 0.5, G'(2,1) = 0.5
                    kernel_transformed_fixed[j][1][k] <= 
                        ((kernel_temp_fixed[j][0][k] * HALF) >> FRAC_BITS) + 
                        ((kernel_temp_fixed[j][1][k] * HALF) >> FRAC_BITS) + 
                        ((kernel_temp_fixed[j][2][k] * HALF) >> FRAC_BITS);
                    
                    // G'(0,2) = 0.5, G'(1,2) = -0.5, G'(2,2) = 0.5
                    kernel_transformed_fixed[j][2][k] <= 
                        ((kernel_temp_fixed[j][0][k] * HALF) >> FRAC_BITS) + 
                        (((-kernel_temp_fixed[j][1][k]) * HALF) >> FRAC_BITS) + 
                        ((kernel_temp_fixed[j][2][k] * HALF) >> FRAC_BITS);
                    
                    // G'(2,3) = 1
                    kernel_transformed_fixed[j][3][k] <= kernel_temp_fixed[j][2][k];
                end
            end
            if (TransStage1Done)
                TransStage2Done <= 1'b1;
        end
    end
    
    // 7. Element-wise matrix multiplication with fixed-point kernel
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
            for (k = 0; k < CHANNELS; k = k + 1)
            begin
                for (i = 0; i < INPUT_TILE_SIZE; i = i + 1)
                begin
                    for (j = 0; j < INPUT_TILE_SIZE; j = j + 1)
                    begin
                        // Convert input to fixed-point by shifting, then multiply
                        ewmm_reg[i][j][k] <= (input_transformed_reg[i][j][k] << FRAC_BITS) * kernel_transformed_fixed[i][j][k];
                    end
                end
            end
            if (TransStage2Done)
                ewmmDone <= 1'b1;
        end
    end
    
    // 8. Output transformation stage 1 - Row transformation
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
            for (k = 0; k < CHANNELS; k = k + 1)
            begin
                for (j = 0; j < INPUT_TILE_SIZE; j = j + 1)
                begin
                    // Normalize by right shift to remove extra fractional bits from ewmm_reg
                    output_reg1[1][j][k] <= (ewmm_reg[1][j][k] + ewmm_reg[2][j][k] + ewmm_reg[3][j][k]) >> FRAC_BITS;
                    output_reg1[0][j][k] <= (ewmm_reg[2][j][k] - ewmm_reg[1][j][k] - ewmm_reg[0][j][k]) >> FRAC_BITS;
                end
            end
            if (ewmmDone)
                out1Done <= 1'b1;
        end
    end
    
    // 9. Output transformation stage 2 - Column transformation
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
    
    // 10. Final accumulation across channels
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
                    for (j = 0; j < INPUT_TILE_SIZE - KERNEL_SIZE + 1; j = j + 1)
                    begin
                        output_final_reg[i][j] <= 0; // Reset before accumulation
                        
                        for (k = 0; k < CHANNELS; k = k + 1)
                        begin
                            output_final_reg[i][j] <= output_final_reg[i][j] + output_reg2[i][j][k];
                        end
                    end
                end
                finalCompute <= 1'b1;
            end
        end
    end
    
    // 11. Pack the output into the outData register
    always @(posedge clk)
    begin
        if (reset)
        begin
            for (i = 0; i < (INPUT_TILE_SIZE - KERNEL_SIZE + 1) * (INPUT_TILE_SIZE - KERNEL_SIZE + 1); i = i + 1)
            begin
                outData[i * (KERNEL_DATA_WIDTH + INPUT_DATA_WIDTH + 13) +: (KERNEL_DATA_WIDTH + INPUT_DATA_WIDTH + 13)] <= 0;
            end
        end
        else if (finalCompute)
        begin
            for (i = 0; i < INPUT_TILE_SIZE - KERNEL_SIZE + 1; i = i + 1)
            begin
                for (j = 0; j < INPUT_TILE_SIZE - KERNEL_SIZE + 1; j = j + 1)
                begin
                    outData[((i * (INPUT_TILE_SIZE - KERNEL_SIZE + 1) + j) * (KERNEL_DATA_WIDTH + INPUT_DATA_WIDTH + 13)) +: (KERNEL_DATA_WIDTH + INPUT_DATA_WIDTH + 13)] <= output_final_reg[i][j];
                end
            end
        end
    end
    
endmodule