module line_buffer #(
    parameter int M = 3,        // Number of channels
    parameter int W = 512,      // Width of each Image
    parameter int n = 4,        // Input Tile size
    parameter int m = 2         // Output tiles, which is also the Stride
)(
    input  logic                   i_clk,
    input  logic                   i_rst,
    input  logic [7:0]             i_data,
    input  logic                   i_data_valid,
    output logic [M*n*8-1:0]       o_data,
    input  logic                   output_needs_to_be_read
);

    // we calculate pointer width based on M*W
    localparam int PNTR_WIDTH = $clog2(M * W);

    // Internal signals
    logic [7:0] line [0:M*W-1];      // Line buffer memory
    logic [PNTR_WIDTH-1:0] wrPntr;   // Write pointer
    logic [PNTR_WIDTH-1:0] rdPntr;   // Read pointer
    int i, j;

    // Write pointer logic
    always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst)
            wrPntr <= 0;
        else if (i_data_valid)
            wrPntr <= wrPntr + 1;
    end

    // Write data to line buffer
    always_ff @(posedge i_clk) begin
        if (i_data_valid)
            line[wrPntr] <= i_data;
    end

    // Read data from line buffer
    always_comb begin
        o_data = '0; // Default value
        for (i = 0; i < M; i++) begin
            for (j = 0; j < n; j++) begin
                // We are reading `n` pixels from each channel and storing them in `o_data`
                // `o_data` is a 1D array of size `M*n*8`
                o_data[((M-1-i)*n*8 + (n-1-j)*8) +: 8] = line[i*W + rdPntr + j];
            end
        end
    end

    // Read pointer logic
    always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst)
            rdPntr <= 0;
        else if (output_needs_to_be_read)
            rdPntr <= rdPntr + m;
    end

endmodule
