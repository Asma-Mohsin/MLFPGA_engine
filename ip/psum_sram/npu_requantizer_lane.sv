`timescale 1ns / 1ps

module npu_requantizer_lane #(
    parameter int PSUM_WIDTH       = 32,
    parameter int SCALE_WIDTH      = 16,
    parameter int ACTIVATION_WIDTH = 8
)(
    input  wire                                               clk_i,
    input  wire                                               rst_n,

    // Mathematical Configuration
    input  wire signed [PSUM_WIDTH-1:0]                      psum_in,
    input  wire signed [SCALE_WIDTH-1:0]                     scale_m0,
    input  wire        [$clog2(PSUM_WIDTH+SCALE_WIDTH)-1:0] shift_n,
    input  wire signed [ACTIVATION_WIDTH-1:0]                zero_point,

    // Direct Quantized Output Stream
    output reg  signed [ACTIVATION_WIDTH-1:0]                act_out
);

    localparam int PROD_WIDTH  = PSUM_WIDTH + SCALE_WIDTH; // 48 bits
    localparam int SHIFT_WIDTH = $clog2(PROD_WIDTH);       // 6 bits

    localparam signed [PROD_WIDTH-1:0] ONE        = 1;
    localparam signed [PROD_WIDTH-1:0] SIGNED_MAX = (ONE << (ACTIVATION_WIDTH - 1)) - 1;
    localparam signed [PROD_WIDTH-1:0] SIGNED_MIN = -(ONE << (ACTIVATION_WIDTH - 1));

    // -------------------------------------------------------------------------
    // Stage 1: Fixed-Point Multiplier
    // -------------------------------------------------------------------------
    reg signed [PROD_WIDTH-1:0]       stage1_prod;
    reg        [SHIFT_WIDTH-1:0]      stage1_shift;
    reg signed [ACTIVATION_WIDTH-1:0] stage1_zp;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            stage1_prod  <= '0;
            stage1_shift <= '0;
            stage1_zp    <= '0;
        end else begin
            stage1_prod  <= psum_in * scale_m0;
            stage1_shift <= shift_n;
            stage1_zp    <= zero_point;
        end
    end

    // -------------------------------------------------------------------------
    // Stage 2: Rounding, Arithmetic Right-Shift & Saturation Clamp
    // Google Edge TPU Standard: Round-Half-Away-From-Zero
    // -------------------------------------------------------------------------
    logic signed [PROD_WIDTH-1:0]       round_offset;
    logic signed [PROD_WIDTH-1:0]       rounded_prod;
    logic signed [PROD_WIDTH-1:0]       shifted_val;
    logic signed [PROD_WIDTH-1:0]       offset_val;
    logic signed [ACTIVATION_WIDTH-1:0] clamped_val;

    always_comb begin
        if (stage1_shift > 6'd0) begin
            round_offset = (ONE << (stage1_shift - 1'b1)) - (stage1_prod[PROD_WIDTH-1] ? ONE : '0);
        end else begin
            round_offset = '0;
        end
    end

    always_comb begin
        rounded_prod = stage1_prod + round_offset;
        shifted_val  = rounded_prod >>> stage1_shift;
        
        offset_val   = shifted_val + PROD_WIDTH'($signed(stage1_zp));

        if (offset_val > SIGNED_MAX)
            clamped_val = SIGNED_MAX[ACTIVATION_WIDTH-1:0];
        else if (offset_val < SIGNED_MIN)
            clamped_val = SIGNED_MIN[ACTIVATION_WIDTH-1:0];
        else
            clamped_val = offset_val[ACTIVATION_WIDTH-1:0];
    end

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            act_out <= '0;
        end else begin
            act_out <= clamped_val;
        end
    end

endmodule