`timescale 1ns / 1ps


module top_v1#(
    parameter KERNEL_SIZE       = 3,
              INPUT_IMAGE_WIDTH = 10,
              INPUT_TILE_SIZE   = 4,
              INPUT_DATA_WIDTH  = 8,
              KERNEL_DATA_WIDTH = 8,
              CHANNELS          = 3
)(
    input clk,
    input reset,
    
    input [7:0]              i_pixel_data,
    input                    i_pixel_data_valid,
    input signed [(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * CHANNELS) - 1 : 0] Kernel,
    
    output signed[(INPUT_TILE_SIZE - KERNEL_SIZE + 1) * (INPUT_TILE_SIZE - KERNEL_SIZE + 1) * (KERNEL_DATA_WIDTH + INPUT_DATA_WIDTH + 13) - 1 : 0] outData
//    input                    proc_finish,  My guess is this is the finalCompute / finalFlatten Signal
//    output reg [3*4*4*8-1:0] o_input_tile_across_all_channel,  This signal is also an input to PE
//    output reg               o_ready  This signal will go to PE to define that output is valid 
);
    
    // Declaring registers
//    reg               proc_finish;
    wire [(CHANNELS * INPUT_TILE_SIZE * INPUT_TILE_SIZE * INPUT_DATA_WIDTH)-1:0] o_input_tile_across_all_channel;
    wire               o_ready;
    
    // PE Output Signals to be used in input interface
    wire finalCompute;
    wire finalFlatten;
    wire proc_finish;
    
    input_control_unit #(
    .M(CHANNELS),        
    .W(INPUT_IMAGE_WIDTH),       
    .n(INPUT_TILE_SIZE)         
    ) inputInterface_inst(
    .i_clk(clk),
    .i_rst(reset),
    .i_pixel_data(i_pixel_data),
    .i_pixel_data_valid(i_pixel_data_valid),
    .proc_finish(proc_finish),
    .o_input_tile_across_all_channel(o_input_tile_across_all_channel),
    .o_ready(o_ready)
);

    PE #(
        .KERNEL_SIZE(KERNEL_SIZE),
        .INPUT_TILE_SIZE(INPUT_TILE_SIZE),
        .INPUT_DATA_WIDTH(INPUT_DATA_WIDTH),
        .KERNEL_DATA_WIDTH(KERNEL_DATA_WIDTH),
        .CHANNELS(CHANNELS)
    ) pe_inst_1(
    .clk(clk),
    .reset(reset),
    .o_valid(o_ready),
    .Kernel(Kernel),
    .inpData(o_input_tile_across_all_channel),
    .outData(outData),
    .finalCompute(finalCompute),
    .finalFlatten(finalFlatten)
    );
    
    
    
    
    
    
    
endmodule
