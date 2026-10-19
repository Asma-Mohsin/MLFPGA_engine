`timescale 1ns / 1ps

module npu_wrapper #(
    parameter int ARRAY_HEIGHT     = 8,
    parameter int ARRAY_WIDTH      = 8,
    parameter int TILE_SIZE        = 16,
    parameter int ACT_HALO_PAD     = 2,
    parameter int ACTIVATION_WIDTH = 8,
    parameter int WEIGHT_WIDTH     = 8,
    parameter int PSUM_WIDTH       = 32,
    parameter int SCALE_WIDTH      = 16,
    parameter int WEIGHT_SPLIT     = 8,
    parameter int USE_LADDER_CLOCKS = 0,

    localparam int PSUM_WORDS       = TILE_SIZE * TILE_SIZE,
    localparam int ACT_WORDS        = (TILE_SIZE * TILE_SIZE) * ACT_HALO_PAD,
    localparam int PSUM_ADDR_WIDTH  = $clog2(PSUM_WORDS),
    localparam int ACT_ADDR_WIDTH   = $clog2(ACT_WORDS),
    localparam int NUM_ACT_BANKS    = ARRAY_HEIGHT,
    localparam int XBAR_SEL_WIDTH   = $clog2(ARRAY_HEIGHT) + 1,
    localparam int BANK_SEL_WIDTH   = $clog2(ARRAY_WIDTH),
    localparam int PROD_WIDTH       = PSUM_WIDTH + SCALE_WIDTH,
    localparam int SHIFT_WIDTH      = $clog2(PROD_WIDTH),
    localparam int QUANT_CFG_WIDTH  = SCALE_WIDTH + SHIFT_WIDTH + ACTIVATION_WIDTH
)(
    input  wire                                                          clk_i,
    input  wire        [NUM_ACT_BANKS-1:0]                               act_clk_i,
    input  wire                                                          rst_n,
    input  wire                                                          array_en,
    input  wire                                                          psum_systolic_en,
    input  wire                                                          psum_lut_en,

    input  wire        [ARRAY_HEIGHT-1:0][XBAR_SEL_WIDTH-1:0]            crossbar_sel,

    input  wire signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0]              weight_shift_in,
    input  wire        [WEIGHT_SPLIT-1:0]                                weight_shift_en,
    input  wire                                                          swap_weights,

    input  wire        [QUANT_CFG_WIDTH-1:0]                             quant_shift_in,
    input  wire                                                          quant_shift_en,

    input  wire                                                          psum_skew_en,
    input  wire                                                          compute_bank_swap,

    input  wire        [PSUM_ADDR_WIDTH-1:0]                             psum_A_addr,
    input  wire        [ARRAY_WIDTH-1:0]                                 psum_A_we,
    input  wire signed [PSUM_WIDTH-1:0]                                  psum_A_wdata,
    input  wire        [BANK_SEL_WIDTH-1:0]                              psum_A_read_bank_sel,
    output wire signed [PSUM_WIDTH-1:0]                                  psum_A_rdata,

    input  wire        [PSUM_ADDR_WIDTH-1:0]                             psum_B_addr,
    input  wire        [ARRAY_WIDTH-1:0]                                 psum_B_we,
    input  wire signed [PSUM_WIDTH-1:0]                                  psum_B_wdata,
    input  wire        [BANK_SEL_WIDTH-1:0]                              psum_B_read_bank_sel,
    output wire signed [PSUM_WIDTH-1:0]                                  psum_B_rdata,

    input  wire        [NUM_ACT_BANKS-1:0]                               ext_act_sram_we,
    input  wire        [NUM_ACT_BANKS-1:0][ACT_ADDR_WIDTH-1:0]           ext_act_sram_addr,
    input  wire signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0]         ext_act_sram_wdata,
    output wire signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0]         act_sram_rdata,

    output wire signed [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0]           out_act
);

    wire        [ARRAY_WIDTH-1:0][PSUM_ADDR_WIDTH-1:0] psum_A_sram_addr;
    wire        [ARRAY_WIDTH-1:0]                      psum_A_sram_we;
    wire signed [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0]      psum_A_sram_wdata;
    wire signed [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0]      psum_A_sram_rdata;

    wire        [ARRAY_WIDTH-1:0][PSUM_ADDR_WIDTH-1:0] psum_B_sram_addr;
    wire        [ARRAY_WIDTH-1:0]                      psum_B_sram_we;
    wire signed [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0]      psum_B_sram_wdata;
    wire signed [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0]      psum_B_sram_rdata;

    wire        [ARRAY_WIDTH-1:0][QUANT_CFG_WIDTH-1:0] quant_cfg;

    wire signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0] act_rdata_core;
    wire signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0]      weight_shift_in_core;
    wire        [WEIGHT_SPLIT-1:0]                        weight_shift_en_core;
    wire        [ARRAY_HEIGHT-1:0][XBAR_SEL_WIDTH-1:0]    crossbar_sel_core;
    wire signed [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0]   requant_out_act;

    wire [NUM_ACT_BANKS-1:0]                              effective_act_clk;
    wire                                                  act_forwarded_core_clk;
    wire                                                  npu_clk_core;

    assign effective_act_clk = (USE_LADDER_CLOCKS != 0) ? act_clk_i : {NUM_ACT_BANKS{clk_i}};

`ifdef VIVADO
    assign npu_clk_core = clk_i;
