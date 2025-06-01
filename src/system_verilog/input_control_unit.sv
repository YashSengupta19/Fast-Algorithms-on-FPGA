module line_buffer #(
    parameter int M = 3,        // Number of channels
    parameter int W = 512,      // Width of each Image
    parameter int n = 4,         // Input Tile size
    parameter int m = 2         // Output tiles, which is also the Stride
)(
    input logic                   i_clk,
    input logic                   i_rst,
    input logic [7:0]             i_data,
    input logic                   i_data_valid,
    output logic [M*n*8-1:0]      o_data,
    input logic                   output_needs_to_be_read
);

    // Calculate pointer width based on M*W
    localparam int PNTR_WIDTH = $clog2(M*W);

    // Internal signals
    logic [7:0] line [M*W];       // Line buffer memory
    logic [PNTR_WIDTH-1:0] wrPntr;   // Write pointer
    logic [PNTR_WIDTH-1:0] rdPntr;   // Read pointer

    // Write pointer logic
    always_ff @(posedge i_clk) begin
        if (i_rst)
            wrPntr <= '0;
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
        o_data = '{default: '0}; // Default value
        for (int i = 0; i < M; i++) begin
            for (int j = 0; j < n; j++) begin
                // we are reading n pixels from each channel and storing them in o_data
                // o_data is a 1D array of size M*n*8
                o_data[((M-1-i)*n*8 + (n-1-j)*8) +: 8] = line[i*W + rdPntr + j];
            end
        end
    end

    // Read pointer logic
    always_ff @(posedge i_clk) begin
        if (i_rst)
            rdPntr <= '0;
        else if (output_needs_to_be_read)
            rdPntr <= rdPntr + m;
    end
endmodule

