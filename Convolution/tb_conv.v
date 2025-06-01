`timescale 1ns / 1ps

module tb_conv;

parameter KERNEL_SIZE = 3;
parameter INPUT_TILE_SIZE = 4;
parameter INPUT_DATA_WIDTH = 8;
parameter KERNEL_DATA_WIDTH = 8;
parameter CHANNELS = 3;
parameter OUTPUT_BIT_WIDTH = INPUT_DATA_WIDTH + KERNEL_DATA_WIDTH + 8;
parameter OUTPUT_TILE_SIZE = INPUT_TILE_SIZE - KERNEL_SIZE + 1;

reg clk;
reg reset;
reg signed [(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * CHANNELS) - 1 : 0] kernel;
reg signed [(INPUT_TILE_SIZE * INPUT_TILE_SIZE * INPUT_DATA_WIDTH * CHANNELS) - 1 : 0] inpData;
wire signed [(OUTPUT_TILE_SIZE * OUTPUT_TILE_SIZE * OUTPUT_BIT_WIDTH) - 1 : 0] outData;
wire finalCompute;

always begin
    #5 clk = ~clk;
end

conv #(
    .KERNEL_SIZE(KERNEL_SIZE),
    .INPUT_TILE_SIZE(INPUT_TILE_SIZE),
    .INPUT_DATA_WIDTH(INPUT_DATA_WIDTH),
    .KERNEL_DATA_WIDTH(KERNEL_DATA_WIDTH),
    .CHANNELS(CHANNELS)
) uut (
    .clk(clk),
    .reset(reset),
    .kernel(kernel),
    .inpData(inpData),
    .outData(outData),
    .finalCompute(finalCompute)
);

initial begin
    clk = 0;
    reset = 0;
    kernel = 0;
    inpData = 0;

    reset = 1;
    #10;
    reset = 0;

    kernel = {
        // Channel 2
        8'sd8, 8'sd0, 8'sd8,
        8'sd0, 8'sd8, 8'sd0,
        8'sd8, 8'sd0, 8'sd8,

        // Channel 1
        8'sd8, 8'sd8, 8'sd16,
        8'sd8, 8'sd8, 8'sd16,
        8'sd8, 8'sd8, 8'sd16,

        // Channel 0
        8'sd8, 8'sd0, 8'sd0,
        8'sd0, 8'sd8, 8'sd0,
        8'sd0, 8'sd0, 8'sd8
    };

    inpData = {
        // Channel 2
        8'sd1, 8'sd2, 8'sd3, 8'sd4,
        8'sd5, 8'sd6, 8'sd7, 8'sd8,
        8'sd9, 8'sd10, 8'sd11, 8'sd12,
        8'sd13, 8'sd14, 8'sd15, 8'sd16,

	//CHANNEL 1
        8'sd1, 8'sd1, 8'sd1, 8'sd1,
        8'sd1, 8'sd1, 8'sd1, 8'sd1,
        8'sd1, 8'sd1, 8'sd1, 8'sd1,
        8'sd1, 8'sd1, 8'sd1, 8'sd1,

	//CHANNEL 0
        8'sd1, 8'sd2, 8'sd3, 8'sd4,
        -8'sd1, -8'sd2, -8'sd3, -8'sd4,
        8'sd1, -8'sd2, 8'sd3, -8'sd4,
        8'sd0, 8'sd0, 8'sd0, -8'sd1
    };

    wait (finalCompute == 1);
    #10;

    reset = 1;
    #10;
    reset = 0;

    inpData = {
        // Channel 2
        8'sd2, 8'sd2, 8'sd2, 8'sd2,
        8'sd2, 8'sd2, 8'sd2, 8'sd2,
        8'sd2, 8'sd2, 8'sd2, 8'sd2,
        8'sd2, 8'sd2, 8'sd2, 8'sd2,

        // Channel 1
        8'sd3, 8'sd3, 8'sd3, 8'sd3,
        8'sd3, 8'sd3, 8'sd3, 8'sd3,
        8'sd3, 8'sd3, 8'sd3, 8'sd3,
        8'sd3, 8'sd3, 8'sd3, 8'sd3,

        // Channel 0
        8'sd4, 8'sd4, 8'sd4, 8'sd4,
        8'sd4, 8'sd4, 8'sd4, 8'sd4,
        8'sd4, 8'sd4, 8'sd4, 8'sd4,
        8'sd4, 8'sd4, 8'sd4, 8'sd4
    };

    wait (finalCompute == 1);
    #10;

    $finish;
end

initial begin
	$dumpfile("waveform.vcd");
	$dumpvars(0,tb_conv);

    $monitor("At time %t, outData = %h, finalCompute = %b", $time, outData, finalCompute);
end

endmodule

