`timescale 1ns / 1ps

module PE #(
    parameter int KERNEL_SIZE       = 3,
                INPUT_TILE_SIZE     = 4,
                INPUT_DATA_WIDTH    = 8,
                KERNEL_DATA_WIDTH   = 8,
                CHANNELS            = 3
)(
    // Global Signals
    input logic clk,
    input logic reset,
    
    // Kernel Loading
    input logic [(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * CHANNELS) - 1 : 0] Kernel,
    
    // Output Loading
    input logic [(INPUT_TILE_SIZE * INPUT_TILE_SIZE * INPUT_DATA_WIDTH * CHANNELS) - 1 : 0] inpData,
    output logic [(INPUT_TILE_SIZE - KERNEL_SIZE) * (INPUT_TILE_SIZE - KERNEL_SIZE) * (KERNEL_DATA_WIDTH + INPUT_DATA_WIDTH + 8) - 1 : 0] outData
);
    
    // Defining the registers with SystemVerilog logic type
    logic [KERNEL_DATA_WIDTH - 1 : 0] kernel_reg [KERNEL_SIZE] [KERNEL_SIZE] [CHANNELS];       
    logic [INPUT_DATA_WIDTH - 1 : 0] input_reg [INPUT_TILE_SIZE] [INPUT_TILE_SIZE] [CHANNELS]; 
    
    // Transformation registers
    logic [INPUT_DATA_WIDTH : 0] input_temp_reg [INPUT_TILE_SIZE] [INPUT_TILE_SIZE] [CHANNELS]; 
    logic [INPUT_DATA_WIDTH + 1 : 0] input_transformed_reg [INPUT_TILE_SIZE] [INPUT_TILE_SIZE] [CHANNELS]; 
    
    logic [KERNEL_DATA_WIDTH : 0] kernel_temp_reg [INPUT_TILE_SIZE] [KERNEL_SIZE] [CHANNELS];
    logic [KERNEL_DATA_WIDTH + 1 : 0] kernel_transformed_reg [INPUT_TILE_SIZE] [INPUT_TILE_SIZE] [CHANNELS];
        
    logic [KERNEL_DATA_WIDTH + INPUT_DATA_WIDTH + 2 : 0] ewmm_reg [INPUT_TILE_SIZE] [INPUT_TILE_SIZE] [CHANNELS]; // Element-Wise Matrix Multiplication
    
    logic [KERNEL_DATA_WIDTH + INPUT_DATA_WIDTH + 4 : 0] output_reg1 [INPUT_TILE_SIZE - KERNEL_SIZE + 1] [INPUT_TILE_SIZE] [CHANNELS];
    logic [KERNEL_DATA_WIDTH + INPUT_DATA_WIDTH + 6 : 0] output_reg2 [INPUT_TILE_SIZE - KERNEL_SIZE + 1] [INPUT_TILE_SIZE - KERNEL_SIZE + 1] [CHANNELS];
    
    // Final output register
    logic [KERNEL_DATA_WIDTH + INPUT_DATA_WIDTH + 8 : 0] output_final_reg [INPUT_TILE_SIZE - KERNEL_SIZE + 1] [INPUT_TILE_SIZE - KERNEL_SIZE + 1];
    
    // Kernel Loading
    always_ff @(posedge clk) begin
        if (reset) begin
            kernel_reg <= '{default: '0};
        end else begin
            for (int i = KERNEL_SIZE - 1; i >= 0; i--) begin
                for (int j = KERNEL_SIZE - 1; j >= 0; j--) begin
                    for (int k = CHANNELS - 1; k >= 0; k--) begin
                        kernel_reg[i][j][k] <= Kernel[((KERNEL_SIZE * i + j) + (KERNEL_SIZE * KERNEL_SIZE * k)) * KERNEL_DATA_WIDTH +: KERNEL_DATA_WIDTH];
                    end
                end
            end
        end
    end
    
    // Input Data Loading
    always_ff @(posedge clk) begin
        if (reset) begin
            input_reg <= '{default: '0};
        end else begin
            for (int i = INPUT_TILE_SIZE - 1; i >= 0; i--) begin
                for (int j = INPUT_TILE_SIZE - 1; j >= 0; j--) begin
                    for (int k = CHANNELS - 1; k >= 0; k--) begin
                        input_reg[i][j][k] <= inpData[((INPUT_TILE_SIZE * i + j) + (INPUT_TILE_SIZE * INPUT_TILE_SIZE * k)) * INPUT_DATA_WIDTH +: INPUT_DATA_WIDTH];
                    end
                end
            end
        end
    end
    
    // Input Transformation - Part 1
    always_ff @(posedge clk) begin
        if (reset) begin
            input_temp_reg <= '{default: '0};
        end else begin
            for (int k = CHANNELS - 1; k >= 0; k--) begin
                for (int j = INPUT_TILE_SIZE - 1; j >= 0; j--) begin
                    input_temp_reg[INPUT_TILE_SIZE - 1][j][k] <= input_reg[3][j][k] - input_reg[1][j][k];
                    input_temp_reg[INPUT_TILE_SIZE - 2][j][k] <= input_reg[2][j][k] + input_reg[1][j][k];
                    input_temp_reg[INPUT_TILE_SIZE - 3][j][k] <= - input_reg[2][j][k] + input_reg[1][j][k];
                    input_temp_reg[INPUT_TILE_SIZE - 4][j][k] <= input_reg[2][j][k] - input_reg[0][j][k];
                end
            end
        end
    end
    
    // Input Transformation - Part 2
    always_ff @(posedge clk) begin
        if (reset) begin
            input_transformed_reg <= '{default: '0};
        end else begin
            for (int k = CHANNELS - 1; k >= 0; k--) begin
                for (int j = INPUT_TILE_SIZE - 1; j >= 0; j--) begin
                    input_transformed_reg[j][INPUT_TILE_SIZE - 1][k] <= input_temp_reg[j][3][k] - input_temp_reg[j][1][k];
                    input_transformed_reg[j][INPUT_TILE_SIZE - 2][k] <= input_temp_reg[j][2][k] + input_temp_reg[j][1][k];
                    input_transformed_reg[j][INPUT_TILE_SIZE - 3][k] <= - input_temp_reg[j][2][k] + input_temp_reg[j][1][k];
                    input_transformed_reg[j][INPUT_TILE_SIZE - 4][k] <= input_temp_reg[j][2][k] - input_temp_reg[j][0][k];
                end
            end
        end
    end
    
    // Kernel Transformation - Part 1
    always_ff @(posedge clk) begin
        if (reset) begin
            kernel_temp_reg <= '{default: '0};
        end else begin
            for (int k = CHANNELS - 1; k >= 0; k--) begin
                for (int j = KERNEL_SIZE - 1; j >= 0; j--) begin
                    kernel_temp_reg[INPUT_TILE_SIZE - 1][j][k] <= kernel_reg[2][j][k];
                    kernel_temp_reg[INPUT_TILE_SIZE - 2][j][k] <= (kernel_reg[2][j][k] + kernel_reg[1][j][k] + kernel_reg[0][j][k]) >>> 1;
                    kernel_temp_reg[INPUT_TILE_SIZE - 3][j][k] <= (kernel_reg[2][j][k] - kernel_reg[1][j][k] + kernel_reg[0][j][k]) >>> 1;
                    kernel_temp_reg[INPUT_TILE_SIZE - 4][j][k] <= kernel_reg[0][j][k];
                end
            end
        end
    end
    
    // Kernel Transformation - Part 2
    always_ff @(posedge clk) begin
        if (reset) begin
            kernel_transformed_reg <= '{default: '0};
        end else begin
            for (int k = CHANNELS - 1; k >= 0; k--) begin
                for (int j = INPUT_TILE_SIZE - 1; j >= 0; j--) begin
                    kernel_transformed_reg[j][INPUT_TILE_SIZE - 1][k] <= kernel_temp_reg[j][2][k];
                    kernel_transformed_reg[j][INPUT_TILE_SIZE - 2][k] <= (kernel_temp_reg[j][2][k] + kernel_temp_reg[j][1][k] + kernel_temp_reg[j][1][k]) >>> 1;
                    kernel_transformed_reg[j][INPUT_TILE_SIZE - 3][k] <= (kernel_temp_reg[j][2][k] - kernel_temp_reg[j][1][k] + kernel_temp_reg[j][1][k]) >>> 1;
                    kernel_transformed_reg[j][INPUT_TILE_SIZE - 4][k] <= kernel_temp_reg[j][0][k];
                end
            end
        end
    end
    
    // Element-Wise Matrix Multiplication
    always_ff @(posedge clk) begin
        if (reset) begin
            ewmm_reg <= '{default: '0};
        end else begin
            for (int k = CHANNELS - 1; k >= 0; k--) begin
                for (int i = INPUT_TILE_SIZE - 1; i >= 0; i--) begin
                    for (int j = INPUT_TILE_SIZE - 1; j >= 0; j--) begin
                        ewmm_reg[i][j][k] <= input_transformed_reg[i][j][k] + kernel_transformed_reg[i][j][k];
                    end
                end
            end
        end
    end
    
    // Output Transformation - Part 1
    always_ff @(posedge clk) begin
        if (reset) begin
            output_reg1 <= '{default: '0};
        end else begin
            for (int k = CHANNELS - 1; k >= 0; k--) begin
                for (int j = INPUT_TILE_SIZE - 1; j >= 0; j--) begin
                    output_reg1[INPUT_TILE_SIZE - KERNEL_SIZE][j][k] <= ewmm_reg[3][j][k] + ewmm_reg[2][j][k] + ewmm_reg[1][j][k];
                    output_reg1[INPUT_TILE_SIZE - KERNEL_SIZE - 1][j][k] <= ewmm_reg[2][j][k] - ewmm_reg[1][j][k] - ewmm_reg[0][j][k];
                end
            end
        end
    end
    
    // Output Transformation - Part 2
    always_ff @(posedge clk) begin
        if (reset) begin
            output_reg2 <= '{default: '0};
        end else begin
            for (int k = CHANNELS - 1; k >= 0; k--) begin
                for (int j = INPUT_TILE_SIZE - KERNEL_SIZE; j >= 0; j--) begin
                    output_reg2[j][INPUT_TILE_SIZE - KERNEL_SIZE][k] <= output_reg1[j][3][k] + output_reg1[j][2][k] + output_reg1[j][1][k];
                    output_reg2[j][INPUT_TILE_SIZE - KERNEL_SIZE - 1][k] <= output_reg1[j][2][k] - output_reg1[j][1][k] - output_reg1[j][0][k];
                end
            end
        end
    end
    
    // Channel Accumulation
    always_ff @(posedge clk) begin
        if (reset) begin
            output_final_reg <= '{default: '0};
        end else begin
            for (int i = INPUT_TILE_SIZE - KERNEL_SIZE; i >= 0; i--) begin
                for (int j = INPUT_TILE_SIZE - KERNEL_SIZE; j >= 0; j--) begin
                    for (int k = CHANNELS - 1; k >= 0; k--) begin
                        output_final_reg[i][j] <= output_final_reg[i][j] + output_reg2[i][j][k];
                    end
                end
            end
        end
    end
    
    // Output Data Flattening
    always_ff @(posedge clk) begin
        if (reset) begin
            outData <= '0;
        end else begin
            for (int i = INPUT_TILE_SIZE - KERNEL_SIZE; i >= 0; i--) begin
                for (int j = INPUT_TILE_SIZE - KERNEL_SIZE; j >= 0; j--) begin
                    outData[((INPUT_TILE_SIZE - KERNEL_SIZE + 1) * i + j) * (KERNEL_DATA_WIDTH + INPUT_DATA_WIDTH + 8) +: (KERNEL_DATA_WIDTH + INPUT_DATA_WIDTH + 8)] <= output_final_reg[i][j];
                end
            end
        end
    end

endmodule