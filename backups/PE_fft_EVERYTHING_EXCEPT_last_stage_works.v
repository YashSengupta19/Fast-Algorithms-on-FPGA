module PE_fft #(
    parameter KERNEL_SIZE = 3,
    INPUT_TILE_SIZE = 4,
    INPUT_DATA_WIDTH = 8,
    KERNEL_DATA_WIDTH = 8,
    CHANNELS = 3
)(
    // Global Signals
    input clk,
    input reset,
    
    // Kernel Loading
    input signed [(KERNEL_SIZE*KERNEL_SIZE*KERNEL_DATA_WIDTH*CHANNELS)-1:0] Kernel,
    
    // Input Loading
    input signed [(INPUT_TILE_SIZE*INPUT_TILE_SIZE*INPUT_DATA_WIDTH*CHANNELS)-1:0] inpData,
    
    // Output
    output reg signed [(INPUT_TILE_SIZE-KERNEL_SIZE+1)*(INPUT_TILE_SIZE-KERNEL_SIZE+1)*(KERNEL_DATA_WIDTH+INPUT_DATA_WIDTH+13)-1:0] outData,
    output reg finalCompute
);

    // ==========================================================================================
    // Local Parameters and Bit Width Calculations
    // ==========================================================================================

    // FFT matrix is fixed for 4x4 with values -1, 0, +1
    localparam FFT_COEFF_WIDTH = 2; // Enough to represent -1,0,+1

    // Bit growth calculations
    localparam ROW_FFT_REAL_WIDTH = INPUT_DATA_WIDTH + 3;// Max 4 additions (1+1+1+1)
    localparam ROW_FFT_IMG_WIDTH = INPUT_DATA_WIDTH + 3; //Same as real part
    localparam COL_FFT_REAL_WIDTH = ROW_FFT_REAL_WIDTH + 3; // Coumn FFT adds more terms
    localparam COL_FFT_IMG_WIDTH = ROW_FFT_IMG_WIDTH + 3;

    localparam KERNEL_ROW_FFT_REAL_WIDTH = KERNEL_DATA_WIDTH + 2; // Max 3 additions ( 1 + 1 + 1 + 0) We zero pad kernel to the size of Input
    localparam KERNEL_ROW_FFT_IMG_WIDTH = KERNEL_DATA_WIDTH + 2;

    localparam KERNEL_COL_FFT_REAL_WIDTH = KERNEL_ROW_FFT_REAL_WIDTH + 2;
    localparam KERNEL_COL_FFT_IMG_WIDTH = KERNEL_ROW_FFT_IMG_WIDTH + 2;

    // Element-wise multiplication
    localparam EWMM_REAL_WIDTH = COL_FFT_REAL_WIDTH + KERNEL_COL_FFT_REAL_WIDTH + 1;
    localparam EWMM_IMG_WIDTH = COL_FFT_IMG_WIDTH + KERNEL_COL_FFT_IMG_WIDTH + 1;

    // Inverse FFT
    localparam IFFT_REAL_WIDTH = EWMM_REAL_WIDTH + 2;
    localparam IFFT_IMG_WIDTH = EWMM_IMG_WIDTH + 2;

    // Final output after cropping and accumulation
    localparam OUTPUT_WIDTH = IFFT_REAL_WIDTH + $clog2(CHANNELS);

    // ==========================================================================================
    // Hardcoded FFT Matrices
    // ==========================================================================================

    // FFT matrices for 4-point transform
    wire signed [FFT_COEFF_WIDTH-1:0] fft_real [0:3][0:3];
    wire signed [FFT_COEFF_WIDTH-1:0] fft_img [0:3][0:3];
    wire signed [FFT_COEFF_WIDTH-1:0] ifft_img [0:3][0:3];

    /*  fft_real
    [ 
        [1,  1,  1,  1],
        [1,  0, -1, 0],
        [1, -1,  1, -1],
        [1,  0, -1, 0]
    ]

    fft_img 
    [
        [0,  0,  0,  0],
        [0, -1,  0, +1],
        [0,  0,  0,  0],
        [0, +1,  0, -1]
    ] */



    // Initialize FFT matrices (synthesizable initialization, REALLY convoluted but cool trick )
    // the IFFT matrix is the Hermitian transpose of the FFT matrix divided by 4 ; so we use the same fft_real matrix, and we just change signs of img matrix 
    generate
        genvar row, col;
        for (row = 0; row < 4; row = row + 1) begin : fft_real_init
            for (col = 0; col < 4; col = col + 1) begin : fft_real_col
                assign fft_real[row][col] = 
                    (row == 0) ? 2'b01 :                                                      // +1 for all col in row 0
                    (row == 1) ? (col == 1 || col == 3) ? 2'b00 : (col == 0) ? 2'b01 : 2'b11 :      // +1, 0, -1, 0
                    (row == 2) ? (col % 2 == 0) ? 2'b01 : 2'b11 :                               // +1, -1, +1, -1
                    (col == 1 || col == 3) ? 2'b00 : (col == 0) ? 2'b01 : 2'b11;                  // +1, 0, -1, 0 for row 3
            end
        end
        
        for (row = 0; row < 4; row = row + 1) begin : fft_img_init
            for (col = 0; col < 4; col = col + 1) begin : fft_img_col
                assign fft_img[row][col] = 
                    (row == 0) ? 2'b00 :                                                      // 0 for all col in row 0
                    (row == 1) ? (col == 0 || col == 2) ? 2'b00 : (col == 1) ? 2'b11 : 2'b01 :      // 0, -1, 0, +1
                    (row == 2) ? 2'b00 :                                                      // 0 for all col in row 2
                    (col == 0 || col == 2) ? 2'b00 : (col == 1) ? 2'b01 : 2'b11;                  // 0, +1, 0, -1 for row 3
            end
        end

        for (row = 0; row < 4; row = row + 1) begin : ifft_img_init
            for (col = 0; col < 4; col = col + 1) begin : ifft_img_col
                assign ifft_img[row][col] = 
                    (row == 0) ? 2'b00 :                                                      // 0 for all col in row 0
                    (row == 1) ? (col == 0 || col == 2) ? 2'b00 : (col == 1) ? 2'b01 : 2'b11 :      // 0, -1, 0, +1
                    (row == 2) ? 2'b00 :                                                      // 0 for all col in row 2
                    (col == 0 || col == 2) ? 2'b00 : (col == 1) ? 2'b11 : 2'b01;                  // 0, +1, 0, -1 for row 3
            end
        end

    endgenerate

    // =============================================
    // Data Registers
    // =============================================

    // Input and kernel storage
    reg signed [INPUT_DATA_WIDTH-1:0] input_tile [CHANNELS-1:0][INPUT_TILE_SIZE-1:0][INPUT_TILE_SIZE-1:0];
    reg signed [KERNEL_DATA_WIDTH-1:0] kernel [CHANNELS-1:0][KERNEL_SIZE-1:0][KERNEL_SIZE-1:0];
    reg signed [KERNEL_DATA_WIDTH-1:0] padded_kernel [CHANNELS-1:0][INPUT_TILE_SIZE-1:0][INPUT_TILE_SIZE-1:0];

    // FFT intermediate results

    // By using hermitian symmetry, we can reduce the dimensions of the intermediate matrices by HALF+1  ( 4 --> 4/2 + 1 = 3 )
    // We reduce the size of the FFT matrices to 3x4

    reg signed [ROW_FFT_REAL_WIDTH-1:0] row_fft_real [CHANNELS-1:0][INPUT_TILE_SIZE-1:0][INPUT_TILE_SIZE-1:0];
    reg signed [ROW_FFT_IMG_WIDTH-1:0] row_fft_img [CHANNELS-1:0][INPUT_TILE_SIZE-1:0][INPUT_TILE_SIZE-1:0];

    reg signed [COL_FFT_REAL_WIDTH-1:0] input_trans_real [CHANNELS-1:0][INPUT_TILE_SIZE-1:0][INPUT_TILE_SIZE-1:0];
    reg signed [COL_FFT_IMG_WIDTH-1:0] input_trans_img [CHANNELS-1:0][INPUT_TILE_SIZE-1:0][INPUT_TILE_SIZE-1:0];

    reg signed [KERNEL_ROW_FFT_REAL_WIDTH-1:0] kernel_row_fft_real [CHANNELS-1:0][INPUT_TILE_SIZE-1:0][INPUT_TILE_SIZE-1:0];
    reg signed [KERNEL_ROW_FFT_IMG_WIDTH-1:0] kernel_row_fft_img [CHANNELS-1:0][INPUT_TILE_SIZE-1:0][INPUT_TILE_SIZE-1:0];

    reg signed [KERNEL_COL_FFT_REAL_WIDTH-1:0] kernel_trans_real [CHANNELS-1:0][INPUT_TILE_SIZE-1:0][INPUT_TILE_SIZE-1:0];
    reg signed [KERNEL_COL_FFT_IMG_WIDTH-1:0] kernel_trans_img [CHANNELS-1:0][INPUT_TILE_SIZE-1:0][INPUT_TILE_SIZE-1:0];

    // Element-wise multiplication results
    reg signed [EWMM_REAL_WIDTH-1:0] ewmm_real [CHANNELS-1:0][INPUT_TILE_SIZE-1:0][INPUT_TILE_SIZE-1:0];
    reg signed [EWMM_IMG_WIDTH-1:0] ewmm_img [CHANNELS-1:0][INPUT_TILE_SIZE-1:0][INPUT_TILE_SIZE-1:0];


    // Temporary storage for row-wise IFFT results
    reg signed [IFFT_REAL_WIDTH-1:0] row_ifft_real [0:CHANNELS-1][0:INPUT_TILE_SIZE-1][0:INPUT_TILE_SIZE-1];
    reg signed [IFFT_IMG_WIDTH-1:0] row_ifft_img [0:CHANNELS-1][0:INPUT_TILE_SIZE-1][0:INPUT_TILE_SIZE-1];

    reg signed [IFFT_IMG_WIDTH-1:0]inverse_trans_real [0:CHANNELS-1][0:INPUT_TILE_SIZE-1][0:INPUT_TILE_SIZE-1];
    // Final output accumulation
    reg signed [OUTPUT_WIDTH-1:0] output_accum [0:CHANNELS-1][0:INPUT_TILE_SIZE/2-1][0:INPUT_TILE_SIZE/2-1] ; // 3x2x2 output


    // Control signals
    reg load_done, fft_stage1_done, fft_stage2_done, ewmm_done, ifft_done;
    reg ifft_row_compute_done, ifft_col_compute_done;

    // Additional registers for EWMM stage
    reg signed [EWMM_REAL_WIDTH-1:0] P;
    reg signed [EWMM_REAL_WIDTH-1:0] R;
    reg signed [EWMM_REAL_WIDTH-1:0] Q;
    
    // // Additional registers for IFFT stage
    reg signed [IFFT_REAL_WIDTH-1:0] col_ifft_real;
    // reg signed [IFFT_IMG_WIDTH-1:0] col_ifft_img;
    
    // =============================================
    // Main Processing
    // =============================================

    integer ch, k, l, m, i, j; // Moved all loop variables to top-level
    integer flat_idx;
    integer real_acc, img_acc;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all registers and control signals
            load_done <= 0;
            fft_stage1_done <= 0;
            fft_stage2_done <= 0;
            ewmm_done <= 0;
            ifft_done <= 0;
            ifft_row_compute_done<=0;
            ifft_col_compute_done<=0;
            finalCompute <= 0;
            // Other reset logic would go here
        end else begin

            // =============================================
            // Stage 1: Load and Pad Data
            // =============================================
            if (!load_done) begin
                // Unflatten input and kernel data
                for (ch = 0; ch < CHANNELS; ch = ch + 1) begin
                    for (i = 0; i < INPUT_TILE_SIZE; i = i + 1) begin
                        for (j = 0; j < INPUT_TILE_SIZE; j = j + 1) begin
                            flat_idx = ((CHANNELS * INPUT_TILE_SIZE * INPUT_TILE_SIZE) - 1) - 
                                        (ch * INPUT_TILE_SIZE * INPUT_TILE_SIZE + i * INPUT_TILE_SIZE + j);
                            input_tile[ch][i][j] = inpData[
                                flat_idx * INPUT_DATA_WIDTH +: INPUT_DATA_WIDTH
                            ];
                        end
                    end

                    for (i = 0; i < INPUT_TILE_SIZE; i = i + 1) begin
                        for (j = 0; j < INPUT_TILE_SIZE; j = j + 1) begin
                            padded_kernel[ch][i][j] = 0;
                        end
                    end

                    for (i = 0; i < KERNEL_SIZE; i = i + 1) begin
                        for (j = 0; j < KERNEL_SIZE; j = j + 1) begin
                            flat_idx = ((CHANNELS * KERNEL_SIZE * KERNEL_SIZE) - 1) - 
                                        (ch * KERNEL_SIZE * KERNEL_SIZE + i * KERNEL_SIZE + j);
                            kernel[ch][i][j] = Kernel[
                                flat_idx * KERNEL_DATA_WIDTH +: KERNEL_DATA_WIDTH
                            ];

                            // Fill the top-left portion of padded kernel (offset by +1)
                            if (i < INPUT_TILE_SIZE - 1 && j < INPUT_TILE_SIZE - 1) begin
                                padded_kernel[ch][i][j] = kernel[ch][i][j];
                            end
                        end
                    end
                end
                // flat_idx = 0;
                //     for (ch = CHANNELS; ch >=0; ch = ch - 1) begin
                //         for (i = 0; i < INPUT_TILE_SIZE; i = i + 1) begin
                //             for (j = 0; j < INPUT_TILE_SIZE; j = j + 1) begin
                //                 // we load input tile, indexing can be manually calculated for Reverse index 
                //                 flat_idx = ((CHANNELS * INPUT_TILE_SIZE * INPUT_TILE_SIZE) - 1) - 
                //                         (ch * INPUT_TILE_SIZE * INPUT_TILE_SIZE + i * INPUT_TILE_SIZE + j);
                //                 input_tile[ch][i][j] = inpData[
                //                     flat_idx * INPUT_DATA_WIDTH +: INPUT_DATA_WIDTH
                //                 ];
                //             end
                //         end
                //     end
                load_done <= 1;
            end
            
            // ============================================= 
            // Stage 2: Row-wise FFT (Real -> Complex)
            // =============================================
            else if (!fft_stage1_done) begin
                for (ch = 0; ch < CHANNELS; ch = ch + 1) begin
                    for (k = 0; k < INPUT_TILE_SIZE; k = k + 1) begin 
                        // Only compute k=0,1,2 => k=3 is conjugate of k=1 (so in real matrix, it's the exact same column )
                        for (i = 0; i < INPUT_TILE_SIZE; i = i + 1) begin
                            // Initialize accumulators
                            row_fft_real[ch][i][k] = 0;
                            row_fft_img[ch][i][k] = 0;
                            
                            // Compute dot product with FFT coefficients
                            for (j = 0; j < INPUT_TILE_SIZE; j = j + 1) begin
