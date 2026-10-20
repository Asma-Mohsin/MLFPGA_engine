`timescale 1ns / 1ps

module psum_requant_top #(
    parameter int ARRAY_WIDTH      = 8,
    parameter int PSUM_WIDTH       = 32,
    parameter int PSUM_WORDS       = 256,
    parameter int SCALE_WIDTH      = 16,
    parameter int ACTIVATION_WIDTH = 8,

    localparam int PSUM_ADDR_WIDTH = $clog2(PSUM_WORDS),
    localparam int PROD_WIDTH      = PSUM_WIDTH + SCALE_WIDTH,
    localparam int SHIFT_WIDTH     = $clog2(PROD_WIDTH),
    localparam int QUANT_CFG_WIDTH = SCALE_WIDTH + SHIFT_WIDTH + ACTIVATION_WIDTH
)(
    input  wire                                                              clk_i,
    input  wire                                                              rst_n,

    // Execution Mode Controls
    input  wire                                                              psum_lut_en,

    // Bank A Vectorized Physical Interface
    input  wire        [ARRAY_WIDTH-1:0][PSUM_ADDR_WIDTH-1:0]                bank_A_addr,
    input  wire        [ARRAY_WIDTH-1:0]                                     bank_A_we,
    input  wire signed [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0]                     bank_A_wdata,
    output wire signed [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0]                     bank_A_rdata,

    // Bank B Vectorized Physical Interface
    input  wire        [ARRAY_WIDTH-1:0][PSUM_ADDR_WIDTH-1:0]                bank_B_addr,
    input  wire        [ARRAY_WIDTH-1:0]                                     bank_B_we,
    input  wire signed [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0]                     bank_B_wdata,
    output wire signed [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0]                     bank_B_rdata,

    // Requantizer Static Configuration Bus (from Compute Core Shift Chain)
    input  wire        [ARRAY_WIDTH-1:0][QUANT_CFG_WIDTH-1:0]                quant_cfg,

    // Final Quantized Streaming Activation Outputs
    output wire signed [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0]               out_act
);

    genvar c;
    generate
        for (c = 0; c < ARRAY_WIDTH; c++) begin : gen_containers
`ifdef LIBRELANE_HARD_MACROS
            psum_requant_container container_inst (
`else
            psum_requant_container #(
                .PSUM_WIDTH      (PSUM_WIDTH),
                .PSUM_WORDS      (PSUM_WORDS),
                .SCALE_WIDTH     (SCALE_WIDTH),
                .ACTIVATION_WIDTH(ACTIVATION_WIDTH)
            ) container_inst (
`endif
                .clk_i       (clk_i),
                .rst_n       (rst_n),
                .psum_lut_en (psum_lut_en),
                .bank_A_addr (bank_A_addr[c]),
                .bank_A_we   (bank_A_we[c]),
                .bank_A_wdata(bank_A_wdata[c]),
                .bank_A_rdata(bank_A_rdata[c]),
                .bank_B_addr (bank_B_addr[c]),
                .bank_B_we   (bank_B_we[c]),
                .bank_B_wdata(bank_B_wdata[c]),
                .bank_B_rdata(bank_B_rdata[c]),
                .quant_cfg   (quant_cfg[c]),
                .act_out     (out_act[c])
            );
        end
    endgenerate

endmodule
