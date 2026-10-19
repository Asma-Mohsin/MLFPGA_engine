`timescale 1ns / 1ps

module compute_core_top #(
    parameter int ARRAY_HEIGHT     = 8,
    parameter int ARRAY_WIDTH      = 8,
    parameter int TILE_SIZE        = 16,
    parameter int ACT_HALO_PAD     = 2,
    parameter int ACTIVATION_WIDTH = 8,
    parameter int WEIGHT_WIDTH     = 8,
    parameter int PSUM_WIDTH       = 32,
    parameter int SCALE_WIDTH      = 16,
    parameter int WEIGHT_SPLIT     = 8,

    localparam int PSUM_WORDS      = TILE_SIZE * TILE_SIZE,
    localparam int ACT_WORDS       = (TILE_SIZE * TILE_SIZE) * ACT_HALO_PAD,
    localparam int PSUM_ADDR_WIDTH = $clog2(PSUM_WORDS),
    localparam int ACT_ADDR_WIDTH  = $clog2(ACT_WORDS),
    localparam int NUM_ACT_BANKS   = ARRAY_HEIGHT,
    localparam int XBAR_SEL_WIDTH  = $clog2(ARRAY_HEIGHT) + 1,
    localparam int BANK_SEL_WIDTH  = $clog2(ARRAY_WIDTH),
    localparam int PROD_WIDTH      = PSUM_WIDTH + SCALE_WIDTH,
    localparam int SHIFT_WIDTH     = $clog2(PROD_WIDTH),
    localparam int QUANT_CFG_WIDTH = SCALE_WIDTH + SHIFT_WIDTH + ACTIVATION_WIDTH
)(
    input  wire                                                              clk_i,
    input  wire                                                              rst_n,

    // Core Execution Controls
    input  wire                                                              array_en,
    input  wire                                                              psum_systolic_en,

    // Crossbar Routing
    input  wire        [ARRAY_HEIGHT-1:0][XBAR_SEL_WIDTH-1:0]                crossbar_sel,

    // Parameterized Weight Interface
    input  wire signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0]                  weight_shift_in,
    input  wire        [WEIGHT_SPLIT-1:0]                                    weight_shift_en,
    input  wire                                                              swap_weights,

    // Quantizer Shift Chain Configuration
    input  wire        [QUANT_CFG_WIDTH-1:0]                                 quant_shift_in,
    input  wire                                                              quant_shift_en,

    // PSum Datapath & Mode Controls
    input  wire                                                              psum_skew_en,
    input  wire                                                              compute_bank_swap,

    // Fabric PSum Port A Interface
    input  wire        [PSUM_ADDR_WIDTH-1:0]                                 psum_A_addr,
    input  wire        [ARRAY_WIDTH-1:0]                                     psum_A_we,
    input  wire signed [PSUM_WIDTH-1:0]                                      psum_A_wdata,
    input  wire        [BANK_SEL_WIDTH-1:0]                                  psum_A_read_bank_sel,
    output wire signed [PSUM_WIDTH-1:0]                                      psum_A_rdata,

    // Fabric PSum Port B Interface
    input  wire        [PSUM_ADDR_WIDTH-1:0]                                 psum_B_addr,
    input  wire        [ARRAY_WIDTH-1:0]                                     psum_B_we,
    input  wire signed [PSUM_WIDTH-1:0]                                      psum_B_wdata,
    input  wire        [BANK_SEL_WIDTH-1:0]                                  psum_B_read_bank_sel,
    output wire signed [PSUM_WIDTH-1:0]                                      psum_B_rdata,

    // Physical Interface to Activation Buffer Block (Slice 3)
    input  wire signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0]             act_sram_rdata,

    // Physical Interface to PSum Requant Block Bank A (Slice 5)
    output logic       [ARRAY_WIDTH-1:0][PSUM_ADDR_WIDTH-1:0]                psum_A_sram_addr,
    output logic       [ARRAY_WIDTH-1:0]                                     psum_A_sram_we,
    output logic signed [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0]                    psum_A_sram_wdata,
    input  wire signed [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0]                     psum_A_sram_rdata,

    // Physical Interface to PSum Requant Block Bank B (Slice 5)
    output logic       [ARRAY_WIDTH-1:0][PSUM_ADDR_WIDTH-1:0]                psum_B_sram_addr,
    output logic       [ARRAY_WIDTH-1:0]                                     psum_B_sram_we,
    output logic signed [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0]                    psum_B_sram_wdata,
    input  wire signed [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0]                     psum_B_sram_rdata,

    // Quantizer Configuration Outputs to Slice 5 Containers
    output wire        [ARRAY_WIDTH-1:0][QUANT_CFG_WIDTH-1:0]                quant_cfg_out
);

    // =========================================================================
    // 1. Crossbar Pipeline & Instance
    // =========================================================================
    logic [ARRAY_HEIGHT-1:0][XBAR_SEL_WIDTH-1:0] crossbar_sel_pipe;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            for (int r = 0; r < ARRAY_HEIGHT; r++) begin
                crossbar_sel_pipe[r] <= {1'b1, {(XBAR_SEL_WIDTH-1){1'b0}}};
            end
        end else begin
            crossbar_sel_pipe <= crossbar_sel;
        end
    end

    wire signed [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0] xbar_out;

    npu_crossbar #(
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH)
    ) xbar_inst (
        .in_data     (act_sram_rdata),
        .crossbar_sel(crossbar_sel_pipe),
        .out_data    (xbar_out)
    );

    // =========================================================================
    // 2. Systolic Array Core
    // =========================================================================
    logic signed [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0] array_psum_in;
    wire  signed [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0] array_psum_out;

    systolic_array #(
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .WEIGHT_WIDTH    (WEIGHT_WIDTH),
        .PSUM_WIDTH      (PSUM_WIDTH),
        .WEIGHT_SPLIT    (WEIGHT_SPLIT)
    ) array_inst (
        .clk_i          (clk_i),
        .rst_n          (rst_n),
        .array_en       (array_en),
        .act_in         (xbar_out),
        .psum_in        (array_psum_in),
        .psum_out       (array_psum_out),
        .weight_shift_in(weight_shift_in),
        .weight_shift_en(weight_shift_en),
        .swap_weights   (swap_weights)
    );

    // =========================================================================
    // 3. Address & Bank Swap Skew Pipeline Registers
    // =========================================================================
    logic [PSUM_ADDR_WIDTH-1:0] psum_A_addr_col [ARRAY_WIDTH];
    logic [PSUM_ADDR_WIDTH-1:0] psum_B_addr_col [ARRAY_WIDTH];
    logic                       bank_swap_col   [ARRAY_WIDTH];

    reg   [PSUM_ADDR_WIDTH-1:0] pipe_A_addr     [1:ARRAY_WIDTH-1];
    reg   [PSUM_ADDR_WIDTH-1:0] pipe_B_addr     [1:ARRAY_WIDTH-1];
    reg                         pipe_bank_swap  [1:ARRAY_WIDTH-1];

    logic compute_bank_swap_reg;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            compute_bank_swap_reg <= 1'b0;
        end else begin
            compute_bank_swap_reg <= compute_bank_swap;
        end
    end

    assign psum_A_addr_col[0] = psum_A_addr;
    assign psum_B_addr_col[0] = psum_B_addr;
    assign bank_swap_col[0]   = compute_bank_swap_reg;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            for (int col = 1; col < ARRAY_WIDTH; col++) begin
                pipe_A_addr[col]    <= '0;
                pipe_B_addr[col]    <= '0;
                pipe_bank_swap[col] <= 1'b0;
            end
        end else begin
            pipe_A_addr[1]    <= psum_A_addr_col[0];
            pipe_B_addr[1]    <= psum_B_addr_col[0];
            pipe_bank_swap[1] <= bank_swap_col[0];

            for (int col = 2; col < ARRAY_WIDTH; col++) begin
                pipe_A_addr[col]    <= psum_A_addr_col[col-1];
                pipe_B_addr[col]    <= psum_B_addr_col[col-1];
                pipe_bank_swap[col] <= bank_swap_col[col-1];
            end
        end
    end

    genvar col;
    generate
        for (col = 1; col < ARRAY_WIDTH; col++) begin : gen_col_skew_mux
            assign psum_A_addr_col[col] = psum_skew_en ? pipe_A_addr[col]    : psum_A_addr;
            assign psum_B_addr_col[col] = psum_skew_en ? pipe_B_addr[col]    : psum_B_addr;
            assign bank_swap_col[col]   = psum_skew_en ? pipe_bank_swap[col] : compute_bank_swap_reg;
        end
    endgenerate

    // =========================================================================
    // 4. Memory Routing Logic (Compute vs Fabric DMA Multiplexers)
    // =========================================================================
    always_comb begin : blk_mem_routing
        for (int i = 0; i < ARRAY_WIDTH; i++) begin
            array_psum_in[i] = (!bank_swap_col[i]) ? psum_A_sram_rdata[i] : psum_B_sram_rdata[i];

            if (psum_systolic_en) begin
                if (!bank_swap_col[i]) begin
                    psum_A_sram_addr[i]  = psum_A_addr_col[i];
                    psum_A_sram_we[i]    = psum_A_we[i];
                    psum_A_sram_wdata[i] = psum_A_wdata;

                    psum_B_sram_addr[i]  = psum_B_addr_col[i];
                    psum_B_sram_we[i]    = psum_B_we[i];
                    psum_B_sram_wdata[i] = array_psum_out[i];
                end else begin
                    psum_B_sram_addr[i]  = psum_B_addr_col[i];
                    psum_B_sram_we[i]    = psum_B_we[i];
                    psum_B_sram_wdata[i] = psum_B_wdata;

                    psum_A_sram_addr[i]  = psum_A_addr_col[i];
                    psum_A_sram_we[i]    = psum_A_we[i];
                    psum_A_sram_wdata[i] = array_psum_out[i];
                end
            end else begin
                psum_A_sram_addr[i]  = psum_A_addr_col[i];
                psum_A_sram_we[i]    = psum_A_we[i];
                psum_A_sram_wdata[i] = psum_A_wdata;

                psum_B_sram_addr[i]  = psum_B_addr_col[i];
                psum_B_sram_we[i]    = psum_B_we[i];
                psum_B_sram_wdata[i] = psum_B_wdata;
            end
        end
    end

    // =========================================================================
    // 5. Quantizer Configuration Shift Chain
    // =========================================================================
    quant_shift_chain #(
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .PSUM_WIDTH      (PSUM_WIDTH),
        .SCALE_WIDTH     (SCALE_WIDTH)
    ) quant_chain_inst (
        .clk_i         (clk_i),
        .rst_n         (rst_n),
        .quant_shift_in(quant_shift_in),
        .quant_shift_en(quant_shift_en),
        .quant_cfg_out (quant_cfg_out)
    );

    // =========================================================================
    // 6. Direct Fabric Readback Outputs
    // =========================================================================
    assign psum_A_rdata = psum_A_sram_rdata[BANK_SEL_WIDTH'(psum_A_read_bank_sel)];
    assign psum_B_rdata = psum_B_sram_rdata[BANK_SEL_WIDTH'(psum_B_read_bank_sel)];

endmodule

