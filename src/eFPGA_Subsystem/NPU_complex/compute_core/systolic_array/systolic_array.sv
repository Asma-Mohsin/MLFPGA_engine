`timescale 1ns / 1ps

module systolic_array #(
    parameter int ARRAY_HEIGHT     = 8,
    parameter int ARRAY_WIDTH      = 8,
    parameter int ACTIVATION_WIDTH = 8,
    parameter int WEIGHT_WIDTH     = 8,
    parameter int PSUM_WIDTH       = 32,
    parameter int WEIGHT_SPLIT     = 8, // 1 = 64-bit (8 rows), 2 = 32-bit (4 rows/block), 8 = per-row (1 bit/row)

    localparam int ROWS_PER_SPLIT  = ARRAY_HEIGHT / WEIGHT_SPLIT
)(
    input  wire                                                          clk_i,
    input  wire                                                          rst_n,
    input  wire                                                          array_en,
    
    // Compute Data Stream
    input  wire signed [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0]          act_in,
    input  wire signed [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0]                 psum_in,
    output wire signed [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0]                 psum_out,
    
    // Parameterized Horizontal Weight Shift Chain
    input  wire signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0]              weight_shift_in,
    input  wire        [WEIGHT_SPLIT-1:0]                                weight_shift_en,
    input  wire                                                          swap_weights
);

    wire clk_compute;

    cg_cell cg_compute_inst (
        .clk_i    (clk_i),
        .enable_i (array_en),
        .clk_o    (clk_compute)
    );

    wire signed [ACTIVATION_WIDTH-1:0] act_wire   [ARRAY_HEIGHT][ARRAY_WIDTH+1];
    wire signed [PSUM_WIDTH-1:0]       psum_wire  [ARRAY_HEIGHT+1][ARRAY_WIDTH];
    wire signed [WEIGHT_WIDTH-1:0]     w_chain    [ARRAY_HEIGHT][ARRAY_WIDTH+1];

    // =========================================================================
    // Systolic Weight Swap Wavefront Pipeline
    // Skews the swap trigger diagonally: 1 cycle South (row), 1 cycle East (col)
    // =========================================================================
    logic swap_chain [ARRAY_HEIGHT][ARRAY_WIDTH];

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            for (int r_idx = 0; r_idx < ARRAY_HEIGHT; r_idx++) begin
                for (int c_idx = 0; c_idx < ARRAY_WIDTH; c_idx++) begin
                    swap_chain[r_idx][c_idx] <= 1'b0;
                end
            end
        end else begin
            for (int r_idx = 0; r_idx < ARRAY_HEIGHT; r_idx++) begin
                for (int c_idx = 0; c_idx < ARRAY_WIDTH; c_idx++) begin
                    if (r_idx == 0 && c_idx == 0) begin
                        swap_chain[0][0] <= swap_weights;
                    end else if (c_idx == 0) begin
                        swap_chain[r_idx][0] <= swap_chain[r_idx-1][0];
                    end else begin
                        swap_chain[r_idx][c_idx] <= swap_chain[r_idx][c_idx-1];
                    end
                end
            end
        end
    end

    genvar r, c;
    generate
        for (r = 0; r < ARRAY_HEIGHT; r++) begin : gen_row_io
            assign act_wire[r][0] = act_in[r];
            assign w_chain[r][0]  = weight_shift_in[r];
        end

        for (c = 0; c < ARRAY_WIDTH; c++) begin : gen_col_io
            assign psum_wire[0][c] = psum_in[c];
            assign psum_out[c]     = psum_wire[ARRAY_HEIGHT][c];
        end
    endgenerate

    generate
        for (r = 0; r < ARRAY_HEIGHT; r++) begin : gen_row
            localparam int BLOCK_IDX = r / ROWS_PER_SPLIT;

            for (c = 0; c < ARRAY_WIDTH; c++) begin : gen_col
                pe #(
                    .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
                    .WEIGHT_WIDTH    (WEIGHT_WIDTH),
                    .PSUM_WIDTH      (PSUM_WIDTH)
                ) pe_inst (
                    .clk_i           (clk_i),
                    .clk_compute     (clk_compute),
                    .rst_n           (rst_n),
                    .act_in          (act_wire[r][c]),
                    .psum_in         (psum_wire[r][c]),
                    .act_out         (act_wire[r][c+1]),
                    .psum_out        (psum_wire[r+1][c]),
                    .weight_shift_in (w_chain[r][c]),
                    .weight_shift_out(w_chain[r][c+1]),
                    .weight_shift_en (weight_shift_en[BLOCK_IDX]),
                    .swap_weights    (swap_chain[r][c]) // Systolic per-PE swap trigger
                );
            end
        end
    endgenerate

endmodule