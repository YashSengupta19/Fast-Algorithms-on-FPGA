`timescale 1ns / 1ps


module PE_tb;

    // Parameters
    parameter KERNEL_SIZE = 3;
    parameter INPUT_TILE_SIZE = 4;
    parameter INPUT_DATA_WIDTH = 8;
    parameter KERNEL_DATA_WIDTH = 8;
    parameter CHANNELS = 3;

    localparam OUTPUT_WIDTH = (INPUT_TILE_SIZE - KERNEL_SIZE) * (INPUT_TILE_SIZE - KERNEL_SIZE) * (KERNEL_DATA_WIDTH + INPUT_DATA_WIDTH + 8);

    // Inputs
    reg clk;
    reg reset;
    reg signed [(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * CHANNELS)-1:0] Kernel;
    reg signed [(INPUT_TILE_SIZE * INPUT_TILE_SIZE * INPUT_DATA_WIDTH * CHANNELS)-1:0] inpData;

    // Outputs
    wire signed [OUTPUT_WIDTH-1:0] outData;
    wire finalCompute;

    // Instantiate the Unit Under Test (UUT)  
    PE #(
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

    // Clock Generation
    always #5 clk = ~clk;  // 10ns clock period
    always @(*) if (finalCompute) reset = 1;

    initial begin
        clk = 1;
        reset = 1;
        Kernel = 0;
        inpData = 0;

        // Apply reset
        #20;
        reset = 0;

        // Provide Kernel values
        Kernel = {
            8'sd8, 8'sd0, 8'sd8,   // Channel 2 Kernel Row 1
            8'sd0, 8'sd8, 8'sd0,   // Channel 2 Kernel Row 2
            8'sd8, 8'sd0, 8'sd8,   // Channel 2 Kernel Row 3

            8'sd8, 8'sd8, 8'sd16,   // Channel 1 Kernel Row 1
            8'sd8, 8'sd8, 8'sd16,   // Channel 1 Kernel Row 2
            8'sd8, 8'sd8, 8'sd16,   // Channel 1 Kernel Row 3

            8'sd8, 8'sd0, 8'sd0,   // Channel 0 Kernel Row 1
            8'sd0, 8'sd8, 8'sd0,   // Channel 0 Kernel Row 2
            8'sd0, 8'sd0, 8'sd8    // Channel 0 Kernel Row 3
        };

        // Provide Input Tile values
        inpData = {
            8'sd1,  8'sd2,  8'sd3,  8'sd4,   // Channel 2 Row 1
            8'sd5,  8'sd6,  8'sd7,  8'sd8,   // Channel 2 Row 2
            8'sd9,  8'sd10, 8'sd11, 8'sd12,  // Channel 2 Row 3
            8'sd13, 8'sd14, 8'sd15, 8'sd16,  // Channel 2 Row 4

            8'sd1, 8'sd1, 8'sd1, 8'sd1,   // Channel 1 Row 1
            8'sd1, 8'sd1, 8'sd1, 8'sd1,   // Channel 1 Row 2
            8'sd1, 8'sd1, 8'sd1, 8'sd1,   // Channel 1 Row 3
            8'sd1, 8'sd1, 8'sd1, 8'sd1,   // Channel 1 Row 4

            8'sd1, 8'sd2, 8'sd3, 8'sd4,      // Channel 0 Row 1
           -8'sd1, -8'sd2, -8'sd3, -8'sd4,   // Channel 0 Row 2
            8'sd1, -8'sd2, 8'sd3, -8'sd4,    // Channel 0 Row 3
            8'sd0, 8'sd0, 8'sd0, -8'sd1      // Channel 0 Row 4
        };
end



endmodule