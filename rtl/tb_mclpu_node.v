// =============================================================================
// Testbench Name: tb_mclpu_node
// Project:        MCLPU-100 (Multi Computer Large Processing Unit)
// Description:    Self-checking IEEE 1364-2005 Verilog verification testbench
//                 for the mclpu_node 3D volumetric processing element.
//                 Verifies 1T-1M non-volatile weight programming, vertical
//                 bitline MAC accumulation, 6-axis 3D stencil reduction, and
//                 inter-tier spatial bypass routing.
// License:        Apache-2.0
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module tb_mclpu_node;

    // =========================================================================
    // Parameters
    // =========================================================================
    parameter integer DATA_WIDTH = 16;
    parameter integer ACC_WIDTH  = 32;
    parameter integer CLK_PERIOD = 10; // 100 MHz simulation clock

    // =========================================================================
    // Operation Modes (Matched to DUT)
    // =========================================================================
    localparam [1:0] MODE_IDLE    = 2'b00;
    localparam [1:0] MODE_MAC     = 2'b01;
    localparam [1:0] MODE_STENCIL = 2'b10;
    localparam [1:0] MODE_BYPASS  = 2'b11;

    // =========================================================================
    // Testbench Signals
    // =========================================================================
    reg                   clk;
    reg                   rst_n;
    reg                   enable;
    reg                   weight_we;
    reg  [1:0]            op_mode;
    reg  [DATA_WIDTH-1:0] weight_in;

    reg  [DATA_WIDTH-1:0] in_north;
    reg  [DATA_WIDTH-1:0] in_south;
    reg  [DATA_WIDTH-1:0] in_east;
    reg  [DATA_WIDTH-1:0] in_west;
    reg  [DATA_WIDTH-1:0] in_up;
    reg  [DATA_WIDTH-1:0] in_down;
    reg  [ACC_WIDTH-1:0]  acc_in_z;

    wire [DATA_WIDTH-1:0] out_north;
    wire [DATA_WIDTH-1:0] out_south;
    wire [DATA_WIDTH-1:0] out_east;
    wire [DATA_WIDTH-1:0] out_west;
    wire [DATA_WIDTH-1:0] out_up;
    wire [DATA_WIDTH-1:0] out_down;
    wire [ACC_WIDTH-1:0]  acc_out_z;

    integer error_count;

    // =========================================================================
    // Device Under Test (DUT) Instantiation — Tier Z = 50, Y = 4, X = 4
    // =========================================================================
    mclpu_node #(
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH),
        .COORD_X    (4),
        .COORD_Y    (4),
        .COORD_Z    (50)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .enable     (enable),
        .weight_we  (weight_we),
        .op_mode    (op_mode),
        .weight_in  (weight_in),
        .in_north   (in_north),
        .in_south   (in_south),
        .in_east    (in_east),
        .in_west    (in_west),
        .in_up      (in_up),
        .in_down    (in_down),
        .out_north  (out_north),
        .out_south  (out_south),
        .out_east   (out_east),
        .out_west   (out_west),
        .out_up     (out_up),
        .out_down   (out_down),
        .acc_in_z   (acc_in_z),
        .acc_out_z  (acc_out_z)
    );

    // =========================================================================
    // Clock Generation
    // =========================================================================
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // =========================================================================
    // VCD Waveform Dump for GTKWave / ModelSim / Verilator
    // =========================================================================
    initial begin
        $dumpfile("tb_mclpu_node.vcd");
        $dumpvars(0, tb_mclpu_node);
    end

    // =========================================================================
    // Main Verification Sequence
    // =========================================================================
    initial begin
        // Initialize inputs
        error_count = 0;
        rst_n       = 1'b0;
        enable      = 1'b0;
        weight_we   = 1'b0;
        op_mode     = MODE_IDLE;
        weight_in   = {DATA_WIDTH{1'b0}};
        in_north    = {DATA_WIDTH{1'b0}};
        in_south    = {DATA_WIDTH{1'b0}};
        in_east     = {DATA_WIDTH{1'b0}};
        in_west     = {DATA_WIDTH{1'b0}};
        in_up       = {DATA_WIDTH{1'b0}};
        in_down     = {DATA_WIDTH{1'b0}};
        acc_in_z    = {ACC_WIDTH{1'b0}};

        $display("----------------------------------------------------------------");
        $display(" MCLPU-100 RTL Verification Testbench Initialized");
        $display("----------------------------------------------------------------");

        // ---------------------------------------------------------------------
        // TEST 1: Asynchronous Reset Verification
        // ---------------------------------------------------------------------
        #(CLK_PERIOD * 2);
        rst_n = 1'b1;
        #(CLK_PERIOD);

        if (acc_out_z !== 32'd0 || out_east !== 16'd0) begin
            $display("[FAIL] Test 1: Reset state mismatch. acc_out_z = %0d", acc_out_z);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Test 1: Reset state verified.");
        end

        // ---------------------------------------------------------------------
        // TEST 2: 1T-1M Non-Volatile Weight Programming & Vertical MAC
        // Expected: acc_out_z = acc_in_z (100) + (in_west (12) * weight (25)) = 400
        // ---------------------------------------------------------------------
        @(negedge clk);
        weight_we = 1'b1;
        weight_in = 16'd25;
        @(negedge clk);
        weight_we = 1'b0;

        enable    = 1'b1;
        op_mode   = MODE_MAC;
        in_west   = 16'd12;
        in_north  = 16'd7;
        acc_in_z  = 32'd100;
        @(negedge clk);

        if (acc_out_z !== 32'd400 || out_east !== 16'd12 || out_south !== 16'd7) begin
            $display("[FAIL] Test 2: MAC calculation mismatch. Expected 400, Got %0d", acc_out_z);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Test 2: 1T-1M MAC verified (acc_out_z = %0d, out_east = %0d).", acc_out_z, out_east);
        end

        // ---------------------------------------------------------------------
        // TEST 3: 6-Axis Volumetric 3D Stencil Reduction
        // Inputs: North=80, South=80, East=80, West=80, Up(Z+1)=80, Down(Z-1)=80
        // Sum = 480. Stencil Average = (480 >> 3) + (0 >> 2) = 60
        // ---------------------------------------------------------------------
        @(negedge clk);
        op_mode  = MODE_STENCIL;
        in_north = 16'd80;
        in_south = 16'd80;
        in_east  = 16'd80;
        in_west  = 16'd80;
        in_up    = 16'd80;
        in_down  = 16'd80;
        @(negedge clk);

        if (out_up !== 16'd60 || out_down !== 16'd60 || out_north !== 16'd60) begin
            $display("[FAIL] Test 3: 3D Stencil reduction mismatch. Expected 60, Got %0d", out_up);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Test 3: 6-Axis 3D Stencil update verified (out_up = %0d).", out_up);
        end

        // ---------------------------------------------------------------------
        // TEST 4: 3D Inter-Tier Spatial Bypass Routing
        // Expected: out_up = in_down (16'hA5A5), out_down = in_up (16'h5A5A)
        // ---------------------------------------------------------------------
        @(negedge clk);
        op_mode  = MODE_BYPASS;
        in_up    = 16'h5A5A;
        in_down  = 16'hA5A5;
        in_west  = 16'h1234;
        in_east  = 16'h4321;
        @(negedge clk);

        if (out_up !== 16'hA5A5 || out_down !== 16'h5A5A || out_east !== 16'h1234) begin
            $display("[FAIL] Test 4: Bypass routing mismatch. out_up = 0x%h, out_down = 0x%h", out_up, out_down);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Test 4: Inter-tier ILV bypass routing verified (out_up = 0x%h).", out_up);
        end

        // ---------------------------------------------------------------------
        // Summary Report
        // ---------------------------------------------------------------------
        #(CLK_PERIOD);
        $display("----------------------------------------------------------------");
        if (error_count == 0) begin
            $display(" SIMULATION PASSED: All 4 functional verification checks succeeded.");
        end else begin
            $display(" SIMULATION FAILED: %0d error(s) detected.", error_count);
        end
        $display("----------------------------------------------------------------");
        $finish;
    end

endmodule

`default_nettype wire
