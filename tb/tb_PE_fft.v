`timescale 1ns/1ps

module PE_fft_tb;

    // Parameters
    parameter KERNEL_SIZE = 3;
    parameter INPUT_TILE_SIZE = 4;
    parameter INPUT_DATA_WIDTH = 8;
    parameter KERNEL_DATA_WIDTH = 8;
    parameter CHANNELS = 3;
    
    // Clock and Reset
    reg clk;
    reg reset;
    
    // Inputs
    reg signed [(KERNEL_SIZE*KERNEL_SIZE*KERNEL_DATA_WIDTH*CHANNELS)-1:0] Kernel;
    reg signed [(INPUT_TILE_SIZE*INPUT_TILE_SIZE*INPUT_DATA_WIDTH*CHANNELS)-1:0] inpData;
    
    // Outputs
    wire signed [(INPUT_TILE_SIZE-KERNEL_SIZE+1)*(INPUT_TILE_SIZE-KERNEL_SIZE+1)*(KERNEL_DATA_WIDTH+INPUT_DATA_WIDTH+13)-1:0] outData;
    wire finalCompute;
    
    // Instantiate DUT
    PE_fft #(
        .KERNEL_SIZE(KERNEL_SIZE),
        .INPUT_TILE_SIZE(INPUT_TILE_SIZE),
        .INPUT_DATA_WIDTH(INPUT_DATA_WIDTH),
        .KERNEL_DATA_WIDTH(KERNEL_DATA_WIDTH),
        .CHANNELS(CHANNELS)
    ) uut (
        .clk(clk),
        .reset(reset),
        .Kernel(Kernel),
        .inpData(inpData),
        .outData(outData),
        .finalCompute(finalCompute)
    );
    
    // Clock generation
    initial begin
        clk = 1;
        forever #5 clk = ~clk;
    end
    
    // Test stimulus
    initial begin
        // Initialize
        reset = 1;
        Kernel = 0;
        inpData = 0;
        
        // Apply reset
        #20;
        reset = 0;

        // Provide Kernel values (rearranged for 3 channels)
        Kernel = {
            // Channel 2 Kernel (3x3)
            8'sd8, 8'sd0, 8'sd8,   // Row 1
            8'sd0, 8'sd8, 8'sd0,   // Row 2
            8'sd8, 8'sd0, 8'sd8,   // Row 3

            // Channel 1 Kernel (3x3)
            8'sd8, 8'sd8, 8'sd16,  // Row 1
            8'sd8, 8'sd8, 8'sd16,  // Row 2
            8'sd8, 8'sd8, 8'sd16,  // Row 3

            // Channel 0 Kernel (3x3)
            8'sd8, 8'sd0, 8'sd0,   // Row 1
            8'sd0, 8'sd8, 8'sd0,   // Row 2
            8'sd0, 8'sd0, 8'sd8    // Row 3
        };

        // Provide Input Tile values (rearranged for 3 channels)
        inpData = {
            // Channel 2 (4x4)
            8'sd1,  8'sd2,  8'sd3,  8'sd4,   // Row 1
            8'sd5,  8'sd6,  8'sd7,  8'sd8,   // Row 2
            8'sd9,  8'sd10, 8'sd11, 8'sd12,  // Row 3
            8'sd13, 8'sd14, 8'sd15, 8'sd16,  // Row 4

            // Channel 1 (4x4)
            8'sd1, 8'sd1, 8'sd1, 8'sd1,   // Row 1
            8'sd1, 8'sd1, 8'sd1, 8'sd1,   // Row 2
            8'sd1, 8'sd1, 8'sd1, 8'sd1,   // Row 3
            8'sd1, 8'sd1, 8'sd1, 8'sd1,   // Row 4

            // Channel 0 (4x4)
            8'sd1, 8'sd2, 8'sd3, 8'sd4,      // Row 1
           -8'sd1,-8'sd2,-8'sd3,-8'sd4,      // Row 2
            8'sd1,-8'sd2, 8'sd3,-8'sd4,      // Row 3
            8'sd0, 8'sd0, 8'sd0,-8'sd1       // Row 4
        };
        
        // Wait for computation to complete
        wait(finalCompute == 1);
        #100;
        
        // Display results
        $display("Final 2x2 Output:");
        $display("Pixel [0][0]: %d", outData[0*72 +: 24]);
        $display("Pixel [0][1]: %d", outData[1*72 +: 24]);
        $display("Pixel [1][0]: %d", outData[2*72 +: 24]);
        $display("Pixel [1][1]: %d", outData[3*72 +: 24]);
        
        $finish;
    end
    

endmodule