`else
    assign npu_clk_core = act_forwarded_core_clk;
`endif

    act_buffer_top #(
        .NUM_ACT_BANKS   (NUM_ACT_BANKS),
        .ACT_WORDS       (ACT_WORDS),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .WEIGHT_WIDTH    (WEIGHT_WIDTH),
        .XBAR_SEL_WIDTH  (XBAR_SEL_WIDTH)
    ) act_buffer_stage (
        .act_clk_i          (effective_act_clk),
        .ext_act_sram_we     (ext_act_sram_we),
        .ext_act_sram_addr   (ext_act_sram_addr),
        .ext_act_sram_wdata  (ext_act_sram_wdata),
        .act_sram_rdata      (act_sram_rdata),
        .weight_shift_in     (weight_shift_in),
        .weight_shift_en     (weight_shift_en),
        .crossbar_sel        (crossbar_sel),
        .out_act             (out_act),

        .npu_clk_core        (act_forwarded_core_clk),
        .clk_o               (),
        .act_sram_rdata_east (act_rdata_core),
        .weight_shift_in_east(weight_shift_in_core),
        .weight_shift_en_east(weight_shift_en_core),
        .crossbar_sel_east   (crossbar_sel_core),
        .out_act_east        (requant_out_act)
    );

    compute_core_top #(
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .TILE_SIZE       (TILE_SIZE),
        .ACT_HALO_PAD    (ACT_HALO_PAD),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .WEIGHT_WIDTH    (WEIGHT_WIDTH),
        .PSUM_WIDTH      (PSUM_WIDTH),
        .SCALE_WIDTH     (SCALE_WIDTH),
        .WEIGHT_SPLIT    (WEIGHT_SPLIT)
    ) npu_compute_core (
        .clk_i               (npu_clk_core),
        .rst_n               (rst_n),
        .array_en            (array_en),
        .psum_systolic_en    (psum_systolic_en),
        .crossbar_sel        (crossbar_sel_core),
        .weight_shift_in     (weight_shift_in_core),
        .weight_shift_en     (weight_shift_en_core),
        .swap_weights        (swap_weights),
        .quant_shift_in      (quant_shift_in),
        .quant_shift_en      (quant_shift_en),
        .psum_skew_en        (psum_skew_en),
        .compute_bank_swap   (compute_bank_swap),
        .psum_A_addr         (psum_A_addr),
        .psum_A_we           (psum_A_we),
        .psum_A_wdata        (psum_A_wdata),
        .psum_A_read_bank_sel(psum_A_read_bank_sel),
        .psum_A_rdata        (psum_A_rdata),
        .psum_B_addr         (psum_B_addr),
        .psum_B_we           (psum_B_we),
        .psum_B_wdata        (psum_B_wdata),
        .psum_B_read_bank_sel(psum_B_read_bank_sel),
        .psum_B_rdata        (psum_B_rdata),
        .act_sram_rdata      (act_rdata_core),
        .psum_A_sram_addr    (psum_A_sram_addr),
        .psum_A_sram_we      (psum_A_sram_we),
        .psum_A_sram_wdata   (psum_A_sram_wdata),
        .psum_A_sram_rdata   (psum_A_sram_rdata),
        .psum_B_sram_addr    (psum_B_sram_addr),
        .psum_B_sram_we      (psum_B_sram_we),
        .psum_B_sram_wdata   (psum_B_sram_wdata),
        .psum_B_sram_rdata   (psum_B_sram_rdata),
        .quant_cfg_out       (quant_cfg)
    );

    psum_requant_top #(
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .PSUM_WIDTH      (PSUM_WIDTH),
        .PSUM_WORDS      (PSUM_WORDS),
        .SCALE_WIDTH     (SCALE_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH)
    ) psum_requant_stage (
        .clk_i       (npu_clk_core),
        .rst_n       (rst_n),
        .psum_lut_en (psum_lut_en),
        .bank_A_addr (psum_A_sram_addr),
        .bank_A_we   (psum_A_sram_we),
        .bank_A_wdata(psum_A_sram_wdata),
        .bank_A_rdata(psum_A_sram_rdata),
        .bank_B_addr (psum_B_sram_addr),
        .bank_B_we   (psum_B_sram_we),
        .bank_B_wdata(psum_B_sram_wdata),
        .bank_B_rdata(psum_B_sram_rdata),
        .quant_cfg   (quant_cfg),
        .out_act     (requant_out_act)
    );

endmodule