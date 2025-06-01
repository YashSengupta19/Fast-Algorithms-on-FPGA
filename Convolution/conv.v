`timescale 1ns / 1ps

module conv #(
	parameter KERNEL_SIZE = 3,
	INPUT_TILE_SIZE = 4,
	INPUT_DATA_WIDTH = 8,
	KERNEL_DATA_WIDTH = 8,
	CHANNELS = 3
)(
	input clk,
	input reset,
	input signed [(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * CHANNELS) - 1 : 0] kernel,
	input signed [((INPUT_TILE_SIZE) * (INPUT_TILE_SIZE) * (INPUT_DATA_WIDTH) *(CHANNELS)) - 1 : 0] inpData,
	output reg signed[ (INPUT_TILE_SIZE - KERNEL_SIZE + 1) * (INPUT_TILE_SIZE - KERNEL_SIZE + 1) * (INPUT_DATA_WIDTH + KERNEL_DATA_WIDTH + 8) - 1 : 0] outData,
	output reg finalCompute
);

// Compute Dimensions
localparam OUTPUT_TILE_SIZE = INPUT_TILE_SIZE - KERNEL_SIZE + 1;
localparam OUTPUT_BIT_WIDTH = INPUT_DATA_WIDTH + KERNEL_DATA_WIDTH + 8;
// Internal 3D Representation
reg signed [INPUT_DATA_WIDTH - 1 : 0] input_tile [0 : CHANNELS -1][0 : INPUT_TILE_SIZE - 1][0 : INPUT_TILE_SIZE - 1];
reg signed [KERNEL_DATA_WIDTH - 1 : 0] kernel_tile [0 : CHANNELS - 1][0 : KERNEL_SIZE - 1][0 : KERNEL_SIZE - 1];
reg signed [OUTPUT_BIT_WIDTH - 1 : 0] conv_result [0 : OUTPUT_TILE_SIZE - 1][0 : OUTPUT_TILE_SIZE - 1];

integer c, i, j, m, n;
integer input_index = 0;
integer out_index = 0;
integer kernel_index = 0;


always @(posedge clk)
begin
	if (reset) begin
		finalCompute <= 0;
		outData <= 0;
	end

	else begin
		// Unpack Input data
		input_index = 0;
		for(c = 0; c < CHANNELS; c = c + 1)begin
			for(i=0; i<INPUT_TILE_SIZE; i=i+1)begin
				for(j=0; j<INPUT_TILE_SIZE; j=j+1)begin
					input_tile[c][i][j] = inpData[input_index +: INPUT_DATA_WIDTH];
					input_index = input_index + INPUT_DATA_WIDTH;
				end
			end
		end

		// Unpack Kernel
		kernel_index = 0;
		for(c=0; c<CHANNELS; c=c+1)begin
			for(i=0; i<KERNEL_SIZE; i=i+1)begin
				for(j=0; j<KERNEL_SIZE; j=j+1)begin
					kernel_tile[c][i][j] = kernel[kernel_index +: KERNEL_DATA_WIDTH];
					kernel_index = kernel_index + KERNEL_DATA_WIDTH;
				end
			end
		end

		//Perform Convolution
		for(i=0; i<OUTPUT_TILE_SIZE; i=i+1)begin
			for(j=0; j<OUTPUT_TILE_SIZE; j=j+1)begin
				conv_result[i][j] = 0;
				for(c=0 ; c<CHANNELS; c=c+1)begin
					for(m=0; m<KERNEL_SIZE; m=m+1)begin
						for(n=0; n<KERNEL_SIZE; n=n+1)begin
							conv_result[i][j] = conv_result[i][j] + input_tile[c][i+m][j+n] * kernel_tile[c][m][n];
						end
					end
				end
			end
		end

		// Flatten Output Result
		out_index = 0;
		for(i=0; i<OUTPUT_TILE_SIZE; i=i+1)begin
			for(j=0; j<OUTPUT_TILE_SIZE; j=j+1)begin
				outData[out_index +: OUTPUT_BIT_WIDTH] = conv_result[i][j];
				out_index = out_index + OUTPUT_BIT_WIDTH;
			end
		end

		finalCompute <= 1;
	end

end



endmodule

