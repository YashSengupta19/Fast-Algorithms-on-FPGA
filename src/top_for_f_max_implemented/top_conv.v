`timescale 1ns / 1ps

module top_conv(
    input clk,
    output out_xored
);

    // Parameters
    localparam TILE_SIZE = 4;
    localparam KERNEL_SIZE = 3;
    localparam CHANNELS = 3;
    localparam DATA_WIDTH = 8;
    localparam KERNEL_WIDTH = 8;
    localparam INPUT_VECTOR_LENGTH = TILE_SIZE * TILE_SIZE * CHANNELS;
    localparam KERNEL_VECTOR_LENGTH = KERNEL_SIZE * KERNEL_SIZE * CHANNELS;
    localparam OUTPUT_WIDTH = DATA_WIDTH + KERNEL_WIDTH + 4;

    // Clock generation
    // wire clk;
    // clk_wiz_0 ps_clock_to_pl_clock (
    //     .clk_out1(clk),     // output clk_out1
    //     .clk_in1_p(clk_p),  // input clk_in1_p
    //     .clk_in1_n(clk_n)   // input clk_in1_n
    // );

    // BRAM interface signals for input data
    reg [14:0] addra = 0;
    wire [7:0] douta_input;
    reg ena_input = 1;
    reg [0:0] wea_input = 0;

    // BRAM instantiation for input data (4x4x3)
    blk_mem_gen_input bram_input(
        .clka(clk),
        .ena(ena_input),
        .wea(wea_input),
        .addra(addra),
        .dina(8'b0),
        .douta(douta_input)
    );

    // BRAM interface signals for kernel data
    reg [7:0] addrb_kernel = 0;
    wire [7:0] doutb_kernel;
    reg enb_kernel = 1;
    reg [0:0] web_kernel = 0;

    // Single BRAM for kernel data (3x3x3)
    blk_mem_gen_kernel bram_kernel(
        .clka(clk),
        .ena(enb_kernel),
        .wea(web_kernel),
        .addra(addrb_kernel),
        .dina(8'b0),
        .douta(doutb_kernel)
    );

    // Data collection registers
    reg [(INPUT_VECTOR_LENGTH * DATA_WIDTH)-1:0] flatten_input = 0;
    reg [(KERNEL_VECTOR_LENGTH * KERNEL_WIDTH)-1:0] flatten_kernel = 0;
    
    // Counters for data collection
    reg [7:0] input_counter = 0;
    reg [7:0] kernel_counter = 0;
    
    // Control signals
    reg input_ready = 0;
    reg kernel_ready = 0;
    reg conv_start = 0;

    // Convolution output
    wire [OUTPUT_WIDTH-1:0] conv_out;
    wire conv_final_compute;

    // XOR reduction of output
    assign out_xored = ^conv_out;

    // Input data collection (Channel 2 first, then 1, then 0)
    always @(posedge clk) begin
        if (reset) begin
            input_counter <= 0;
            flatten_input <= 0;
            addra <= 0;
            input_ready <= 0;
        end else if (input_counter < INPUT_VECTOR_LENGTH) begin
            // Read from BRAM and build flattened input
            flatten_input[(INPUT_VECTOR_LENGTH-1-input_counter)*DATA_WIDTH +: DATA_WIDTH] <= douta_input;
            addra <= addra + 1;
            input_counter <= input_counter + 1;
            if (input_counter == INPUT_VECTOR_LENGTH-1)
                input_ready <= 1;
        end
    end

    // Kernel data collection (Channel 2 first, then 1, then 0)
    always @(posedge clk) begin
        if (reset) begin
            kernel_counter <= 0;
            flatten_kernel <= 0;
            addrb_kernel <= 0;
            kernel_ready <= 0;
        end else if (kernel_counter < KERNEL_VECTOR_LENGTH) begin
            // Read from kernel BRAM and build flattened kernel
            flatten_kernel[(KERNEL_VECTOR_LENGTH-1-kernel_counter)*KERNEL_WIDTH +: KERNEL_WIDTH] <= doutb_kernel;
            addrb_kernel <= addrb_kernel + 1;
            kernel_counter <= kernel_counter + 1;
            if (kernel_counter == KERNEL_VECTOR_LENGTH-1)
                kernel_ready <= 1;
        end
    end

    // Start convolution when both inputs are ready
    always @(posedge clk) begin
        if (reset) begin
            conv_start <= 0;
        end else begin
            conv_start <= input_ready & kernel_ready;
        end
    end

    // Convolution module instantiation
    conv #(
        .KERNEL_SIZE(KERNEL_SIZE),
        .INPUT_TILE_SIZE(TILE_SIZE),
        .INPUT_DATA_WIDTH(DATA_WIDTH),
        .KERNEL_DATA_WIDTH(KERNEL_WIDTH),
        .CHANNELS(CHANNELS),
    ) conv_inst (
        .clk(clk),
        .reset(reset),
        .conv_start(conv_start),
        .kernel(flatten_kernel),
        .inpData(flatten_input),
        .outData(conv_out),
        .finalCompute(conv_final_compute)
    );

endmodule