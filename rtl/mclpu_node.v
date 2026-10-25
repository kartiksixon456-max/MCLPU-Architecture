// =============================================================================
// Module Name:  mclpu_node
// Project:      MCLPU-100 (Multi Computer Large Processing Unit)
// Description:  Synthesizable IEEE 1364-2005 Verilog RTL model of a single 3D
//               volumetric (X, Y, Z) 1T-1M processing element (PE). Implements
//               local non-volatile weight storage, single-cycle MAC execution,
//               and 6-axis spatial neighbor routing via vertical inter-layer
//               vias (ILVs) and horizontal interconnects.
// License:      Apache-2.0
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module mclpu_node #(
    parameter integer DATA_WIDTH = 16,
    parameter integer ACC_WIDTH  = 32,
    parameter integer COORD_X    = 0,
    parameter integer COORD_Y    = 0,
    parameter integer COORD_Z    = 0
)(
    // System Signals
    input  wire                  clk,
    input  wire                  rst_n,

    // Control Interface
    input  wire                  enable,
    input  wire                  weight_we,
    input  wire [1:0]            op_mode,    // 2'b00: Idle, 2'b01: MAC, 2'b10: 3D Stencil, 2'b11: Bypass
    input  wire [DATA_WIDTH-1:0] weight_in,

    // 6-Axis Volumetric Spatial Inputs (X, Y, Z)
    input  wire [DATA_WIDTH-1:0] in_north,   // Y + 1 (Planar)
    input  wire [DATA_WIDTH-1:0] in_south,   // Y - 1 (Planar)
    input  wire [DATA_WIDTH-1:0] in_east,    // X + 1 (Planar)
    input  wire [DATA_WIDTH-1:0] in_west,    // X - 1 (Planar)
    input  wire [DATA_WIDTH-1:0] in_up,      // Z + 1 (Upper Tier via Vertical ILV)
    input  wire [DATA_WIDTH-1:0] in_down,    // Z - 1 (Lower Tier via Vertical ILV)

    // 6-Axis Volumetric Spatial Outputs (X, Y, Z)
    output reg  [DATA_WIDTH-1:0] out_north,
    output reg  [DATA_WIDTH-1:0] out_south,
    output reg  [DATA_WIDTH-1:0] out_east,
    output reg  [DATA_WIDTH-1:0] out_west,
    output reg  [DATA_WIDTH-1:0] out_up,
    output reg  [DATA_WIDTH-1:0] out_down,

    // Vertical Bitline Accumulator Cascade
    input  wire [ACC_WIDTH-1:0]  acc_in_z,   // Partial sum from Tier Z + 1
    output reg  [ACC_WIDTH-1:0]  acc_out_z   // Partial sum to Tier Z - 1
);

    // =========================================================================
    // Operation Mode Encoding
    // =========================================================================
    localparam [1:0] MODE_IDLE    = 2'b00;
    localparam [1:0] MODE_MAC     = 2'b01;
    localparam [1:0] MODE_STENCIL = 2'b10;
    localparam [1:0] MODE_BYPASS  = 2'b11;

    // =========================================================================
    // Internal 1T-1M Coupled Non-Volatile Memory Register & Datapath Signals
    // =========================================================================
    reg  [DATA_WIDTH-1:0] local_nvm_weight;
    reg  [DATA_WIDTH-1:0] state_reg;

    wire [ACC_WIDTH-1:0]  mac_product;
    wire [ACC_WIDTH-1:0]  stencil_sum;
    wire [DATA_WIDTH-1:0] stencil_avg;

    // =========================================================================
    // Combinational Arithmetic (1T-1M Local Compute & 3D Spatial Reduction)
    // =========================================================================
    
    // Multiply input activation (from West wordline) by local coupled weight
    assign mac_product = in_west * local_nvm_weight;

    // 6-neighbor 3D volumetric finite-difference summation
    assign stencil_sum = {16'd0, in_north} +
                         {16'd0, in_south} +
                         {16'd0, in_east}  +
                         {16'd0, in_west}  +
                         {16'd0, in_up}    +
                         {16'd0, in_down};

    // Normalized spatial update (approximated via right-shift division by 8 + self weight)
    assign stencil_avg = (stencil_sum[DATA_WIDTH+2:3]) + (state_reg >> 2);

    // =========================================================================
    // Sequential Logic: Local 1T-1M Storage Update
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            local_nvm_weight <= {DATA_WIDTH{1'b0}};
        end else if (weight_we) begin
            local_nvm_weight <= weight_in;
        end
    end

    // =========================================================================
    // Sequential Logic: Volumetric Routing & Execution Pipeline
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= {DATA_WIDTH{1'b0}};
            out_north <= {DATA_WIDTH{1'b0}};
            out_south <= {DATA_WIDTH{1'b0}};
            out_east  <= {DATA_WIDTH{1'b0}};
            out_west  <= {DATA_WIDTH{1'b0}};
            out_up    <= {DATA_WIDTH{1'b0}};
            out_down  <= {DATA_WIDTH{1'b0}};
            acc_out_z <= {ACC_WIDTH{1'b0}};
        end else if (enable) begin
            case (op_mode)
                MODE_IDLE: begin
                    acc_out_z <= acc_in_z;
                end

                MODE_MAC: begin
                    // Pass activation horizontally (West to East) and accumulate vertically (Z+1 to Z-1)
                    out_east  <= in_west;
                    out_south <= in_north;
                    acc_out_z <= acc_in_z + mac_product;
                end

                MODE_STENCIL: begin
                    // Update volumetric state and broadcast across all 6 spatial axes (X, Y, Z)
                    state_reg <= stencil_avg;
                    out_north <= stencil_avg;
                    out_south <= stencil_avg;
                    out_east  <= stencil_avg;
                    out_west  <= stencil_avg;
                    out_up    <= stencil_avg;
                    out_down  <= stencil_avg;
                end

                MODE_BYPASS: begin
                    // Direct 3D inter-tier and planar pass-through
                    out_north <= in_south;
                    out_south <= in_north;
                    out_east  <= in_west;
                    out_west  <= in_east;
                    out_up    <= in_down;
                    out_down  <= in_up;
                    acc_out_z <= acc_in_z;
                end

                default: begin
                    acc_out_z <= acc_in_z;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
