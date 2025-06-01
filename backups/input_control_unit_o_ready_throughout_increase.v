module line_buffer #(
    parameter integer M = 3,        // Number of channels
    parameter integer W = 10,       // Width of each Image
    parameter integer n = 4,        // Input Tile size
    parameter integer m = 2         // Output tiles, which is also the Stride
)(
    input                   i_clk,
    input                   i_rst,
    input [7:0]             i_data,
    input                   i_data_valid,
    output reg [M*n*8-1:0] o_data,  
    input                   output_needs_to_be_read,
    output reg finish_reading
);
    // Calculate pointer width based on M*W, 10 in our case
    localparam PNTR_WIDTH = $clog2(M*W);

    // Internal signals
    reg [7:0] line [0:M*W-1];       // Line buffer memory
    reg [PNTR_WIDTH-1:0] wrPntr;   // Write pointer
    reg [PNTR_WIDTH-1:0] rdPntr;   // Read pointer

    integer i,j ;
    // Write pointer logic 
    always @(posedge i_clk) begin
        if (i_rst)
            wrPntr <= 0;
        else if (i_data_valid)
            wrPntr <= wrPntr + 1;
    end

    // Write data to line buffer
    always @(posedge i_clk) begin
        if (i_data_valid)begin
            line[wrPntr] <= i_data;
            $display("Writing %d to LB3[%d] at %0t", i_data, wrPntr, $time);
        end
    end

    // Read data from line buffer
    always @(posedge i_clk) begin
        if(i_rst) begin
            o_data <= {M*n*8{1'b0}}; 
            finish_reading <= 0;
        end else if (output_needs_to_be_read && !finish_reading) begin
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < n; j = j + 1) begin
                    o_data[((M-1-i)*n*8 + (n-1-j)*8) +: 8] <= line[i*W + rdPntr + j];
                end
            end
            // Check if next read would exceed valid region
            if (rdPntr + m + n - 1 >= W)
                finish_reading <= 1;
        end else if (finish_reading) begin
            o_data <= {M*n*8{1'b0}};
            finish_reading <= 0;
        end
end



    // read pointer logic
    always @(posedge i_clk) begin
        if (i_rst)
            rdPntr <= 0;
        else if (output_needs_to_be_read)
            rdPntr <= rdPntr + m;
    end

endmodule


    /*
    The implementation uses a 3-cycle read process:
    First cycle: Prepare for read
    Second cycle: Assert output_needs_to_be_read signals
    Third cycle: Capture data and assert o_ready
    */


module input_control_unit #(
    parameter integer M = 3,        // Number of channels
    parameter integer W = 10,       // Width of each Image
    parameter integer n = 4          // Input Tile size
    )(
    input                    i_clk,
    input                    i_rst,
    input [7:0]              i_pixel_data,
    input                    i_pixel_data_valid,
    input                    proc_finish,
    output reg [3*4*4*8-1:0] o_input_tile_across_all_channel,
    output reg               o_ready
);

    // Circular Buffer's Finite State Machine Implementation
    localparam INIT_STATE = 2'b00;
    localparam STATE1 = 2'b01;
    localparam STATE2 = 2'b10;
    localparam STATE3 = 2'b11;
        
    // State register
    reg [1:0] current_state;
    reg [1:0] next_state;
        
    // Line buffer selection control
    reg [5:0] lb_fill_sel;      // Which line buffers to fill
    reg [5:0] lb_read_sel;      // Which line buffers to read
        
    // Counters
    reg [19:0] fill_counter;    // Counter for filling line buffers
    reg [19:0] read_counter;    // Counter for reading line buffers
    reg [1:0]  read_cycle;      // Tracks position within read cycle
        
    // Line buffer output signals
    wire [M*n*8-1:0] lb1_data, lb2_data, lb3_data, lb4_data, lb5_data, lb6_data;
    reg lb1_is_ready_to_be_read, lb2_is_ready_to_be_read, lb3_is_ready_to_be_read, lb4_is_ready_to_be_read, lb5_is_ready_to_be_read, lb6_is_ready_to_be_read;
        
    // Pixel routing control
    reg [7:0] pixel_to_lb1, pixel_to_lb2, pixel_to_lb3, pixel_to_lb4, pixel_to_lb5, pixel_to_lb6;
    reg valid_to_lb1, valid_to_lb2, valid_to_lb3, valid_to_lb4, valid_to_lb5, valid_to_lb6;
    wire finish_reading_lb1, finish_reading_lb2, finish_reading_lb3, finish_reading_lb4, finish_reading_lb5, finish_reading_lb6;
        
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
        .output_needs_to_be_read(lb1_is_ready_to_be_read),
        .finish_reading(finish_reading_lb1)
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
        .output_needs_to_be_read(lb2_is_ready_to_be_read),
        .finish_reading(finish_reading_lb2)
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
        .output_needs_to_be_read(lb3_is_ready_to_be_read),
        .finish_reading(finish_reading_lb3)
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
        .output_needs_to_be_read(lb4_is_ready_to_be_read),
        .finish_reading(finish_reading_lb4)
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
        .output_needs_to_be_read(lb5_is_ready_to_be_read),
        .finish_reading(finish_reading_lb5)
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
        .output_needs_to_be_read(lb6_is_ready_to_be_read),
        .finish_reading(finish_reading_lb6)
    );
        
    // State transition logic
    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst)
            current_state <= INIT_STATE;
        else if (proc_finish)
            current_state <= INIT_STATE;
        else
            current_state <= next_state;
    end
        
    // Next state logic := PURELY COMBINATORIAL
    always @(*) begin
        next_state = current_state;
        // The primary purpose of the above line is to define the default behavior of this state machine. It says :-
        // "Unless explicitly told to transition to a different state within the case statement, the next state will be the same as the current state."
            
        case (current_state)
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
    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            fill_counter <= 0;
        end else if (i_pixel_data_valid) begin
            case (current_state)
                INIT_STATE: begin
                    if (fill_counter >= (M*W*4 - 1)) begin
                        fill_counter <= 0;
                        // Debug message for testing purposes
                        $display("INIT_STATE complete at time %0t", $time);
                    end else begin
                        fill_counter <= fill_counter + 1;
                    end
                end
                    
                default: begin // STATE1, STATE2, STATE3
                    if (fill_counter >= (M*W*2 - 1)) begin
                        fill_counter <= 0;
                        // Debug message for testing purposes
                        $display("STATE%0d complete at time %0t", current_state, $time);
                    end else begin
                        fill_counter <= fill_counter + 1;
                    end
                end
            endcase
        end
    end


    // Read counter logic
    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            read_counter <= 0;
            read_cycle <= 0;
            o_ready <= 0;
        end else begin
            case (current_state)
                INIT_STATE: begin
                    read_counter <= 0;
                    read_cycle <= 0;
                    o_ready <= 0;
                end
                default: begin // STATE1, STATE2, STATE3
                    if (read_cycle == 2'd2) begin
                        read_cycle <= 0;
                        if (read_counter >= (W - n))
                            read_counter <= 0;
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
    always @(*) begin
        // Default: no line buffers selected
        lb_fill_sel = 6'b000000;
        lb_read_sel = 6'b000000;
            
        case (current_state)
            INIT_STATE: begin
                // Fill LB3, LB4, LB5, LB6 in sequence
                if (fill_counter <= M*W-1)
                    lb_fill_sel = 6'b000100;      // LB3
                else if (fill_counter <= 2*M*W-1)
                    lb_fill_sel = 6'b001000;      // LB4
                else if (fill_counter <= 3*M*W-1)
                    lb_fill_sel = 6'b010000;      // LB5
                else
                    lb_fill_sel = 6'b100000;      // LB6
            end
                
            // Fill LB1, LB2 in sequence ; READ LB3, LB4, LB5, LB6
            STATE1: begin
                if( fill_counter <= M*W-1) lb_fill_sel = 6'b000001;         
                else  lb_fill_sel = 6'b000010;          
                lb_read_sel = 6'b111100;          
            end
            // Fill LB3, LB4 sequentially ;  Read LB5, LB6, LB1, LB2
            STATE2: begin
                if (fill_counter <= M*W-1)  lb_fill_sel = 6'b000100;
                else lb_fill_sel = 6'b001000;      
                lb_read_sel = 6'b110011;          
            end
            // Fill LB5, LB6 sequentially ; // Read LB1, LB2, LB3, LB4
            STATE3: begin
                if (fill_counter <= M*W-1) lb_fill_sel = 6'b010000;      
                else lb_fill_sel = 6'b100000;      
                lb_read_sel = 6'b001111;          
            end
        endcase
    end



    // Pixel routing logic
    always @(*) begin
        // Default: no data valid to any line buffer
        valid_to_lb1 = 1'b0;
        valid_to_lb2 = 1'b0;
        valid_to_lb3 = 1'b0;
        valid_to_lb4 = 1'b0;
        valid_to_lb5 = 1'b0;
        valid_to_lb6 = 1'b0;
    if (i_pixel_data_valid) begin
            pixel_to_lb1 = i_pixel_data;
            pixel_to_lb2 = i_pixel_data;
            pixel_to_lb3 = i_pixel_data;
            pixel_to_lb4 = i_pixel_data;
            pixel_to_lb5 = i_pixel_data;
            pixel_to_lb6 = i_pixel_data;
            valid_to_lb1 = lb_fill_sel[0];
            valid_to_lb2 = lb_fill_sel[1];
            valid_to_lb3 = lb_fill_sel[2];
            valid_to_lb4 = lb_fill_sel[3];
            valid_to_lb5 = lb_fill_sel[4];
            valid_to_lb6 = lb_fill_sel[5];
        end
    end
        
    // Line buffer read control
    always @(*) begin
        // Default: no reads
        lb1_is_ready_to_be_read = 1'b0;
        lb2_is_ready_to_be_read = 1'b0;
        lb3_is_ready_to_be_read = 1'b0;
        lb4_is_ready_to_be_read = 1'b0;
        lb5_is_ready_to_be_read = 1'b0;
        lb6_is_ready_to_be_read = 1'b0;
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

    // // Output tile formation
    // always @(posedge i_clk) begin
    //     if (i_rst) begin
    //         o_input_tile_across_all_channel <= 0;
    //     end else if (o_ready) begin
    //         case (current_state)
    //             // LSB as the first data
    //             STATE1: begin
    //                 o_input_tile_across_all_channel <= {lb6_data, lb5_data, lb4_data, lb3_data};
    //             end
                    
    //             STATE2: begin
    //                 o_input_tile_across_all_channel <= {lb2_data, lb1_data, lb6_data, lb5_data};
    //             end
                    
    //             STATE3: begin
    //                 o_input_tile_across_all_channel <= {lb4_data, lb3_data, lb2_data, lb1_data};
    //             end
                    
    //             default: begin
    //                 o_input_tile_across_all_channel <= 0;
    //             end
    //         endcase
    //     end
    // end

    // Output tile formation
    always @(posedge i_clk) begin
        if (i_rst) begin
            o_input_tile_across_all_channel <= 0;
        end 
        // else if (finish_reading_lb1 || finish_reading_lb2 || finish_reading_lb3 || 
        //         finish_reading_lb4 || finish_reading_lb5 || finish_reading_lb6) begin
        //     // Reset output when reading is finished
        //     o_input_tile_across_all_channel <= 0;
        // end
        else if (o_ready) begin
            case (current_state)
                // STATE1: lb3, lb4, lb5, lb6 
                STATE1: begin
                    o_input_tile_across_all_channel <= {
                        // Channel 2 data (rows 1-4) 
                        lb3_data[95:64], lb4_data[95:64], lb5_data[95:64], lb6_data[95:64],
                        // Channel 1 data (rows 1-4) 
                        lb3_data[63:32], lb4_data[63:32], lb5_data[63:32], lb6_data[63:32],
                        // Channel 0 data (rows 1-4) 
                        lb3_data[31:0], lb4_data[31:0], lb5_data[31:0], lb6_data[31:0]
                    };
                end
                    
                // STATE2:  lb1, lb2, lb5, lb6 
                STATE2: begin
                    o_input_tile_across_all_channel <= {
                        // Channel 2 data (rows 1-4) 
                        lb5_data[95:64], lb6_data[95:64], lb1_data[95:64], lb2_data[95:64],
                        // Channel 1 data (rows 1-4) 
                        lb5_data[63:32], lb6_data[63:32], lb1_data[63:32], lb2_data[63:32],
                        // Channel 0 data (rows 1-4) 
                        lb5_data[31:0], lb6_data[31:0], lb1_data[31:0], lb2_data[31:0]
                    };
                end
                    
                // STATE3:  lb1, lb2, lb3, lb4 
                STATE3: begin
                    o_input_tile_across_all_channel <= {
                        // Channel 2 data (rows 1-4) 
                        lb1_data[95:64], lb2_data[95:64], lb3_data[95:64], lb4_data[95:64],
                        // Channel 1 data (rows 1-4) 
                        lb1_data[63:32], lb2_data[63:32], lb3_data[63:32], lb4_data[63:32],
                        // Channel 0 data (rows 1-4) 
                        lb1_data[31:0], lb2_data[31:0], lb3_data[31:0], lb4_data[31:0]
                    };
                end
                    
                default: begin
                    o_input_tile_across_all_channel <= 0;
                end
            endcase
        end
    end

endmodule