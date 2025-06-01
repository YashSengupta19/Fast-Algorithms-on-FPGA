    `timescale 1ns / 1ps


module top_v2#(
    parameter KERNEL_SIZE       = 3,
              INPUT_IMAGE_WIDTH = 10,
              INPUT_TILE_SIZE   = 4,
              INPUT_DATA_WIDTH  = 8,
              KERNEL_DATA_WIDTH = 8,
              CHANNELS          = 3
)(
    input clk,
    input reset,
    
    output comb_output
    
//    input [7:0]              i_pixel_data,
//    input                    i_pixel_data_valid,
    // input signed [(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * CHANNELS) - 1 : 0] Kernel,
    
//    input                    proc_finish,  My guess is this is the finalCompute / finalFlatten Signal
//    output reg [3*4*4*8-1:0] o_input_tile_across_all_channel,  This signal is also an input to PE
//    output reg               o_ready  This signal will go to PE to define that output is valid 
);
    // Local params
    localparam TOTAL_WIDTH = (INPUT_TILE_SIZE - KERNEL_SIZE + 1) * (INPUT_TILE_SIZE - KERNEL_SIZE + 1) * (KERNEL_DATA_WIDTH + INPUT_DATA_WIDTH + 12);
// Declaring registers
//    reg               proc_finish;
    wire [(CHANNELS * INPUT_TILE_SIZE * INPUT_TILE_SIZE * INPUT_DATA_WIDTH)-1:0] o_input_tile_across_all_channel;
    wire               o_ready;
    
    // PE Output Signals to be used in input interface
    wire finalCompute[2:0];
    wire finalFlatten[2:0];
    wire proc_finish;
    
    wire signed[(INPUT_TILE_SIZE - KERNEL_SIZE + 1) * (INPUT_TILE_SIZE - KERNEL_SIZE + 1) * (KERNEL_DATA_WIDTH + INPUT_DATA_WIDTH + 12) - 1 : 0] outData[2:0];
    
    
    
    // BRAM interface signals
    reg [14:0] addra = 0;
    wire [7:0] douta;
    reg ena = 0;
    reg [0:0] wea = 0;
    reg [7:0] dina = 0;
    
    
    // Pixel data signals
    reg [7:0] i_pixel_data;
    reg i_pixel_data_valid = 0;
    reg [1:0] init_counter = 0;
    
    // BRAM instantiation
    blk_mem_gen_TOP bram_INPUTs (
      .clka(clk),
      .ena(ena),
      .wea(wea),
      .addra(addra),
      .dina(dina),
      .douta(douta)
    );
    
    // BRAM read and data passing logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            addra <= 0;
            ena <= 0;
            i_pixel_data <= 0;
            i_pixel_data_valid <= 0;
            init_counter <= 0;
        end
        else begin
            // Enable BRAM read operation
            ena <= 1;
            wea <= 0;
            
            // Handle initial 2-cycle delay
            if (init_counter < 2) begin
                init_counter <= init_counter + 1;
                i_pixel_data_valid <= 0;
            end
            else begin
                // After delay, read data continuously
                i_pixel_data <= douta;
                i_pixel_data_valid <= 1;
                
                // Increment address for next read
                if (addra < 15'h7FFF) begin
                    addra <= addra + 1;
                end
            end
        end
    end

    reg [(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * CHANNELS) - 1 : 0] Kernel_1;
    reg [(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * CHANNELS) - 1 : 0] Kernel_2;
    reg [(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * CHANNELS) - 1 : 0] Kernel_3;      
    
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
    ) pe_inst_0 (
        .clk(clk),
        .reset(reset),
        .o_valid(o_ready),
        .Kernel(Kernel_1),
        .inpData(o_input_tile_across_all_channel),
        .outData(outData[0]),
        .finalCompute(finalCompute[0]),
        .finalFlatten(finalFlatten[0])
        );
    PE #(
        .KERNEL_SIZE(KERNEL_SIZE),
        .INPUT_TILE_SIZE(INPUT_TILE_SIZE),
        .INPUT_DATA_WIDTH(INPUT_DATA_WIDTH),
        .KERNEL_DATA_WIDTH(KERNEL_DATA_WIDTH),
        .CHANNELS(CHANNELS)
    ) pe_inst_1 (
    .clk(clk),
    .reset(reset),
    .o_valid(o_ready),
    .Kernel(Kernel_2),
    .inpData(o_input_tile_across_all_channel),
    .outData(outData[1]),
    .finalCompute(finalCompute[1]),
    .finalFlatten(finalFlatten[1])
    );
    
    PE #(
        .KERNEL_SIZE(KERNEL_SIZE),
        .INPUT_TILE_SIZE(INPUT_TILE_SIZE),
        .INPUT_DATA_WIDTH(INPUT_DATA_WIDTH),
        .KERNEL_DATA_WIDTH(KERNEL_DATA_WIDTH),
        .CHANNELS(CHANNELS)
    ) pe_inst_2 (
    .clk(clk),
    .reset(reset),
    .o_valid(o_ready),
    .Kernel(Kernel_3),
    .inpData(o_input_tile_across_all_channel),
    .outData(outData[2]),
    .finalCompute(finalCompute[2]),
    .finalFlatten(finalFlatten[2])
    );

    
    // BRAM signals
    reg bram_en;
    localparam BRAM_ADDR_WIDTH = $clog2(KERNEL_SIZE * KERNEL_SIZE * CHANNELS);
    reg [BRAM_ADDR_WIDTH-1:0] bram_addr;
    wire [KERNEL_DATA_WIDTH-1:0] bram_data_out_1;
    wire [KERNEL_DATA_WIDTH-1:0] bram_data_out_2;
    wire [KERNEL_DATA_WIDTH-1:0] bram_data_out_3;

    // Instantiate BRAMs for each kernel
//    block_mem_gen_kernel_1 bram_kernel_1 (
//        .clka(clk),    
//        .ena(bram_en),      
//        .wea(wea),      
//        .addra(bram_addr),  
//        .dina(dina),    
//        .douta(bram_data_out_1)  
//    );
    
        blk_mem_gen_kernel_1 bram_kernel_1 (
         .clka(clk),    
        .ena(bram_en),      
        .wea(wea),      
        .addra(bram_addr),  
        .dina(dina),    
        .douta(bram_data_out_1)  
    );
    blk_mem_gen_kernel_2 bram_kernel_2 (
        .clka(clk),    
        .ena(bram_en),      
        .wea(wea),      
        .addra(bram_addr),  
        .dina(dina),    
        .douta(bram_data_out_2)  
    );
    // Instantiate BRAMs for each kernel
    blk_mem_gen_kernel_3 bram_kernel_3 (
        .clka(clk),    
        .ena(bram_en),      
        .wea(wea),      
        .addra(bram_addr),  
        .dina(dina),    
        .douta(bram_data_out_3)  
    );

    localparam KERNEL_ELEMENTS = KERNEL_SIZE * KERNEL_SIZE * CHANNELS;
    localparam IDLE = 2'd0;
    localparam LOADING = 2'd1;
    localparam DONE = 2'd2;
    
    // State machine registers
    reg [1:0] state;
    reg load_done;
    
    
    // Temp registers to build the kernels
    reg [(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * CHANNELS) - 1 : 0] kernel_1_temp;
    reg [(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * CHANNELS) - 1 : 0] kernel_2_temp;
    reg [(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * CHANNELS) - 1 : 0] kernel_3_temp;
    
    // State machine for loading kernels from BRAMs
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            bram_addr <= 0;
            bram_en <= 0;
            load_done <= 0;
            kernel_1_temp <= 0;
            kernel_2_temp <= 0;
            kernel_3_temp <= 0;
            Kernel_1 <= 0;
            Kernel_2 <= 0;
            Kernel_3 <= 0;
        end else begin
            case (state)
                IDLE: begin
                    bram_en <= 1;
                    state <= LOADING;
                    bram_addr <= 0;
                end
                
                LOADING: begin
                    kernel_1_temp <= {kernel_1_temp[(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * CHANNELS) - KERNEL_DATA_WIDTH - 1:0], bram_data_out_1};
                    kernel_2_temp <= {kernel_2_temp[(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * CHANNELS) - KERNEL_DATA_WIDTH - 1:0], bram_data_out_2};
                    kernel_3_temp <= {kernel_3_temp[(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * CHANNELS) - KERNEL_DATA_WIDTH - 1:0], bram_data_out_3};
                    
                    // Increment address
                    if (bram_addr == KERNEL_ELEMENTS - 1) begin
                        state <= DONE;
                        bram_en <= 0;
                    end else begin
                        bram_addr <= bram_addr + 1;
                    end
                end
                
                DONE: begin
                    // Transfer completed kernel data to output
                    Kernel_1 <= kernel_1_temp;
                    Kernel_2 <= kernel_2_temp;
                    Kernel_3 <= kernel_3_temp;
                    load_done <= 1;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    wire [(TOTAL_WIDTH*3)-1:0] outData_flat;
    genvar i;
    generate
        for (i = 0; i < 3; i = i + 1) begin : FLATTEN
            assign outData_flat[(i+1)*TOTAL_WIDTH-1 : i*TOTAL_WIDTH] = outData[i];
        end
    endgenerate
    
//    wire xor_reduced;
    assign comb_output = ^outData_flat;  // Bitwise XOR reduction




endmodule
