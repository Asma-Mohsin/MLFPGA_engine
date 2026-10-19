`timescale 1ns / 1ps

module quant_shift_chain #(
    parameter int ARRAY_WIDTH      = 8,
    parameter int ACTIVATION_WIDTH = 8,
    parameter int PSUM_WIDTH       = 32,
    parameter int SCALE_WIDTH      = 16,

    localparam int PROD_WIDTH      = PSUM_WIDTH + SCALE_WIDTH,
    localparam int SHIFT_WIDTH     = $clog2(PROD_WIDTH),
    localparam int QUANT_CFG_WIDTH = SCALE_WIDTH + SHIFT_WIDTH + ACTIVATION_WIDTH
)(
    input  wire                                               clk_i,
    input  wire                                               rst_n,

    input  wire        [QUANT_CFG_WIDTH-1:0]                  quant_shift_in,
    input  wire                                               quant_shift_en,

    output wire        [ARRAY_WIDTH-1:0][QUANT_CFG_WIDTH-1:0] quant_cfg_out
);

    reg [QUANT_CFG_WIDTH-1:0] quant_cfg_chain [0:ARRAY_WIDTH-1];

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < ARRAY_WIDTH; i++) begin
                quant_cfg_chain[i] <= '0;
            end
        end else if (quant_shift_en) begin
            quant_cfg_chain[0] <= quant_shift_in;
            for (int i = 1; i < ARRAY_WIDTH; i++) begin
                quant_cfg_chain[i] <= quant_cfg_chain[i-1];
            end
        end
    end

    genvar q;
    generate
        for (q = 0; q < ARRAY_WIDTH; q++) begin : gen_cfg_out
            assign quant_cfg_out[q] = quant_cfg_chain[q];
        end
    endgenerate

endmodule

