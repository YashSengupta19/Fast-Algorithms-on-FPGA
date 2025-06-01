`timescale 1ns / 1ps

module line_buffer_tb_vivado;

    // Parameters
    parameter int M = 3;
    parameter int W = 512;
    parameter int n = 4;
    // we have to start validating from rdPntr=2
    parameter int m = 2;

    // Calculated parameters
    parameter int DATA_WIDTH = M * n * 8;

    // Signals
    logic clk;
    logic rst;
    logic [7:0] data_in;
    logic data_valid;
    logic [DATA_WIDTH-1:0] data_out;
    logic output_needs_to_be_read;

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
        .output_needs_to_be_read(output_needs_to_be_read)
    );
    
    // Variables for testing
    int wr_ptr;
    int rd_ptr;
    int total_elements;
    int i, j;
    int how_many_reads_to_validate;
    logic continue_reading;
    
    // For output verification
    logic [7:0] expected_data [M*W-1:0];
    logic [DATA_WIDTH-1:0] expected_output;
    
    // Clock generation
    always #5 clk = ~clk; // 10ns period
    
    initial begin
        // Initialize signals
        clk = 1;
        rst = 1;
        data_in = 0;
        data_valid = 0;
        output_needs_to_be_read = 0;
        wr_ptr = 0;
        rd_ptr = 2;
        total_elements = M * W;
        how_many_reads_to_validate = 10; 
        continue_reading = 1;
        
        // Reset for 30ns
        #30;
        rst = 0;
        
        // Fill the line buffer
        $display("Starting to fill the line buffer with %0d elements", total_elements);
        
        // Pre-fill the expected data array
        for (i = 0; i < total_elements; i++)
            expected_data[i] = i % 256;
        
        // Write data into the buffer
        repeat (total_elements) begin
            @(posedge clk);
            data_valid = 1;
            // Values 0-255 repeating
            data_in = wr_ptr % 256; 
            wr_ptr++;
        end
        
        @(posedge clk);
        data_valid = 0;
        $display("Finished filling the line buffer with %0d elements", wr_ptr);
        
        repeat(5) @(posedge clk);
        
        // Read and validate data
        $display("Starting to read and validate data");
        
        continue_reading = 1;
        repeat (W) begin
            if (continue_reading) begin
                @(posedge clk);
                output_needs_to_be_read = 1;
                
                expected_output = '0;
                for (i = 0; i < M; i++) begin
                    for (j = 0; j < n; j++) begin
                        expected_output[((M-1-i)*n*8 + (n-1-j)*8) +: 8] = expected_data[i*W + rd_ptr + j];
                    end
                end
                
                @(posedge clk);
                output_needs_to_be_read = 0;
                
                if (data_out !== expected_output) begin
                    $display("ERROR at rd_ptr=%0d: Expected %h, Got %h", rd_ptr, expected_output, data_out);
                end else begin
                    $display("Validation PASSED at rd_ptr=%0d", rd_ptr);
                end
                
                rd_ptr += m;
                if (rd_ptr >= how_many_reads_to_validate) begin
                    $display("Truncating validation after %0d reads", how_many_reads_to_validate);
                    continue_reading = 0;
                end
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