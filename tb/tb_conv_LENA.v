module tb_conv;

parameter KERNEL_SIZE = 3;
parameter INPUT_TILE_SIZE = 3;
parameter INPUT_DATA_WIDTH = 8;
parameter KERNEL_DATA_WIDTH = 8;
parameter CHANNELS = 3;
parameter OUTPUT_BIT_WIDTH = INPUT_DATA_WIDTH + KERNEL_DATA_WIDTH + 8;
parameter OUTPUT_TILE_SIZE = INPUT_TILE_SIZE - KERNEL_SIZE + 1;

reg clk;
reg reset;
reg signed [(KERNEL_SIZE * KERNEL_SIZE * KERNEL_DATA_WIDTH * CHANNELS) - 1 : 0] kernel;
reg signed [(INPUT_TILE_SIZE * INPUT_TILE_SIZE * INPUT_DATA_WIDTH * CHANNELS) - 1 : 0] inpData;
wire signed [(OUTPUT_TILE_SIZE * OUTPUT_TILE_SIZE * OUTPUT_BIT_WIDTH) - 1 : 0] outData;
wire finalCompute;

always begin
    #5 clk = ~clk;
end

conv #(
    .KERNEL_SIZE(KERNEL_SIZE),
    .INPUT_TILE_SIZE(INPUT_TILE_SIZE),
    .INPUT_DATA_WIDTH(INPUT_DATA_WIDTH),
    .KERNEL_DATA_WIDTH(KERNEL_DATA_WIDTH),
    .CHANNELS(CHANNELS)
) uut (
    .clk(clk),
    .reset(reset),
    .kernel(kernel),
    .inpData(inpData),
    .outData(outData),
    .finalCompute(finalCompute)
);

integer rf, gf, bf, outf;
integer i, patch, dum1, dum2, dum3, r_tmp, g_tmp, b_tmp;
reg signed [7:0] r_patch[0:8];
reg signed [7:0] g_patch[0:8];
reg signed [7:0] b_patch[0:8];

initial begin
    clk = 0;
    reset = 0;
    inpData = 0;

    // Open input files
    rf = $fopen("red.txt", "r");
    gf = $fopen("green.txt", "r");
    bf = $fopen("blue.txt", "r");
    outf = $fopen("conv.txt", "w");

    if (rf == 0 || gf == 0 || bf == 0 || outf == 0) begin
        $display("Error: Unable to open one or more files.");
        $finish;
    end

    // Read all patches and perform convolution
    for (patch = 1; patch <= 260100; patch = patch + 1) begin
        // Skip "Patch N:" label in the files
        dum1 = $fscanf(rf, "Patch %*d: ",dum1);
        dum2 = $fscanf(gf, "Patch %*d: ",dum2);
        dum3 = $fscanf(bf, "Patch %*d: ",dum3);

        // Read 9 values from each file
        for (i = 0; i < 9; i = i + 1) begin
            // Read individual pixel values from the red, green, and blue files
            r_tmp=$fscanf(rf, "%d,", r_tmp);  // Reading signed 8-bit value
            g_tmp=$fscanf(gf, "%d,", g_tmp);  // Reading signed 8-bit value
            b_tmp=$fscanf(bf, "%d,", b_tmp);  // Reading signed 8-bit value

            r_patch[i] = r_tmp;
            g_patch[i] = g_tmp;
            b_patch[i] = b_tmp;
        end
        
        // Reset and send data to convolution module
        reset = 1;
        #100;  // Longer reset pulse to ensure proper reset
        reset = 0;

        // Kernel values (hardcoded 3x3 kernel)
        kernel = {
            // Channel 2 (blue)
            8'sd1, 8'sd2, 8'sd1,
            8'sd2, 8'sd4, 8'sd2,
            8'sd1, 8'sd2, 8'sd1,

            // Channel 1 (green)
            8'sd1, 8'sd2, 8'sd1,
            8'sd2, 8'sd4, 8'sd2,
            8'sd1, 8'sd2, 8'sd1,

            // Channel 0 (red)
            8'sd1, 8'sd2, 8'sd1,
            8'sd2, 8'sd4, 8'sd2,
            8'sd1, 8'sd2, 8'sd1
        };

        // Set input data based on patches
        inpData = {
            // Channel 2 (blue)
            b_patch[0], b_patch[1], b_patch[2],
            b_patch[3], b_patch[4], b_patch[5],
            b_patch[6], b_patch[7], b_patch[8],

            // Channel 1 (green)
            g_patch[0], g_patch[1], g_patch[2],
            g_patch[3], g_patch[4], g_patch[5],
            g_patch[6], g_patch[7], g_patch[8],

            // Channel 0 (red)
            r_patch[0], r_patch[1], r_patch[2],
            r_patch[3], r_patch[4], r_patch[5],
            r_patch[6], r_patch[7], r_patch[8]
        };

        // Wait for the computation to be complete
        wait (finalCompute == 1);
        #100;  // Allow some time after computation

        // Write the output to the file
        $fdisplay(outf, "Patch %0d Output = %h", patch, outData);
    end

    $display("✅ All patches processed. Output saved to conv.txt.");

    // Close the files
    $fclose(rf);
    $fclose(gf);
    $fclose(bf);
    $fclose(outf);

    $finish;
end

initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb_conv);
    $monitor("Time = %t | Output = %h | finalCompute = %b", $time, outData, finalCompute);
end

endmodule