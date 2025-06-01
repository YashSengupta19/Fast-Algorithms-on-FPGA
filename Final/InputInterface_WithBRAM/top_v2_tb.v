`timescale 1ns/1ps

module top_v2_tb;

    parameter KERNEL_SIZE       = 3;
    parameter INPUT_IMAGE_WIDTH = 10;
    parameter INPUT_TILE_SIZE   = 4;
    parameter INPUT_DATA_WIDTH  = 8;
    parameter KERNEL_DATA_WIDTH = 8;
    parameter CHANNELS          = 3;

    reg clk;
    reg reset;
//    wire signed [(INPUT_TILE_SIZE - KERNEL_SIZE + 1) * 
//                 (INPUT_TILE_SIZE - KERNEL_SIZE + 1) * 
//                 (KERNEL_DATA_WIDTH + INPUT_DATA_WIDTH + 13) - 1 : 0] outData;

    wire outData;

    // Instantiate DUT (Device Under Test)
    top_v2 #(
        .KERNEL_SIZE(KERNEL_SIZE),
        .INPUT_IMAGE_WIDTH(INPUT_IMAGE_WIDTH),
        .INPUT_TILE_SIZE(INPUT_TILE_SIZE),
        .INPUT_DATA_WIDTH(INPUT_DATA_WIDTH),
        .KERNEL_DATA_WIDTH(KERNEL_DATA_WIDTH),
        .CHANNELS(CHANNELS)
    ) dut (
        .clk(clk),
        .reset(reset),
        .comb_output(outData)
    );

    initial begin
        clk = 1;
        forever #5 clk = ~clk;  
    end

    initial begin
        reset = 1;
        #30 reset = 0;  
    end

endmodule
