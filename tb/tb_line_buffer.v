`timescale 1ns / 1ps


module line_buffer_tb_vivado;

    // Parameters
    parameter integer M = 3;
    parameter integer W = 10;
    parameter integer n = 4;
    parameter integer m = 2;

    // Calculated parameters
    parameter integer DATA_WIDTH = M*n*8;

    // Signals
    reg clk;
    reg rst;
    reg [7:0] data_in;
    reg data_valid;
    wire [DATA_WIDTH-1:0] data_out;
    reg output_needs_to_be_read;
    wire finish_reading;

    // Instantiate the Unit Under Test (UUT)
    line_buffer #(
        .M(M),
        .W(W),
        .n(n),
        .m(m)
    ) uut (
        .i_clk(clk),
        .i_rst(rst),
        .i_data(data_in),
        .i_data_valid(data_valid),
        .o_data(data_out),
        .output_needs_to_be_read(output_needs_to_be_read),
        .finish_reading(finish_reading)
    );
    
    
    // Variables for testing
    integer wr_ptr;
    integer rd_ptr;
    integer total_elements;
    integer i, j;
    integer how_many_reads_to_validate;
    reg continue_reading;
    
    // For output verification
    reg [7:0] expected_data [0:M*W-1];
    reg [DATA_WIDTH-1:0] expected_output;
    
    // For memory viewing assistance
    // THESE ARE MY MAGNIFYING GLASSES FOR 
    // viewing specific memory locations of REALLY BIG MEMORY (line buffer)

    reg [7:0] mem_channel_0___0;
    reg [7:0] mem_channel_0___1;
    reg [7:0] mem_channel_0___2;
    reg [7:0] mem_channel_0___3;

    reg [7:0] mem_channel_1___0;
    reg [7:0] mem_channel_1___1;
    reg [7:0] mem_channel_1___2;
    reg [7:0] mem_channel_1___3;

    reg [7:0] mem_channel_2___0;
    reg [7:0] mem_channel_2___1;
    reg [7:0] mem_channel_2___2;
    reg [7:0] mem_channel_2___3;

    // Clock generation
    always #5 clk = ~clk; // 10ns period

    // Update these signals for waveform viewing
    always @(*) begin
        mem_channel_0___0 <= uut.line[0];
        mem_channel_0___1 <= uut.line[1];
        mem_channel_0___2 <= uut.line[2];
        mem_channel_0___3 <= uut.line[3];

        mem_channel_1___0 <= uut.line[W + 0];
        mem_channel_1___1 <= uut.line[W + 1];
        mem_channel_1___2 <= uut.line[W + 2];
        mem_channel_1___3 <= uut.line[W + 3];

        mem_channel_2___0 <= uut.line[2*W + 0];
        mem_channel_2___1 <= uut.line[2*W + 1];
        mem_channel_2___2 <= uut.line[2*W + 2];
        mem_channel_2___3 <= uut.line[2*W + 3];
    end
    
    initial begin
        // Initialize signals
        clk = 1;
        rst = 1;
        data_in = 0;
        data_valid = 0;
        output_needs_to_be_read = 0;
        wr_ptr = 0;
        rd_ptr = 0;
        total_elements = M * W;

        // We'll validate 10 reads
        how_many_reads_to_validate = 10; 
        continue_reading = 1;
        
        // Reset for 30ns
        #30;
        rst = 0;
        
        // Fill the line buffer
        $display("Starting to fill the line buffer with %0d elements", total_elements);
        
        // Pre-fill the expected data array
        for (i = total_elements; i >= 0; i = i - 1) begin
            expected_data[i] = i % 256;
        end
        
        // Write data into the buffer
        repeat (total_elements) begin
            @(posedge clk);
            data_valid = 1;
            // Values 0-255 repeating
            data_in = wr_ptr % 256; 
            wr_ptr = wr_ptr + 1;
        end
        
        // wait for the last write to complete
        @(posedge clk); 

        data_valid = 0;
        $display("Finished filling the line buffer with %0d elements", wr_ptr);
        
        // Wait a few clock cycles
        repeat(5) @(posedge clk);
        // Read and validate data
        $display("Starting to read and validate data");
        continue_reading = 1;
        repeat (W) begin
            if (continue_reading && !finish_reading) begin
                // Assert read enable
                @(posedge clk);
                output_needs_to_be_read = 1;
                // Prepare expected_output in advance
                expected_output = 0;
                for (i = 0; i < M; i = i + 1) begin
                    for (j = 0; j < n; j = j + 1) begin
                        expected_output[((M-1-i)*n*8 + (n-1-j)*8) +: 8] = expected_data[i*W + rd_ptr + j];
                    end
                end
                // Wait one clock to allow DUT to respond
                @(posedge clk);
                output_needs_to_be_read = 0;
                // Compare output now
                if (data_out !== expected_output) begin
                    $display("ERROR at rd_ptr=%0d: Expected %h, Got %h", rd_ptr, expected_output, data_out);
                end else begin
                    $display("Validation PASSED at rd_ptr=%0d", rd_ptr);
                end
                rd_ptr = rd_ptr + m;
                if (rd_ptr + n - 1 >= W) begin
                    $display("Truncating validation after final possible read");
                    continue_reading = 0;
                end
            end
            else  begin 
                expected_output = {M*n*8{1'b0}};
            end
        end 

        #100;
        $display("Testbench completed");
        $finish;
    end
    
    // Monitor for debug
    initial begin
        $monitor("Time=%0t, Reset=%b, WrPtr=%0d, RdPtr=%0d, Data_Valid=%b, output_needs_to_be_read=%b", 
                    $time, rst, uut.wrPntr, uut.rdPntr, data_valid, output_needs_to_be_read);
    end

endmodule