`timescale 1ns / 1ps


module top_PE_winograd(
    input clk,
    output out_xored
);

    // Parameters
    parameter KERNEL_SIZE = 3;
    parameter INPUT_TILE_SIZE = 4;
    parameter CHANNELS = 3;
    parameter INPUT_DATA_WIDTH = 8;
    parameter KERNEL_DATA_WIDTH = 8;
    
    // Clock generation
    // wire clk;
    // clk_wiz_0 ps_clock_to_pl_clock (
    //     .clk_out1(clk),
    //     .clk_in1_p(clk_p),
    //     .clk_in1_n(clk_n)
    // );

    // BRAM for Input Data (4x4x3 = 48 elements)
    reg [7:0] addra = 0;
    wire [7:0] douta_input;
    blk_mem_gen_input bram_input (
        .clka(clk),
        .ena(1'b1),
        .wea(1'b0),
        .addra(addra),
        .dina(8'b0),
        .douta(douta_input)
    );

    // BRAM for Kernel Data (3x3x3 = 27 elements)
    reg [7:0] addrb_kernel = 0;
    wire [7:0] doutb_kernel;
    blk_mem_gen_kernel bram_kernel (
        .clka(clk),
        .ena(1'b1),
        .wea(1'b0),
        .addra(addrb_kernel),
        .dina(8'b0),
        .douta(doutb_kernel)
    );

    // Data collection registers
    reg [(INPUT_TILE_SIZE*INPUT_TILE_SIZE*INPUT_DATA_WIDTH*CHANNELS)-1:0] flatten_input;
    reg [(KERNEL_SIZE*KERNEL_SIZE*KERNEL_DATA_WIDTH*CHANNELS)-1:0] flatten_kernel;
    
    // Counters
    reg [7:0] input_counter = 0;
    reg [7:0] kernel_counter = 0;
    
    // Control signals
    reg input_ready = 0;
    reg kernel_ready = 0;
    reg conv_start = 0;

    // PE Interface
    wire [(INPUT_TILE_SIZE-KERNEL_SIZE+1)*(INPUT_TILE_SIZE-KERNEL_SIZE+1)*
         (KERNEL_DATA_WIDTH+INPUT_DATA_WIDTH+13)-1:0] pe_outData;
    wire pe_finalCompute;
    wire pe_finalFlatten;
    
    // XOR output
    assign out_xored = ^pe_outData;

    // Input Data Collection (Channel 2 -> 1 -> 0)
    always @(posedge clk) begin
        if (reset) begin
            input_counter <= 0;
            flatten_input <= 0;
            addra <= 0;
            input_ready <= 0;
        end else if (input_counter < INPUT_TILE_SIZE*INPUT_TILE_SIZE*CHANNELS) begin
            // Store in reverse order (LSB last)
            flatten_input[(INPUT_TILE_SIZE*INPUT_TILE_SIZE*CHANNELS*INPUT_DATA_WIDTH-1)-
                         (input_counter*INPUT_DATA_WIDTH) -: INPUT_DATA_WIDTH] <= douta_input;
            addra <= addra + 1;
            input_counter <= input_counter + 1;
            if (input_counter == INPUT_TILE_SIZE*INPUT_TILE_SIZE*CHANNELS-1)
                input_ready <= 1;
        end
    end

    // Kernel Data Collection (Channel 2 -> 1 -> 0)
    always @(posedge clk) begin
        if (reset) begin
            kernel_counter <= 0;
            flatten_kernel <= 0;
            addrb_kernel <= 0;
            kernel_ready <= 0;
        end else if (kernel_counter < KERNEL_SIZE*KERNEL_SIZE*CHANNELS) begin
            // Store in reverse order (LSB last)
            flatten_kernel[(KERNEL_SIZE*KERNEL_SIZE*CHANNELS*KERNEL_DATA_WIDTH-1)-
                          (kernel_counter*KERNEL_DATA_WIDTH) -: KERNEL_DATA_WIDTH] <= doutb_kernel;
            addrb_kernel <= addrb_kernel + 1;
            kernel_counter <= kernel_counter + 1;
            if (kernel_counter == KERNEL_SIZE*KERNEL_SIZE*CHANNELS-1)
                kernel_ready <= 1;
        end
    end

    // Start PE when both inputs are ready
    always @(posedge clk) begin
        conv_start <= input_ready & kernel_ready;
    end

    // PE Instantiation
    PE #(
        .KERNEL_SIZE(KERNEL_SIZE),
        .INPUT_TILE_SIZE(INPUT_TILE_SIZE),
        .INPUT_DATA_WIDTH(INPUT_DATA_WIDTH),
        .KERNEL_DATA_WIDTH(KERNEL_DATA_WIDTH),
        .CHANNELS(CHANNELS)
    ) pe_inst (
        .clk(clk),
        .reset(reset),
        .o_valid(conv_start),
        .Kernel(flatten_kernel),
        .inpData(flatten_input),
        .outData(pe_outData),
        .finalCompute(pe_finalCompute),
        .finalFlatten(pe_finalFlatten)
    );

endmodule