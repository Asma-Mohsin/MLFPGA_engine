`timescale 1ns / 1ps

/* ===============================================================================================
 * Unified Integrated Clock Gating (ICG) Primitive Wrapper
 *
 * Provides a portable clock-gating cell across target platforms:
 * - ASIC (Default): Instantiates foundry IHP 130nm SG13G2 latch-based clock gate (sg13g2_lgcp_1).
 * - Xilinx FPGA (VIVADO): Instantiates dedicated global clock buffer with enable (BUFGCE).
 * - Simulation (__ICARUS__): Behavioral negative-edge latch and AND gate to prevent glitches.
 * =============================================================================================== */

module cg_cell (
    input  wire clk_i,
    input  wire enable_i,
    output wire clk_o
);

`ifdef VIVADO
    BUFGCE u_bufgce (
        .I  (clk_i),
        .CE (enable_i),
        .O  (clk_o)
    );
`elsif __ICARUS__
    reg en_latch;
    always @(clk_i or enable_i) begin
        if (!clk_i) begin
            en_latch <= enable_i;
        end
    end
    assign clk_o = clk_i & en_latch;
`else
    sg13g2_lgcp_1 u_icg (
        .CLK  (clk_i),
        .GATE (enable_i),
        .GCLK (clk_o)
    );
`endif

endmodule

