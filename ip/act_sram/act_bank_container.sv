`timescale 1ns / 1ps

module act_bank_container #(
    parameter int ACTIVATION_WIDTH = 8,
    parameter int ACT_WORDS        = 512,
    parameter int WEIGHT_WIDTH     = 8,
    parameter int XBAR_SEL_WIDTH   = 4,

    localparam int ACT_ADDR_WIDTH  = $clog2(ACT_WORDS)
)(
    // West Interface (facing Slice 2 / eFPGA Fabric)
    input  wire                                           clk_i,
    input  wire                                           act_we,
    input  wire        [ACT_ADDR_WIDTH-1:0]               act_addr,
    input  wire signed [ACTIVATION_WIDTH-1:0]             act_wdata,
    output wire signed [ACTIVATION_WIDTH-1:0]             act_rdata_west,

    input  wire signed [WEIGHT_WIDTH-1:0]                 weight_in_west,
    input  wire                                           weight_shift_en_west,
    input  wire        [XBAR_SEL_WIDTH-1:0]               xbar_sel_west,
    output wire signed [ACTIVATION_WIDTH-1:0]             out_act_west,

    // East Interface (facing Slice 4 / Compute Core)
    output wire                                           clk_o,
    output wire signed [ACTIVATION_WIDTH-1:0]             act_rdata_east,
    output wire signed [WEIGHT_WIDTH-1:0]                 weight_in_east,
    output wire                                           weight_shift_en_east,
    output wire        [XBAR_SEL_WIDTH-1:0]               xbar_sel_east,
    input  wire signed [ACTIVATION_WIDTH-1:0]             out_act_east
);

    wire signed [ACTIVATION_WIDTH-1:0] sram_rdata;

    sram_bank #(
        .DATA_WIDTH(ACTIVATION_WIDTH),
        .DEPTH     (ACT_WORDS)
    ) act_sram_inst (
        .clk_i(clk_i),
        .we   (act_we),
        .addr (act_addr),
        .wdata(act_wdata),
        .rdata(sram_rdata)
    );

    // Local SRAM read data drives both West (Fabric readback) and East (Compute Core)
    assign act_rdata_west = sram_rdata;
    assign act_rdata_east = sram_rdata;

    // Clock feedthrough to East side
    assign clk_o = clk_i;

    // West-to-East feedthrough channels
    assign weight_in_east       = weight_in_west;
    assign weight_shift_en_east = weight_shift_en_west;
    assign xbar_sel_east        = xbar_sel_west;

    // East-to-West feedthrough channel (drained activations from Slice 5/4 to Fabric)
    assign out_act_west = out_act_east;

endmodule
