module line_buffer #(
    parameter integer M = 3,        // Number of channels
    parameter integer W = 512,       // Width of each Image
    parameter integer n = 4,          // Input Tile size
    parameter integer m = 2         // Output tiles, which is also the Stride
)(
    input                   i_clk,
    input                   i_rst,
    input  [7:0]            i_data,
    input                   i_data_valid,
    output reg  [M*n*8-1:0] o_data,
    input                   output_needs_to_be_read
);

    // Calculate pointer width based on M*W
    localparam PNTR_WIDTH = $clog2(M*W);

    // Internal signals
    reg [7:0] line [0:M*W-1];       // Line buffer memory
    reg [PNTR_WIDTH-1:0] wrPntr;   // Write pointer
    reg [PNTR_WIDTH-1:0] rdPntr;   // Read pointer
    integer i,j;

    // Write pointer logic
    always @(posedge i_clk) begin
        if (i_rst)
            wrPntr <= 0;
        else if (i_data_valid)
            wrPntr <= wrPntr + 1;
    end


    // Write data to line buffer
    always @(posedge i_clk) begin
        if (i_data_valid)
            line[wrPntr] <= i_data;
    end


    // Read data from line buffer
    always @(*) begin
        o_data = {M*n*8{1'b0}}; // Default value
        for (i = 0; i < M; i = i + 1) begin
            for (j = 0; j < n; j = j + 1) begin
                // we are reading n pixels from each channel and storing them in o_data
                // o_data is a 1D array of size M*n*8
                o_data[((M-1-i)*n*8 + (n-1-j)*8) +: 8] = line[i*W + rdPntr + j];
            end
        end
    end

    // Read pointer logic
    always @(posedge i_clk) begin
        if (i_rst)
            rdPntr <= 0;
        else if (output_needs_to_be_read)
            rdPntr <= rdPntr + m;
    end

endmodule