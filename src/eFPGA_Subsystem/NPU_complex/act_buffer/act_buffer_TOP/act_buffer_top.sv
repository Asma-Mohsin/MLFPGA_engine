`timescale 1ns / 1ps

module act_buffer_top #(
    parameter int NUM_ACT_BANKS    = 8,
    parameter int ACT_WORDS        = 512,
    parameter int ACTIVATION_WIDTH = 8,
    parameter int WEIGHT_WIDTH     = 8,
    parameter int XBAR_SEL_WIDTH   = 4,

    localparam int ACT_ADDR_WIDTH  = $clog2(ACT_WORDS)
)(
    // West Interface (facing Slice 2 / eFPGA Fabric)
    input  wire        [NUM_ACT_BANKS-1:0]                               act_clk_i,
    input  wire        [NUM_ACT_BANKS-1:0]                               ext_act_sram_we,
    input  wire        [NUM_ACT_BANKS-1:0][ACT_ADDR_WIDTH-1:0]           ext_act_sram_addr,
    input  wire signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0]         ext_act_sram_wdata,
    output wire signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0]         act_sram_rdata,

    input  wire signed [NUM_ACT_BANKS-1:0][WEIGHT_WIDTH-1:0]             weight_shift_in,
    input  wire        [NUM_ACT_BANKS-1:0]                               weight_shift_en,
    input  wire        [NUM_ACT_BANKS-1:0][XBAR_SEL_WIDTH-1:0]           crossbar_sel,
    output wire signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0]         out_act,

    // East Interface (facing Slice 4 / Compute Core)
    output wire                                                          npu_clk_core,
    output wire        [NUM_ACT_BANKS-1:0]                               clk_o,
    output wire signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0]         act_sram_rdata_east,
    output wire signed [NUM_ACT_BANKS-1:0][WEIGHT_WIDTH-1:0]             weight_shift_in_east,
    output wire        [NUM_ACT_BANKS-1:0]                               weight_shift_en_east,
    output wire        [NUM_ACT_BANKS-1:0][XBAR_SEL_WIDTH-1:0]           crossbar_sel_east,
    input  wire signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0]         out_act_east
);

    // Forward the unified core clock from the middle container (Row 3)
    assign npu_clk_core = clk_o[3];

    genvar i;
    generate
        for (i = 0; i < NUM_ACT_BANKS; i++) begin : gen_containers
            act_bank_container container_inst (
                .clk_i               (act_clk_i[i]),
                .act_we              (ext_act_sram_we[i]),
                .act_addr            (ext_act_sram_addr[i]),
                .act_wdata           (ext_act_sram_wdata[i]),
                .act_rdata_west      (act_sram_rdata[i]),
                .weight_in_west      (weight_shift_in[i]),
                .weight_shift_en_west(weight_shift_en[i]),
                .xbar_sel_west       (crossbar_sel[i]),
                .out_act_west        (out_act[i]),

                .clk_o               (clk_o[i]),
                .act_rdata_east      (act_sram_rdata_east[i]),
                .weight_in_east      (weight_shift_in_east[i]),
                .weight_shift_en_east(weight_shift_en_east[i]),
                .xbar_sel_east       (crossbar_sel_east[i]),
                .out_act_east        (out_act_east[i])
            );
        end
    endgenerate

endmodule
