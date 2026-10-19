`timescale 1ns / 1ps

module pmp_math #(
    parameter int NUM_PMP_REGIONS   = 2,
    parameter bit PAGE_GRANULARITY  = 1'b1, // 1 = 4KB Aligned Pages, 0 = Exact Word Granularity
    parameter int ADDR_WIDTH        = 32
)(
    input  logic g_en_i,

    // Base & Limit Registers:
    // When PAGE_GRANULARITY == 1: Base/Limit registers store Page Frame Numbers (bits [ADDR_WIDTH-1:12])
    // Control bits: base_i[r][1:0] = {Write_En, Read_En}, limit_i[r][1:0] = {Sec_Req, Priv_Req}
    input  logic [NUM_PMP_REGIONS-1:0][31:0] base_i,
    input  logic [NUM_PMP_REGIONS-1:0][31:0] limit_i,

    input  logic [31:0] awaddr_i,
    input  logic [7:0]  awlen_i,
    input  logic [2:0]  awsize_i,
    input  logic [2:0]  awprot_i,
    input  logic        awvalid_i,

    input  logic [31:0] araddr_i,
    input  logic [7:0]  arlen_i,
    input  logic [2:0]  arsize_i,
    input  logic [2:0]  arprot_i,
    input  logic        arvalid_i,

    output logic        violation_r_o,
    output logic        violation_w_o
);

    localparam int ADDR_SHIFT = PAGE_GRANULARITY ? 12 : 2;
    localparam int COMP_WIDTH = ADDR_WIDTH - ADDR_SHIFT;

    // Security Flag Extraction (PROT[0]: Privileged, PROT[1]: Non-Secure)
    wire aw_is_priv = awprot_i[0]; 
    wire aw_is_sec  = ~awprot_i[1];
    wire ar_is_priv = arprot_i[0]; 
    wire ar_is_sec  = ~arprot_i[1];

    logic [NUM_PMP_REGIONS-1:0] aw_region_ok;
    logic [NUM_PMP_REGIONS-1:0] ar_region_ok;
    
    wire aw_allowed;
    wire ar_allowed;

    // =========================================================================
    // DUAL-MODE LOGIC IMPLEMENTATION
    // (Assumes protocol compliance guaranteed by watchdog firewall)
    // =========================================================================
    generate
        if (PAGE_GRANULARITY == 1) begin : gen_fast_4k_page_math
            // -----------------------------------------------------------------
            // 4KB ALIGNED PAGE MODE (Pure Comparators, Zero Adders)
            // -----------------------------------------------------------------
            wire [COMP_WIDTH-1:0] aw_pfn = awaddr_i[ADDR_WIDTH-1 : 12];
            wire [COMP_WIDTH-1:0] ar_pfn = araddr_i[ADDR_WIDTH-1 : 12];

            for (genvar r = 0; r < NUM_PMP_REGIONS; r++) begin : pmp_checks_4k
                wire read_en   = base_i[r][0];
                wire write_en  = base_i[r][1];
                wire req_priv  = limit_i[r][0];
                wire req_sec   = limit_i[r][1];

                wire [COMP_WIDTH-1:0] base_pfn  = base_i[r][ADDR_WIDTH-1 : 12];
                wire [COMP_WIDTH-1:0] limit_pfn = limit_i[r][ADDR_WIDTH-1 : 12];

                wire aw_in_bounds = (aw_pfn >= base_pfn) && (aw_pfn < limit_pfn);
                wire ar_in_bounds = (ar_pfn >= base_pfn) && (ar_pfn < limit_pfn);

                wire aw_sec_ok = (!req_priv || aw_is_priv) && (!req_sec || aw_is_sec);
                wire ar_sec_ok = (!req_priv || ar_is_priv) && (!req_sec || ar_is_sec);

                assign aw_region_ok[r] = write_en && aw_in_bounds && aw_sec_ok;
                assign ar_region_ok[r] = read_en  && ar_in_bounds && ar_sec_ok;
            end

            assign aw_allowed = |aw_region_ok;
            assign ar_allowed = |ar_region_ok;

        end else begin : gen_exact_word_math
            // -----------------------------------------------------------------
            // EXACT WORD GRANULARITY MODE
            // -----------------------------------------------------------------
            wire [10:0] aw_burst_bytes = 11'((11'(awlen_i) + 11'd1) << awsize_i[1:0]);
            wire [10:0] ar_burst_bytes = 11'((11'(arlen_i) + 11'd1) << arsize_i[1:0]);

            localparam int CALC_W = ADDR_WIDTH + 1;
            wire [ADDR_WIDTH:0] aw_end_addr_full = {1'b0, awaddr_i[ADDR_WIDTH-1:0]} + CALC_W'(aw_burst_bytes) - CALC_W'(1);
            wire [ADDR_WIDTH:0] ar_end_addr_full = {1'b0, araddr_i[ADDR_WIDTH-1:0]} + CALC_W'(ar_burst_bytes) - CALC_W'(1);

            wire aw_4g_wrap = aw_end_addr_full[ADDR_WIDTH];
            wire ar_4g_wrap = ar_end_addr_full[ADDR_WIDTH];

            wire [COMP_WIDTH-1:0] aw_start = awaddr_i[ADDR_WIDTH-1 : 2];
            wire [COMP_WIDTH-1:0] aw_end   = aw_end_addr_full[ADDR_WIDTH-1 : 2];
            wire [COMP_WIDTH-1:0] ar_start = araddr_i[ADDR_WIDTH-1 : 2];
            wire [COMP_WIDTH-1:0] ar_end   = ar_end_addr_full[ADDR_WIDTH-1 : 2];

            for (genvar r = 0; r < NUM_PMP_REGIONS; r++) begin : pmp_checks_word
                wire read_en   = base_i[r][0];
                wire write_en  = base_i[r][1];
                wire req_priv  = limit_i[r][0];
                wire req_sec   = limit_i[r][1];

                wire [COMP_WIDTH-1:0] base_val  = base_i[r][ADDR_WIDTH-1 : 2];
                wire [COMP_WIDTH-1:0] limit_val = limit_i[r][ADDR_WIDTH-1 : 2];

                wire aw_in_bounds = (aw_start >= base_val) && (aw_end < limit_val);
                wire ar_in_bounds = (ar_start >= base_val) && (ar_end < limit_val);

                wire aw_sec_ok = (!req_priv || aw_is_priv) && (!req_sec || aw_is_sec);
                wire ar_sec_ok = (!req_priv || ar_is_priv) && (!req_sec || ar_is_sec);

                assign aw_region_ok[r] = write_en && aw_in_bounds && aw_sec_ok;
                assign ar_region_ok[r] = read_en  && ar_in_bounds && ar_sec_ok;
            end

            assign aw_allowed = (|aw_region_ok) & ~aw_4g_wrap;
            assign ar_allowed = (|ar_region_ok) & ~ar_4g_wrap;
        end
    endgenerate

    // =========================================================================
    // FINAL VIOLATION FLAGS (Zero-Delay Combinational Line to Decoupler)
    // =========================================================================
    assign violation_w_o = g_en_i & (awvalid_i & ~aw_allowed);
    assign violation_r_o = g_en_i & (arvalid_i & ~ar_allowed);

endmodule