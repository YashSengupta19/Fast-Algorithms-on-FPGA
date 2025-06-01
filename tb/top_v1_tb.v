`timescale 1ns / 1ps

module top_v1_tb;

  // Parameters
  parameter KERNEL_SIZE       = 3;
  parameter INPUT_IMAGE_WIDTH = 10;
  parameter INPUT_TILE_SIZE   = 4;
  parameter INPUT_DATA_WIDTH  = 8;
  parameter KERNEL_DATA_WIDTH = 8;
  parameter CHANNELS          = 3;

  // Clock and reset
  reg clk;
  reg reset;

  // Inputs
  reg [INPUT_DATA_WIDTH-1:0] i_pixel_data;
  reg                        i_pixel_data_valid;
  reg signed [(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * CHANNELS) - 1 : 0] Kernel;

  // Outputs
  wire signed[(INPUT_TILE_SIZE - KERNEL_SIZE + 1) * (INPUT_TILE_SIZE - KERNEL_SIZE + 1) * (KERNEL_DATA_WIDTH + INPUT_DATA_WIDTH + 13) - 1 : 0] outData;

  // Instantiate the module
  top_v1 #(
    .KERNEL_SIZE(KERNEL_SIZE),
    .INPUT_IMAGE_WIDTH(INPUT_IMAGE_WIDTH),
    .INPUT_TILE_SIZE(INPUT_TILE_SIZE),
    .INPUT_DATA_WIDTH(INPUT_DATA_WIDTH),
    .KERNEL_DATA_WIDTH(KERNEL_DATA_WIDTH),
    .CHANNELS(CHANNELS)
  ) dut (
    .clk(clk),
    .reset(reset),
    .i_pixel_data(i_pixel_data),
    .i_pixel_data_valid(i_pixel_data_valid),
    .Kernel(Kernel),
    .outData(outData)
  );

  // Clock generation
  initial clk = 1;
  always #5 clk = ~clk; // 100MHz clock

  // Test logic
  integer i;
  initial begin
    // Initial values
    reset = 1;
    i_pixel_data = 0;
    i_pixel_data_valid = 0;
    Kernel = 0;

    // Apply reset
    #20;
    reset = 0;

    // Assign kernel (example: all ones)
    Kernel = {((KERNEL_SIZE * KERNEL_SIZE * CHANNELS)){8'sd1}};

    // Feed input pixel data stream (simulate CHANNELS * TILE_SIZE * TILE_SIZE)
    for (i = 0; i < CHANNELS * INPUT_IMAGE_WIDTH *INPUT_IMAGE_WIDTH * 6  ; i = i + 1) begin
      @(posedge clk);
      i_pixel_data <= i[7:0] % 256; // send incremental pixel data
      i_pixel_data_valid <= 1;
    end

    // Stop sending data
    @(posedge clk);
    i_pixel_data_valid <= 0;

    // Wait for processing
    #100;

    // Observe output (manually or with assertions)
    $display("Output data: %h", outData);

    // Finish simulation
    // $finish;
  end

endmodule