//                                $display("Multiplying input_tile[%0d][%0d][%0d] = %0d with fft_real[%0d][%0d] = %0d and fft_img[%0d][%0d] = %0d", ch, i, j, input_tile[ch][i][j], j, k, fft_real[j][k], j, k, fft_img[j][k]);
                                row_fft_real[ch][i][k] = row_fft_real[ch][i][k] + (input_tile[ch][i][j] * fft_real[j][k]);
                                row_fft_img[ch][i][k] = row_fft_img[ch][i][k] + (input_tile[ch][i][j] * fft_img[j][k]);
//                                $display("After iteration j=%0d, row_fft_real[%0d][%0d][%0d] = %0d, row_fft_img[%0d][%0d][%0d] = %0d",  j, ch, i, k, row_fft_real[ch][i][k], ch, i, k, row_fft_img[ch][i][k]);
                            end
//                            $display("\n\n\nNext Dot Product:-");
                        end
                    end
                    
                    // Process kernel (same operation as we did in above input tile )
                    for (k = 0; k < INPUT_TILE_SIZE; k = k + 1) begin
                        for (i = 0; i < INPUT_TILE_SIZE; i = i + 1) begin
                            kernel_row_fft_real[ch][i][k] = 0;
                            kernel_row_fft_img[ch][i][k] = 0;
                            for (j = 0; j < INPUT_TILE_SIZE; j = j + 1) begin
                                kernel_row_fft_real[ch][i][k] = kernel_row_fft_real[ch][i][k] + 
                                    (padded_kernel[ch][i][j] * fft_real[k][j]);
                                kernel_row_fft_img[ch][i][k] = kernel_row_fft_img[ch][i][k] + 
                                    (padded_kernel[ch][i][j] * fft_img[k][j]);
                            end
                        end
                    end
                end
                fft_stage1_done <= 1;
            end
            
            // =============================================
            // Stage 3: Column-wise FFT (Complex -> Complex)
            // =============================================
            else if (!fft_stage2_done) begin
                for (ch = 0; ch < CHANNELS; ch = ch + 1) begin
                    // Process input tile
                    for (k = 0; k < INPUT_TILE_SIZE; k = k + 1) begin // Columns: 0,1,2
                        for (l = 0; l < INPUT_TILE_SIZE; l = l + 1) begin // Rows: 0,1,2,3
                            input_trans_real[ch][l][k] = 0;
                            input_trans_img[ch][l][k] = 0;
                            
                            for (i = 0; i < INPUT_TILE_SIZE; i = i + 1) begin
                                // Real part: cos*real - sin*imag
                                input_trans_real[ch][l][k] = input_trans_real[ch][l][k] + 
                                    (fft_real[l][i] * row_fft_real[ch][i][k] - 
                                    fft_img[l][i] * row_fft_img[ch][i][k]);
                                // Imag part: cos*imag + sin*real
                                input_trans_img[ch][l][k] = input_trans_img[ch][l][k] + 
                                    (fft_real[l][i] * row_fft_img[ch][i][k] + 
                                    fft_img[l][i] * row_fft_real[ch][i][k]);
                            end
                        end
                    end
                    
                    // Process kernel (same operation)
                    for (k = 0; k < INPUT_TILE_SIZE; k = k + 1) begin
                        for (l = 0; l < INPUT_TILE_SIZE; l = l + 1) begin
                            kernel_trans_real[ch][l][k] = 0;
                            kernel_trans_img[ch][l][k] = 0;
                            for (i = 0; i < INPUT_TILE_SIZE; i = i + 1) begin
                                kernel_trans_real[ch][l][k] = kernel_trans_real[ch][l][k] + 
                                    (fft_real[l][i] * kernel_row_fft_real[ch][i][k] - 
                                    fft_img[l][i] * kernel_row_fft_img[ch][i][k]);
                                kernel_trans_img[ch][l][k] = kernel_trans_img[ch][l][k] + 
                                    (fft_real[l][i] * kernel_row_fft_img[ch][i][k] + 
                                    fft_img[l][i] * kernel_row_fft_real[ch][i][k]);
                            end
                        end
                    end
                end
                fft_stage2_done <= 1;
            end
            
            // =============================================
            // Stage 4: Element-wise Multiplication (3-mult trick)
            // =============================================
            else if (!ewmm_done) begin
                // Initialize output accumulation

                for (ch = 0; ch < CHANNELS; ch = ch + 1) begin
                    // First reconstruct full spectrum using Hermitian symmetry
                    // For columns 0,1,2 we have computed values
                    // Column 3 is conjugate of column 1
                    for (l = 0; l < INPUT_TILE_SIZE; l = l + 1) begin
                        ewmm_real[ch][l][0] = input_trans_real[ch][l][0] * kernel_trans_real[ch][l][0] - 
                                            input_trans_img[ch][l][0] * kernel_trans_img[ch][l][0];
                        ewmm_img[ch][l][0] = input_trans_real[ch][l][0] * kernel_trans_img[ch][l][0] + 
                                            input_trans_img[ch][l][0] * kernel_trans_real[ch][l][0];
                        for (k = 1; k < INPUT_TILE_SIZE; k = k + 1) begin
                            // Using 3-multiplier complex multiplication  ( so instead of 4 mults, we only do 3 mults )
                            // P = inp_img( ker_real - ker_img)
                            // Q = ker_real( inp_real - inp_img)
                            // R = ker_img( inp_real + inp_img)
                            // Real = P + Q
                            // Imag = P + R
                            P = input_trans_img[ch][l][k] * ( kernel_trans_real[ch][l][k] - kernel_trans_img[ch][l][k]);
                            Q = kernel_trans_real[ch][l][k] * (input_trans_real[ch][l][k] - input_trans_img[ch][l][k]);
                            R = kernel_trans_img[ch][l][k] * ( input_trans_real[ch][l][k] + input_trans_img[ch][l][k]);
                            
                            ewmm_real[ch][l][k] = P+Q;
                            ewmm_img[ch][l][k] = P+R;
                            
                            // Apply Hermitian symmetry for column 3
                            // if (k == 1) begin
                            //     ewmm_real[ch][l][3] = ewmm_real[ch][l][1];
                            //     ewmm_img[ch][l][3] = -ewmm_img[ch][l][1];
                            // end
                        end
                    end
                end
                ewmm_done <= 1;

            end

            // =============================================
            // Stage 5: Inverse FFT and Output Accumulation
            // =============================================
            else if (!ifft_done) begin
                // Initialize output accumulation
                for (ch = 0; ch < CHANNELS; ch = ch + 1) begin
                    for (i = 0; i < 2; i = i + 1) begin
                        for (j = 0; j < 2; j = j + 1) begin
                            output_accum[ch][i][j] = 0;
                        end
                    end
                end
                
                // =============================================
                // Step 5a: Row-wise IFFT (W_inv * E)
                // =============================================
                if(!ifft_row_compute_done) begin
                    for (ch = 0; ch < CHANNELS; ch = ch + 1) begin
                        for (i = 0; i < INPUT_TILE_SIZE; i = i + 1) begin
                            for (j = 0; j < INPUT_TILE_SIZE; j = j + 1) begin
                                // Initialize accumulators
                                real_acc = 0;
                                img_acc = 0;
                                
                                for (k = 0; k < INPUT_TILE_SIZE; k = k + 1) begin
                                    // Correct order: W_inv * E (fft_real is W_inv_real, ifft_img is W_inv_img)
                                    // Real part: W_inv_real*E_real - W_inv_img*E_img
                                    
                                    real_acc = real_acc + 
                                        (fft_real[i][k] * ewmm_real[ch][k][j] - 
                                        ifft_img[i][k] * ewmm_img[ch][k][j]);
                                    
                                    img_acc = img_acc + 
                                        (fft_real[i][k] * ewmm_img[ch][k][j] + 
                                        ifft_img[i][k] * ewmm_real[ch][k][j]);
                                    
                                    $display("Computing real_acc and img_acc for ch=%0d, i=%0d, j=%0d, k=%0d", ch, i, j, k);
                                    $display("fft_real[%0d][%0d] = %0d, ewmm_real[%0d][%0d][%0d] = %0d, ifft_img[%0d][%0d] = %0d, ewmm_img[%0d][%0d][%0d] = %0d", 
                                        i, k, fft_real[i][k], ch, k, j, ewmm_real[ch][k][j], i, k, ifft_img[i][k], ch, k, j, ewmm_img[ch][k][j]);

                                end
                                // Store intermediate results (scale by N=4 here)
                                row_ifft_real[ch][i][j] = real_acc >>> 2;
                                row_ifft_img[ch][i][j] = img_acc >>> 2;
                                $display("After iteration j=%0d, real_ifft_real[%0d][%0d][%0d] = %0d, real_ifft_img[%0d][%0d][%0d] = %0d", j ,ch,i,j,row_ifft_real[ch][i][j] ,ch,i,j, row_ifft_img[ch][i][j]);
                                $display("\n\n\n\n");
                            end
                        end
                    end
                    ifft_row_compute_done <= 1;
                end
                // =============================================
                // Step 5b: Column-wise IFFT (W_inv * temp)
                // =============================================
                else if(!ifft_col_compute_done) begin
                    for (ch = 0; ch < CHANNELS; ch = ch + 1) begin
                        for (i = 0; i < INPUT_TILE_SIZE; i = i + 1) begin
                            for (j = 0; j < INPUT_TILE_SIZE; j = j + 1) begin
                                // Initialize accumulators
                                real_acc = 0;
                                img_acc = 0;

                                for (k = 0; k < INPUT_TILE_SIZE; k = k + 1) begin
                                    // Real part: W_inv_real*row_real - W_inv_img*row_img
                                    real_acc = real_acc + 
                                        (fft_real[i][k] * row_ifft_real[ch][k][j] - 
                                        ifft_img[i][k] * row_ifft_img[ch][k][j]);
                                    
                                    // Imag part: W_inv_real*row_img + W_inv_img*row_real
                                    img_acc = img_acc + 
                                        (fft_real[i][k] * row_ifft_img[ch][k][j] + 
                                        ifft_img[i][k] * row_ifft_real[ch][k][j]);
                                end

                                // Final scaling by N=4 (total scaling is N²=16)
                                inverse_trans_real[ch][i][j] = real_acc >>> 2;
                                $display("After iteration j=%0d, inverse_trans_real[%0d][%0d][%0d] = %0d", j ,ch,i,j,row_ifft_real[ch][i][j]);

                                // Accumulate only the center 2x2 region
                                if (i >= 1 && i < 3 && j >= 1 && j < 3) begin
                                    output_accum[ch][i-1][j-1] = output_accum[ch][i-1][j-1] + 
                                        inverse_trans_real[ch][i][j];
                                end
                            end
                        end
                    end
                    ifft_col_compute_done <= 1;
                end
                
                // Final output
                // if (ifft_row_compute_done && ifft_col_compute_done) begin
                //     for (i = 0; i < 2; i = i + 1) begin
                //         for (j = 0; j < 2; j = j + 1) begin
                //             outData[(i*2 + j)*OUTPUT_WIDTH +: OUTPUT_WIDTH] = output_accum[i][j];
                //         end
                //     end
                //     ifft_done <= 1;
                //     finalCompute <= 1;
                // end
            end

            
            // // =============================================
            // // Stage 5: Inverse FFT and Output Accumulation
            // // =============================================
            // else if (!ifft_done) begin
            //     // Initialize output accumulation
            //     for (i = 0; i < 2; i = i + 1) begin
            //         for (j = 0; j < 2; j = j + 1) begin
            //             output_accum[i][j] = 0;
            //         end
            //     end
                
            //     // =============================================
            //     // Step 5a: Row-wise IFFT (E_fft * W_inv)
            //     // =============================================
            //     if(!ifft_row_compute_done) begin
            //         for (ch = 0; ch < CHANNELS; ch = ch + 1) begin
            //             for (i = 0; i < INPUT_TILE_SIZE; i = i + 1) begin
            //                 for (j = 0; j < INPUT_TILE_SIZE; j = j + 1) begin
            //                     row_ifft_real[ch][i][j] = 0;
            //                     row_ifft_img[ch][i][j] = 0;
                                
            //                     for (k = 0; k < INPUT_TILE_SIZE; k = k + 1) begin
            //                         // Real part: real*real - img*img
            //                         $display("Computing row_ifft_real[%0d][%0d][%0d]: Adding fft_real[%0d][%0d] = %0d * ewmm_real[%0d][%0d][%0d] = %0d - ifft_img[%0d][%0d] = %0d * ewmm_img[%0d][%0d][%0d] = %0d", 
            //                             ch, i, j, i, k, fft_real[i][k], ch, k, j, ewmm_real[ch][k][j], i, k, ifft_img[i][k], ch, k, j, ewmm_img[ch][k][j]);
            //                         row_ifft_real[ch][i][j] = row_ifft_real[ch][i][j] +  
            //                             ( ewmm_real[ch][k][j] * fft_real[i][k] - ewmm_img[ch][k][j] * ifft_img[i][k] );
                                    
            //                         // Imag part: real*img + img*real
            //                         $display("Computing row_ifft_img[%0d][%0d][%0d]: Adding fft_real[%0d][%0d] = %0d * ewmm_img[%0d][%0d][%0d] = %0d + ifft_img[%0d][%0d] = %0d * ewmm_real[%0d][%0d][%0d] = %0d", 
            //                             ch, i, j, i, k, fft_real[i][k], ch, k, j, ewmm_img[ch][k][j], i, k, ifft_img[i][k], ch, k, j, ewmm_real[ch][k][j]);
            //                         row_ifft_img[ch][i][j] = row_ifft_img[ch][i][j] +  
            //                             ( ewmm_real[ch][k][j] * ifft_img[i][k]  + ewmm_img[ch][k][j]* fft_real[i][k]  );
            //                         $display("\n");
            //                     end
                                
            //                     $display("After iteration j=%0d, row_ifft_real[%0d][%0d][%0d] = %0d, row_ifft_img[%0d][%0d][%0d] = %0d", 
            //                         j, ch, i, j, row_ifft_real[ch][i][j], ch, i, j, row_ifft_img[ch][i][j]);
            //                     $display("\n===========================================================\n\n\n\n");
            //                 end
            //                 end
            //             end
            //     ifft_row_compute_done <= 1;
            //     end
            // end
                    
            // // =============================================
            // // Step 5b: Column-wise IFFT (W_inv * temp)
            // // =============================================
            // if(!ifft_col_compute_done) begin
            //     for (ch = 0; ch < CHANNELS; ch = ch + 1) begin
            //         for (i = 0; i < INPUT_TILE_SIZE; i = i + 1) begin
            //             for (j = 0; j < INPUT_TILE_SIZE; j = j + 1) begin
            //                 // Use pre-declared registers
            //                 col_ifft_real = 0;
            //                 // col_ifft_img = 0;
                            
            //                 for (k = 0; k < INPUT_TILE_SIZE; k = k + 1) begin
            //                     // Real part: real*real - img*img
            //                     col_ifft_real = col_ifft_real + 
            //                         (fft_real[i][k] * row_ifft_real[ch][k][j] - ifft_img[i][k] * row_ifft_img[ch][k][j]);
                                
            //                     // Imag part: real*img + img*real ; We have no need for this 
            //                     // col_ifft_img = col_ifft_img + 
            //                     //     (fft_real[i][k] * row_ifft_img[ch][k][j] + ifft_img[i][k] * row_ifft_real[ch][k][j]);
            //                 end
                            
            //                 // Only store the real part (normalize by INPUT_TILE_SIZE*INPUT_TILE_SIZE = 16, right shift by 4)
            //                 inverse_trans_real[ch][i][j] = col_ifft_real >>> 4;
                            
            //                 // Accumulate the valid 2x2 region (bottom right 2x2)
            //                 if (i >= (INPUT_TILE_SIZE/2) && i < INPUT_TILE_SIZE && j >= (INPUT_TILE_SIZE/2) && j < INPUT_TILE_SIZE) begin
            //                     output_accum[i-(INPUT_TILE_SIZE/2)][j-(INPUT_TILE_SIZE/2)] = 
            //                         output_accum[i-(INPUT_TILE_SIZE/2)][j-(INPUT_TILE_SIZE/2)] + inverse_trans_real[ch][i][j];
            //                 end
            //             end
            //         end
            //     end
            //     ifft_col_compute_done<=1;
            // end
                
            //     // Flatten the output
            //     for (i = 0; i < 2; i = i + 1) begin
            //         for (j = 0; j < 2; j = j + 1) begin
            //             outData[(i*2 + j)*OUTPUT_WIDTH +: OUTPUT_WIDTH] = output_accum[i][j];
            //         end
            // end
                
            //     ifft_done <= 1;
            // finalCompute <= 1;
        end
    end

endmodule