module input_control_unit #(
    parameter int M = 3,        // Number of channels
    parameter int W = 512,      // Width of each Image
    parameter int n = 4         // Input Tile size
)(
    input logic                   i_clk,
    input logic                   i_rst,
    input logic [7:0]             i_pixel_data,
    input logic                   i_pixel_data_valid,
    input logic                   proc_finish,
    output logic [3*4*4*8-1:0]    o_input_tile_across_all_channel,
    output logic                  o_ready
);

    // Circular Buffer's Finite State Machine Implementation
    enum logic [1:0] {
        INIT_STATE = 2'b00,
        STATE1     = 2'b01,
        STATE2     = 2'b10,
        STATE3     = 2'b11
    } current_state, next_state;
        
    // Line buffer selection control
    logic [5:0] lb_fill_sel;      // Which line buffers to fill
    logic [5:0] lb_read_sel;      // Which line buffers to read
        
    // Counters
    logic [19:0] fill_counter;    // Counter for filling line buffers
    logic [19:0] read_counter;    // Counter for reading line buffers
    logic [1:0]  read_cycle;      // Tracks position within read cycle
        
    // Line buffer output signals
    logic [M*n*8-1:0] lb1_data, lb2_data, lb3_data, lb4_data, lb5_data, lb6_data;
    logic lb1_is_ready_to_be_read, lb2_is_ready_to_be_read, lb3_is_ready_to_be_read, 
        lb4_is_ready_to_be_read, lb5_is_ready_to_be_read, lb6_is_ready_to_be_read;
        
    // Pixel routing control
    logic [7:0] pixel_to_lb1, pixel_to_lb2, pixel_to_lb3, pixel_to_lb4, pixel_to_lb5, pixel_to_lb6;
    logic valid_to_lb1, valid_to_lb2, valid_to_lb3, valid_to_lb4, valid_to_lb5, valid_to_lb6;
        
    // Line buffer instantiations
    line_buffer #(
        .M(M),
        .W(W),
        .n(n)
    ) LB1 (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_data(pixel_to_lb1),
        .i_data_valid(valid_to_lb1),
        .o_data(lb1_data),
        .output_needs_to_be_read(lb1_is_ready_to_be_read)
    );
        
    line_buffer #(
        .M(M),
        .W(W),
        .n(n)
    ) LB2 (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_data(pixel_to_lb2),
        .i_data_valid(valid_to_lb2),
        .o_data(lb2_data),
        .output_needs_to_be_read(lb2_is_ready_to_be_read)
    );
        
    line_buffer #(
        .M(M),
        .W(W),
        .n(n)
    ) LB3 (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_data(pixel_to_lb3),
        .i_data_valid(valid_to_lb3),
        .o_data(lb3_data),
        .output_needs_to_be_read(lb3_is_ready_to_be_read)
    );
        
    line_buffer #(
        .M(M),
        .W(W),
        .n(n)
    ) LB4 (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_data(pixel_to_lb4),
        .i_data_valid(valid_to_lb4),
        .o_data(lb4_data),
        .output_needs_to_be_read(lb4_is_ready_to_be_read)
    );
        
    line_buffer #(
        .M(M),
        .W(W),
        .n(n)
    ) LB5 (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_data(pixel_to_lb5),
        .i_data_valid(valid_to_lb5),
        .o_data(lb5_data),
        .output_needs_to_be_read(lb5_is_ready_to_be_read)
    );
        
    line_buffer #(
        .M(M),
        .W(W),
        .n(n)
    ) LB6 (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_data(pixel_to_lb6),
        .i_data_valid(valid_to_lb6),
        .o_data(lb6_data),
        .output_needs_to_be_read(lb6_is_ready_to_be_read)
    );
        
    // State transition logic
    always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst)
            current_state <= INIT_STATE;
        else if (proc_finish)
            current_state <= INIT_STATE;
        else
            current_state <= next_state;
    end
        
    // Next state logic
    always_comb begin
        next_state = current_state;
            
        unique case (current_state)
            INIT_STATE: begin
                if (fill_counter >= (M*W*4 - 1) && i_pixel_data_valid)
                    next_state = STATE1;
            end
                
            STATE1: begin
                if (fill_counter >= (M*W*2 - 1) && i_pixel_data_valid)
                    next_state = STATE2;
            end
                
            STATE2: begin
                if (fill_counter >= (M*W*2 - 1) && i_pixel_data_valid)
                    next_state = STATE3;
            end
                
            STATE3: begin
                if (fill_counter >= (M*W*2 - 1) && i_pixel_data_valid)
                    next_state = STATE1;
            end
        endcase
    end
        
    // Fill counter logic
    always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            fill_counter <= '0;
        end else if (i_pixel_data_valid) begin
            unique case (current_state)
                INIT_STATE: begin
                    if (fill_counter >= (M*W*4 - 1))
                        fill_counter <= '0;
                    else
                        fill_counter <= fill_counter + 1;
                end
                    
                default: begin // STATE1, STATE2, STATE3
                    if (fill_counter >= (M*W*2 - 1))
                        fill_counter <= '0;
                    else
                        fill_counter <= fill_counter + 1;
                end
            endcase
        end
    end
        
    // Read counter logic
    always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            read_counter <= '0;
            read_cycle <= '0;
            o_ready <= '0;
        end else begin
            unique case (current_state)
                INIT_STATE: begin
                    read_counter <= '0;
                    read_cycle <= '0;
                    o_ready <= '0;
                end
                    
                default: begin // STATE1, STATE2, STATE3
                    if (read_cycle == 2'd2) begin
                        read_cycle <= '0;
                        if (read_counter >= (W - n))
                            read_counter <= '0;
                        else
                            read_counter <= read_counter + 1;
                    end else begin
                        read_cycle <= read_cycle + 1;
                    end
                        
                    // Assert o_ready when we've completed a read cycle
                    o_ready <= (read_cycle == 2'd2);
                end
            endcase
        end
    end
        
    // Line buffer selection logic
    always_comb begin
        // Default: no line buffers selected
        lb_fill_sel = 6'b000000;
        lb_read_sel = 6'b000000;
            
        unique case (current_state)
            INIT_STATE: begin
                // Fill LB3, LB4, LB5, LB6 in sequence
                if (fill_counter < M*W)
                    lb_fill_sel = 6'b000100;      // LB3
                else if (fill_counter < 2*M*W)
                    lb_fill_sel = 6'b001000;      // LB4
                else if (fill_counter < 3*M*W)
                    lb_fill_sel = 6'b010000;      // LB5
                else
                    lb_fill_sel = 6'b100000;      // LB6
            end
                
            STATE1: begin
                lb_fill_sel = 6'b000011;          // Fill LB1, LB2
                lb_read_sel = 6'b111100;          // Read LB3, LB4, LB5, LB6
            end
                
            STATE2: begin
                lb_fill_sel = 6'b001100;          // Fill LB3, LB4
                lb_read_sel = 6'b110011;          // Read LB5, LB6, LB1, LB2
            end
                
            STATE3: begin
                lb_fill_sel = 6'b110000;          // Fill LB5, LB6
                lb_read_sel = 6'b001111;          // Read LB1, LB2, LB3, LB4
            end
        endcase
    end
        
    // Pixel routing logic
    always_comb begin
        // Default: no data valid to any line buffer
        valid_to_lb1 = '0;
        valid_to_lb2 = '0;
        valid_to_lb3 = '0;
        valid_to_lb4 = '0;
        valid_to_lb5 = '0;
        valid_to_lb6 = '0;
            
        // Route pixel data to selected line buffers
        pixel_to_lb1 = i_pixel_data;
        pixel_to_lb2 = i_pixel_data;
        pixel_to_lb3 = i_pixel_data;
        pixel_to_lb4 = i_pixel_data;
        pixel_to_lb5 = i_pixel_data;
        pixel_to_lb6 = i_pixel_data;
            
        if (i_pixel_data_valid) begin
            valid_to_lb1 = lb_fill_sel[0];
            valid_to_lb2 = lb_fill_sel[1];
            valid_to_lb3 = lb_fill_sel[2];
            valid_to_lb4 = lb_fill_sel[3];
            valid_to_lb5 = lb_fill_sel[4];
            valid_to_lb6 = lb_fill_sel[5];
        end
    end
        
    // Line buffer read control
    always_comb begin
        // Default: no reads
        lb1_is_ready_to_be_read = '0;
        lb2_is_ready_to_be_read = '0;
        lb3_is_ready_to_be_read = '0;
        lb4_is_ready_to_be_read = '0;
        lb5_is_ready_to_be_read = '0;
        lb6_is_ready_to_be_read = '0;
            
        // Enable reads for selected line buffers during read cycle
        if (current_state != INIT_STATE && read_cycle == 2'd1) begin
            lb1_is_ready_to_be_read = lb_read_sel[0];
            lb2_is_ready_to_be_read = lb_read_sel[1];
            lb3_is_ready_to_be_read = lb_read_sel[2];
            lb4_is_ready_to_be_read = lb_read_sel[3];
            lb5_is_ready_to_be_read = lb_read_sel[4];
            lb6_is_ready_to_be_read = lb_read_sel[5];
        end
    end
        
    // Output tile formation
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            o_input_tile_across_all_channel <= '0;
        end else if (o_ready) begin
            unique case (current_state)
                STATE1: begin
                    o_input_tile_across_all_channel <= {lb3_data, lb4_data, lb5_data, lb6_data};
                end
                    
                STATE2: begin
                    o_input_tile_across_all_channel <= {lb5_data, lb6_data, lb1_data, lb2_data};
                end
                    
                STATE3: begin
                    o_input_tile_across_all_channel <= {lb1_data, lb2_data, lb3_data, lb4_data};
                end
                    
                default: begin
                    o_input_tile_across_all_channel <= '0;
                end
            endcase
        end
    end

endmodule