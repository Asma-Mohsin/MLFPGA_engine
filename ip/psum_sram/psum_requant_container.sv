`timescale 1ns / 1ps

module psum_requant_container #(
    parameter int PSUM_WIDTH       = 32,
    parameter int PSUM_WORDS       = 256,
    parameter int SCALE_WIDTH      = 16,
    parameter int ACTIVATION_WIDTH = 8,

    localparam int PSUM_ADDR_WIDTH = $clog2(PSUM_WORDS),
    localparam int PROD_WIDTH      = PSUM_WIDTH + SCALE_WIDTH,
    localparam int SHIFT_WIDTH     = $clog2(PROD_WIDTH),
    localparam int QUANT_CFG_WIDTH = SCALE_WIDTH + SHIFT_WIDTH + ACTIVATION_WIDTH
)(
    input  wire                                               clk_i,
    input  wire                                               rst_n,

    // Execution Mode Controls
    input  wire                                               psum_lut_en,

    // Bank A Interface (West Pins facing Slice 4)
    input  wire        [PSUM_ADDR_WIDTH-1:0]                  bank_A_addr,
    input  wire                                               bank_A_we,
    input  wire signed [PSUM_WIDTH-1:0]                       bank_A_wdata,
    output wire signed [PSUM_WIDTH-1:0]                       bank_A_rdata,

    // Bank B Interface (West Pins facing Slice 4)
    input  wire        [PSUM_ADDR_WIDTH-1:0]                  bank_B_addr,
    input  wire                                               bank_B_we,
    input  wire signed [PSUM_WIDTH-1:0]                       bank_B_wdata,
    output wire signed [PSUM_WIDTH-1:0]                       bank_B_rdata,

    // Requantizer Configuration (West Pins from Slice 4 Shift Chain)
    input  wire        [QUANT_CFG_WIDTH-1:0]                  quant_cfg,

    // Final Quantized Streaming Output (West Pin to Slice 4 / Drain Bus)
    output wire signed [ACTIVATION_WIDTH-1:0]                 act_out
);

    // -------------------------------------------------------------------------
    // 1. Bank A Partial Sum SRAM (Accumulator Storage)
    // -------------------------------------------------------------------------
    sram_bank #(
        .DATA_WIDTH(PSUM_WIDTH),
        .DEPTH     (PSUM_WORDS)
    ) bank_A_sram (
        .clk_i(clk_i),
        .we   (bank_A_we),
        .addr (bank_A_addr),
        .wdata(bank_A_wdata),
        .rdata(bank_A_rdata)
    );

    // -------------------------------------------------------------------------
    // 2. Requantizer Lane (Standard-Cell Arithmetic Pipeline)
    // Direct internal connection: bank_A_rdata feeds psum_in directly.
    // -------------------------------------------------------------------------
    wire signed [ACTIVATION_WIDTH-1:0] quant_direct_act;

    wire signed [SCALE_WIDTH-1:0]      lane_scale_m0   = quant_cfg[SCALE_WIDTH-1 : 0];
    wire        [SHIFT_WIDTH-1:0]      lane_shift_n    = quant_cfg[SCALE_WIDTH+SHIFT_WIDTH-1 : SCALE_WIDTH];
    wire signed [ACTIVATION_WIDTH-1:0] lane_zero_point = quant_cfg[QUANT_CFG_WIDTH-1 : SCALE_WIDTH+SHIFT_WIDTH];

    npu_requantizer_lane #(
        .PSUM_WIDTH      (PSUM_WIDTH),
        .SCALE_WIDTH     (SCALE_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH)
    ) lane_inst (
        .clk_i     (clk_i),
        .rst_n     (rst_n),
        .psum_in   (bank_A_rdata),
        .scale_m0  (lane_scale_m0),
        .shift_n   (lane_shift_n),
        .zero_point(lane_zero_point),
        .act_out   (quant_direct_act)
    );

    // -------------------------------------------------------------------------
    // 3. Bank B Partial Sum / LUT Activation SRAM
    // In LUT mode (psum_lut_en = 1), Bank B address is driven directly by the
    // internal requantizer output and write enable is gated inactive.
    // -------------------------------------------------------------------------
    wire [PSUM_ADDR_WIDTH-1:0] internal_bank_B_addr = psum_lut_en ? PSUM_ADDR_WIDTH'($unsigned(quant_direct_act))
                                                                  : bank_B_addr;
    wire                       internal_bank_B_we   = psum_lut_en ? 1'b0
                                                                  : bank_B_we;

    sram_bank #(
        .DATA_WIDTH(PSUM_WIDTH),
        .DEPTH     (PSUM_WORDS)
    ) bank_B_sram (
        .clk_i(clk_i),
        .we   (internal_bank_B_we),
        .addr (internal_bank_B_addr),
        .wdata(bank_B_wdata),
        .rdata(bank_B_rdata)
    );

    // -------------------------------------------------------------------------
    // 4. Final Activation Output Multiplexer
    // Selects Bank B non-linear LUT result when enabled, or direct linear requant.
    // -------------------------------------------------------------------------
    assign act_out = psum_lut_en ? bank_B_rdata[ACTIVATION_WIDTH-1:0]
                                 : quant_direct_act;

endmodule

