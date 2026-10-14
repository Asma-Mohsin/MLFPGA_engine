`timescale 1ns / 1ps

/* ===============================================================================================
 * eFPGA Manager Register Map
 * ===============================================================================================
 * Total Address Space: 64 KB
 *
 * GLOBAL REGISTERS (Base Address: 0x0000)
 * -----------------------------------------------------------------------------------------------
 * Offset | Register Name  | R/W | Description / Bit Mapping
 * -------|----------------|-----|----------------------------------------------------------------
 * 0x000  | HW_VERSION     | R   | [31:0]: Hardware Version ID (Returns HW_VERSION parameter)
 * 0x004  | GLOBAL_CTRL    | R/W | [4]: BitBang Programmed (W1C) | [3]: BitBang Active (R) | [2]: User Design Loaded (R/W) | [1]: Com Active (R) | [0]: Soft Reset (R/W)
 * 0x008  | CONFIG_DATA    | W   | [31:0]: Config Payload (translates little-endian CPU words to big-endian fabric frames)
 * 0x00C  | CONFIG_COUNT   | R   | [31:0]: Number of words written to CONFIG_DATA
 *
 * PER-SLOT REGISTERS (Base Address: 0x1000 + (Slot_Index * 0x1000))
 * -----------------------------------------------------------------------------------------------
 * Offset | Register Name  | R/W | Description / Bit Mapping
 * -------|----------------|-----|----------------------------------------------------------------
 * 0x000  | SLOT_RESET     | R/W | [25:24]: Bridge DMA/Ctrl Rst | [16]: Wdog Rst | [4]: NPU Rst | [3:0]: Fabric Soft Rst
 * 0x004  | SLOT_CTRL      | R/W | [25:24]: WB M/S En | [19:16]: Wdog Mod En [CM, DS, CS, DM] | [15:13]: DMA ARPROT | [12:10]: DMA AWPROT | [8]: PMP En | [1:0]: Decouple Frc/Req
 * 0x008  | SLOT_STATUS    | R   | [20:16]: Wdog Faults [SoC, C-TO, C-PR, D-TO, D-PR] | [9:8]: PMP W/R Faults | [2:0]: Act/Dec Status
 * 0x00C  | FAULT_CLEAR    | W   | [20:16]: Clear Wdogs [SoC, C-TO, C-PR, D-TO, D-PR] | [9:8]: Clear PMP W/R
 * 0x010  | DEBUG_OUT      | R/W | [31:0]: Static output wires driven to the eFPGA fabric
 * 0x014  | DEBUG_IN       | R   | [31:0]: Static input wires read from the eFPGA fabric
 *
 * DYNAMIC PMP REGISTERS (Base Address: 0x1000 + (Slot_Index * 0x1000) + 0x018)
 * Security Lock: PMP registers are READ-ONLY unless the slot is actively decoupled.
 * -----------------------------------------------------------------------------------------------
 * Offset | Register Name  | R/W | Description / Bit Mapping
 * -------|----------------|-----|----------------------------------------------------------------
 * 0x018  | PMP_BASE_0     | R/W*| [31:0]: Base address for PMP Region 0
 * 0x01C  | PMP_LIMIT_0    | R/W*| [31:0]: Limit address for PMP Region 0 (Lower bits overloaded for PROT)
 * 0x020  | PMP_BASE_1     | R/W*| [31:0]: Base address for PMP Region 1
 * 0x024  | PMP_LIMIT_1    | R/W*| [31:0]: Limit address for PMP Region 1 (Lower bits overloaded for PROT)
 * =============================================================================================== */

module efpga_manager #(
    parameter int NUM_SLOTS = 1,
    parameter int NUM_PMP_REGIONS = 2,
    parameter logic [31:0] HW_VERSION = 32'hFAB00001,
    parameter bit PAGE_GRANULARITY = 1'b1,
    parameter int ADDR_WIDTH = 32,
    
    // Hardware Discovery & Subsystem Generation Parameters
    parameter bit ENABLE_PMP              = 1'b1,
    parameter bit ENABLE_WDOG_CTRL_SLAVE  = 1'b1,
    parameter bit ENABLE_WDOG_DMA_MASTER  = 1'b1,
    parameter bit ENABLE_WDOG_CTRL_MASTER = 1'b0,
    parameter bit ENABLE_WDOG_DMA_SLAVE   = 1'b0,
    parameter bit ENABLE_BRIDGE_CTRL      = 1'b0,
    parameter bit ENABLE_BRIDGE_DMA       = 1'b0
) (
    input  logic        clk_i,
    input  logic        rstn_i,
    
    // AXI4-Lite Slave Interface
    input  logic [31:0] s_axil_awaddr, input  logic [2:0]  s_axil_awprot, input  logic        s_axil_awvalid, output logic        s_axil_awready,
    input  logic [31:0] s_axil_wdata,  input  logic [3:0]  s_axil_wstrb,  input  logic        s_axil_wvalid,  output logic        s_axil_wready,
    output logic [1:0]  s_axil_bresp,  output logic        s_axil_bvalid, input  logic        s_axil_bready,
    input  logic [31:0] s_axil_araddr, input  logic [2:0]  s_axil_arprot, input  logic        s_axil_arvalid, output logic        s_axil_arready,
    output logic [31:0] s_axil_rdata,  output logic [1:0]  s_axil_rresp,  output logic        s_axil_rvalid,  input  logic        s_axil_rready,
    
    // Global eFPGA Interfacing
    output logic [31:0] efpga_config_data_o, output logic efpga_config_we_o, input logic efpga_com_active_i, input logic efpga_bitbang_active_i,
    
    // Per-Slot Control Arrays
    input  logic [NUM_SLOTS-1:0][31:0] slot_debug_in_i,
    output logic [NUM_SLOTS-1:0][31:0] slot_debug_out_o,
    output logic [NUM_SLOTS-1:0][31:0] slot_reset_o,
    
    output logic [NUM_SLOTS-1:0]       decoupler_req_o,
    output logic [NUM_SLOTS-1:0]       decoupler_force_o,
    input  logic [NUM_SLOTS-1:0]       decoupler_is_decoupled_i,
    input  logic [NUM_SLOTS-1:0]       decoupler_host_act_i,
    input  logic [NUM_SLOTS-1:0]       decoupler_dma_act_i,

    input  logic [NUM_SLOTS-1:0]       slot_pmp_r_violation_i,
    input  logic [NUM_SLOTS-1:0]       slot_pmp_w_violation_i,
    
    // Watchdog Inputs
    input  logic [NUM_SLOTS-1:0] slot_wdog_cs_to_w_i, input logic [NUM_SLOTS-1:0] slot_wdog_cs_to_r_i, input logic [NUM_SLOTS-1:0] slot_wdog_cs_pr_w_i, input logic [NUM_SLOTS-1:0] slot_wdog_cs_pr_r_i,
    input  logic [NUM_SLOTS-1:0] slot_wdog_dm_to_w_i, input logic [NUM_SLOTS-1:0] slot_wdog_dm_to_r_i, input logic [NUM_SLOTS-1:0] slot_wdog_dm_pr_w_i, input logic [NUM_SLOTS-1:0] slot_wdog_dm_pr_r_i,
    input  logic [NUM_SLOTS-1:0] slot_wdog_cm_to_w_i, input logic [NUM_SLOTS-1:0] slot_wdog_cm_to_r_i, input logic [NUM_SLOTS-1:0] slot_wdog_cm_pr_w_i, input logic [NUM_SLOTS-1:0] slot_wdog_cm_pr_r_i,
    input  logic [NUM_SLOTS-1:0] slot_wdog_ds_to_w_i, input logic [NUM_SLOTS-1:0] slot_wdog_ds_to_r_i, input logic [NUM_SLOTS-1:0] slot_wdog_ds_pr_w_i, input logic [NUM_SLOTS-1:0] slot_wdog_ds_pr_r_i,
    
    // PMP Outputs (Parametric Array)
    output logic [NUM_SLOTS-1:0]                               pmp_g_en_o,
    output logic [NUM_SLOTS-1:0][NUM_PMP_REGIONS-1:0][31:0]    pmp_base_o,
    output logic [NUM_SLOTS-1:0][NUM_PMP_REGIONS-1:0][31:0]    pmp_limit_o,
    
    // Wishbone Bridge Enables
    output logic [NUM_SLOTS-1:0] wb_s_enable_o,
    output logic [NUM_SLOTS-1:0] wb_m_enable_o,

    // Fault Interrupt Line
    output logic [NUM_SLOTS-1:0] slot_fault_irq_o,

    // Host-Configured DMA Protection Levels
    output logic [NUM_SLOTS*3-1:0] slot_dma_awprot_o,
    output logic [NUM_SLOTS*3-1:0] slot_dma_arprot_o
);

    localparam bit PMP_ACTIVE = ENABLE_PMP & (NUM_PMP_REGIONS > 0);

    localparam int ADDR_SHIFT = PAGE_GRANULARITY ? 12 : 2;
    localparam int COMP_WIDTH = ADDR_WIDTH - ADDR_SHIFT;

    wire [15:0] local_awaddr = s_axil_awaddr[15:0];
    wire [15:0] local_araddr = s_axil_araddr[15:0];
    wire [3:0]  aw_slot_idx  = 4'((local_awaddr - 16'h1000) >> 12);
    wire [3:0]  ar_slot_idx  = 4'((local_araddr - 16'h1000) >> 12);

    localparam int SLOT_IDX_W = (NUM_SLOTS > 1) ? $clog2(NUM_SLOTS) : 1;
    wire [SLOT_IDX_W-1:0] aw_slot_sel = aw_slot_idx[SLOT_IDX_W-1:0];
    wire [SLOT_IDX_W-1:0] ar_slot_sel = ar_slot_idx[SLOT_IDX_W-1:0];

    // AXI Registers
    logic axi_awready, axi_wready, axi_bvalid, axi_arready, axi_rvalid;
    logic [31:0] axi_rdata;

    assign s_axil_awready = axi_awready; assign s_axil_wready = axi_wready; assign s_axil_bvalid = axi_bvalid; assign s_axil_bresp = 2'b00; 
    assign s_axil_arready = axi_arready; assign s_axil_rvalid = axi_rvalid; assign s_axil_rdata  = axi_rdata;  assign s_axil_rresp = 2'b00; 

    // Global Registers
    logic [31:0] config_count_reg;
    logic user_design_loaded_reg, com_active_q; 
    logic bitbang_active_q, bitbang_sticky_reg; 
    
    // Per-Slot Trimmed Registers
    logic [NUM_SLOTS-1:0][3:0]  slot_reset_fabric_reg;
    logic [NUM_SLOTS-1:0]       slot_reset_npu_reg;
    logic [NUM_SLOTS-1:0]       slot_reset_wdog_reg;
    logic [NUM_SLOTS-1:0]       slot_reset_bridge_ctrl_reg;
    logic [NUM_SLOTS-1:0]       slot_reset_bridge_dma_reg;
    logic [NUM_SLOTS-1:0]       dec_req_reg, dec_force_reg;
    logic [NUM_SLOTS-1:0][31:0] slot_debug_out_reg;
    logic [NUM_SLOTS-1:0][2:0]  dma_awprot_reg, dma_arprot_reg;

    assign slot_debug_out_o   = slot_debug_out_reg;
    assign decoupler_req_o    = dec_req_reg;
    assign slot_dma_awprot_o  = dma_awprot_reg;
    assign slot_dma_arprot_o  = dma_arprot_reg;

    // AXI Write Handshake
    wire axi_write_en = (s_axil_awvalid && s_axil_wvalid && !axi_awready && !axi_wready && !axi_bvalid);
    wire is_slot_write = axi_write_en && (local_awaddr >= 16'h1000) && (aw_slot_idx < 4'(NUM_SLOTS));
    wire [11:0] slot_aw_offset = local_awaddr[11:0] & 12'hFFC;

    // PMP Register Address Decoding
    wire [11:0] pmp_aw_offset     = (local_awaddr[11:0] & 12'hFFC) - 12'h018;
    wire [7:0]  pmp_aw_region_idx = pmp_aw_offset[10:3];

    wire [11:0] pmp_ar_offset     = (local_araddr[11:0] & 12'hFFC) - 12'h018;
    wire [7:0]  pmp_ar_region_idx = pmp_ar_offset[10:3];

    // =========================================================================
    // OPTIONAL SUBSYSTEM: Physical Memory Protection (PMP)
    // =========================================================================
    wire [NUM_SLOTS-1:0] pmp_g_en_wire;
    wire [NUM_SLOTS-1:0] pmp_r_flag_wire;
    wire [NUM_SLOTS-1:0] pmp_w_flag_wire;

    generate
        if (PMP_ACTIVE) begin : gen_pmp
            logic [NUM_SLOTS-1:0] pmp_g_en_reg;
            logic [NUM_SLOTS-1:0] pmp_r_flag_reg, pmp_w_flag_reg;
            logic [NUM_SLOTS-1:0][NUM_PMP_REGIONS-1:0][COMP_WIDTH-1:0] pmp_base_addr_reg;
            logic [NUM_SLOTS-1:0][NUM_PMP_REGIONS-1:0][1:0]            pmp_base_cfg_reg;
            logic [NUM_SLOTS-1:0][NUM_PMP_REGIONS-1:0][COMP_WIDTH-1:0] pmp_limit_addr_reg;
            logic [NUM_SLOTS-1:0][NUM_PMP_REGIONS-1:0][1:0]            pmp_limit_cfg_reg;

            assign pmp_g_en_wire   = pmp_g_en_reg;
            assign pmp_r_flag_wire = pmp_r_flag_reg;
            assign pmp_w_flag_wire = pmp_w_flag_reg;
            assign pmp_g_en_o      = pmp_g_en_reg;

            for (genvar s = 0; s < NUM_SLOTS; s++) begin : gen_pmp_out_slot
                for (genvar r = 0; r < NUM_PMP_REGIONS; r++) begin : gen_pmp_out_reg
                    if (PAGE_GRANULARITY) begin : gen_4k_out
                        if (ADDR_WIDTH < 32) begin : gen_pad
                            assign pmp_base_o[s][r]  = { {(32-ADDR_WIDTH){1'b0}}, pmp_base_addr_reg[s][r], 10'd0, pmp_base_cfg_reg[s][r] };
                            assign pmp_limit_o[s][r] = { {(32-ADDR_WIDTH){1'b0}}, pmp_limit_addr_reg[s][r], 10'd0, pmp_limit_cfg_reg[s][r] };
                        end else begin : gen_nopad
                            assign pmp_base_o[s][r]  = { pmp_base_addr_reg[s][r], 10'd0, pmp_base_cfg_reg[s][r] };
                            assign pmp_limit_o[s][r] = { pmp_limit_addr_reg[s][r], 10'd0, pmp_limit_cfg_reg[s][r] };
                        end
                    end else begin : gen_word_out
                        if (ADDR_WIDTH < 32) begin : gen_pad
                            assign pmp_base_o[s][r]  = { {(32-ADDR_WIDTH){1'b0}}, pmp_base_addr_reg[s][r], pmp_base_cfg_reg[s][r] };
                            assign pmp_limit_o[s][r] = { {(32-ADDR_WIDTH){1'b0}}, pmp_limit_addr_reg[s][r], pmp_limit_cfg_reg[s][r] };
                        end else begin : gen_nopad
                            assign pmp_base_o[s][r]  = { pmp_base_addr_reg[s][r], pmp_base_cfg_reg[s][r] };
                            assign pmp_limit_o[s][r] = { pmp_limit_addr_reg[s][r], pmp_limit_cfg_reg[s][r] };
                        end
                    end
                end
            end

            logic [31:0] pmp_w_curr_val;
            logic [31:0] pmp_w_next_val;

            always_comb begin
                pmp_w_curr_val = 32'b0;
                if ((aw_slot_idx < 4'(NUM_SLOTS)) && (pmp_aw_region_idx < 8'(NUM_PMP_REGIONS))) begin
                    pmp_w_curr_val = (pmp_aw_offset[2] == 1'b0) ? pmp_base_o[aw_slot_sel][pmp_aw_region_idx]
                                                                : pmp_limit_o[aw_slot_sel][pmp_aw_region_idx];
                end
                pmp_w_next_val[7:0]   = s_axil_wstrb[0] ? s_axil_wdata[7:0]   : pmp_w_curr_val[7:0];
                pmp_w_next_val[15:8]  = s_axil_wstrb[1] ? s_axil_wdata[15:8]  : pmp_w_curr_val[15:8];
                pmp_w_next_val[23:16] = s_axil_wstrb[2] ? s_axil_wdata[23:16] : pmp_w_curr_val[23:16];
                pmp_w_next_val[31:24] = s_axil_wstrb[3] ? s_axil_wdata[31:24] : pmp_w_curr_val[31:24];
            end

            always_ff @(posedge clk_i or negedge rstn_i) begin
                if (!rstn_i) begin
                    pmp_g_en_reg       <= '0;
                    pmp_r_flag_reg     <= '0;
                    pmp_w_flag_reg     <= '0;
                    pmp_base_addr_reg  <= '0;
                    pmp_base_cfg_reg   <= '0;
                    pmp_limit_addr_reg <= '0;
                    pmp_limit_cfg_reg  <= '0;
                end else begin
                    for (int j = 0; j < NUM_SLOTS; j++) begin
                        if (slot_pmp_r_violation_i[j]) begin
                            pmp_r_flag_reg[j] <= 1'b1;
                        end else if (is_slot_write && (aw_slot_sel == SLOT_IDX_W'(j)) && (slot_aw_offset == 12'h00C) && s_axil_wstrb[1] && s_axil_wdata[8]) begin
                            pmp_r_flag_reg[j] <= 1'b0;
                        end

                        if (slot_pmp_w_violation_i[j]) begin
                            pmp_w_flag_reg[j] <= 1'b1;
                        end else if (is_slot_write && (aw_slot_sel == SLOT_IDX_W'(j)) && (slot_aw_offset == 12'h00C) && s_axil_wstrb[1] && s_axil_wdata[9]) begin
                            pmp_w_flag_reg[j] <= 1'b0;
                        end
                    end

                    if (is_slot_write) begin
                        if (slot_aw_offset == 12'h004) begin
                            if (s_axil_wstrb[1]) pmp_g_en_reg[aw_slot_sel] <= s_axil_wdata[8];
                        end else if ((slot_aw_offset >= 12'h018) && decoupler_is_decoupled_i[aw_slot_sel]) begin
                            if (pmp_aw_region_idx < 8'(NUM_PMP_REGIONS)) begin
                                if (pmp_aw_offset[2] == 1'b0) begin
                                    pmp_base_addr_reg[aw_slot_sel][pmp_aw_region_idx] <= pmp_w_next_val[ADDR_WIDTH-1 : ADDR_SHIFT];
                                    pmp_base_cfg_reg[aw_slot_sel][pmp_aw_region_idx]  <= pmp_w_next_val[1:0];
                                end else begin
                                    pmp_limit_addr_reg[aw_slot_sel][pmp_aw_region_idx] <= pmp_w_next_val[ADDR_WIDTH-1 : ADDR_SHIFT];
                                    pmp_limit_cfg_reg[aw_slot_sel][pmp_aw_region_idx]  <= pmp_w_next_val[1:0];
                                end
                            end
                        end
                    end
                end
            end
        end else begin : gen_no_pmp
            assign pmp_g_en_wire   = '0;
            assign pmp_r_flag_wire = '0;
            assign pmp_w_flag_wire = '0;
            assign pmp_g_en_o      = '0;
            assign pmp_base_o      = '0;
            assign pmp_limit_o     = '0;
        end
    endgenerate

    // =========================================================================
    // OPTIONAL SUBSYSTEM: Watchdogs & Fault Flags
    // =========================================================================
    wire [NUM_SLOTS-1:0] wdog_en_dm_wire, wdog_en_cs_wire, wdog_en_ds_wire, wdog_en_cm_wire;
    wire [NUM_SLOTS-1:0] wdog_dm_pr_wire, wdog_dm_to_wire, wdog_cs_pr_wire, wdog_cs_to_wire, wdog_soc_wire;
    wire [NUM_SLOTS-1:0] raw_dm_pr, raw_dm_to, raw_cs_pr, raw_cs_to, raw_soc;

    generate
        if (ENABLE_WDOG_DMA_MASTER) begin : gen_wdog_dm
            logic [NUM_SLOTS-1:0] wdog_en_dm_reg;
            logic [NUM_SLOTS-1:0] wdog_dm_pr_reg, wdog_dm_to_reg;
            assign wdog_en_dm_wire = wdog_en_dm_reg;
            assign wdog_dm_pr_wire = wdog_dm_pr_reg;
            assign wdog_dm_to_wire = wdog_dm_to_reg;

            for (genvar j = 0; j < NUM_SLOTS; j++) begin : gen_raw_dm
                assign raw_dm_pr[j] = (slot_wdog_dm_pr_w_i[j] | slot_wdog_dm_pr_r_i[j]) & wdog_en_dm_reg[j];
                assign raw_dm_to[j] = (slot_wdog_dm_to_w_i[j] | slot_wdog_dm_to_r_i[j]) & wdog_en_dm_reg[j];
            end

            always_ff @(posedge clk_i or negedge rstn_i) begin
                if (!rstn_i) begin
                    wdog_en_dm_reg <= '1;
                    wdog_dm_pr_reg <= '0;
                    wdog_dm_to_reg <= '0;
                end else begin
                    for (int j = 0; j < NUM_SLOTS; j++) begin
                        if (raw_dm_pr[j]) begin
                            wdog_dm_pr_reg[j] <= 1'b1;
                        end else if (slot_reset_wdog_reg[j] || (is_slot_write && (aw_slot_sel == SLOT_IDX_W'(j)) && (slot_aw_offset == 12'h00C) && s_axil_wstrb[2] && s_axil_wdata[16])) begin
                            wdog_dm_pr_reg[j] <= 1'b0;
                        end

                        if (raw_dm_to[j]) begin
                            wdog_dm_to_reg[j] <= 1'b1;
                        end else if (slot_reset_wdog_reg[j] || (is_slot_write && (aw_slot_sel == SLOT_IDX_W'(j)) && (slot_aw_offset == 12'h00C) && s_axil_wstrb[2] && s_axil_wdata[17])) begin
                            wdog_dm_to_reg[j] <= 1'b0;
                        end
                    end

                    if (is_slot_write && (slot_aw_offset == 12'h004) && s_axil_wstrb[2]) begin
                        wdog_en_dm_reg[aw_slot_sel] <= s_axil_wdata[16];
                    end
                end
            end
        end else begin : gen_no_wdog_dm
            assign wdog_en_dm_wire = '0;
            assign wdog_dm_pr_wire = '0;
            assign wdog_dm_to_wire = '0;
            assign raw_dm_pr       = '0;
            assign raw_dm_to       = '0;
        end
    endgenerate

    generate
        if (ENABLE_WDOG_CTRL_SLAVE) begin : gen_wdog_cs
            logic [NUM_SLOTS-1:0] wdog_en_cs_reg;
            logic [NUM_SLOTS-1:0] wdog_cs_pr_reg, wdog_cs_to_reg;
            assign wdog_en_cs_wire = wdog_en_cs_reg;
            assign wdog_cs_pr_wire = wdog_cs_pr_reg;
            assign wdog_cs_to_wire = wdog_cs_to_reg;

            for (genvar j = 0; j < NUM_SLOTS; j++) begin : gen_raw_cs
                assign raw_cs_pr[j] = (slot_wdog_cs_pr_w_i[j] | slot_wdog_cs_pr_r_i[j]) & wdog_en_cs_reg[j];
                assign raw_cs_to[j] = (slot_wdog_cs_to_w_i[j] | slot_wdog_cs_to_r_i[j]) & wdog_en_cs_reg[j];
            end

            always_ff @(posedge clk_i or negedge rstn_i) begin
                if (!rstn_i) begin
                    wdog_en_cs_reg <= '1;
                    wdog_cs_pr_reg <= '0;
                    wdog_cs_to_reg <= '0;
                end else begin
                    for (int j = 0; j < NUM_SLOTS; j++) begin
                        if (raw_cs_pr[j]) begin
                            wdog_cs_pr_reg[j] <= 1'b1;
                        end else if (slot_reset_wdog_reg[j] || (is_slot_write && (aw_slot_sel == SLOT_IDX_W'(j)) && (slot_aw_offset == 12'h00C) && s_axil_wstrb[2] && s_axil_wdata[18])) begin
                            wdog_cs_pr_reg[j] <= 1'b0;
                        end

                        if (raw_cs_to[j]) begin
                            wdog_cs_to_reg[j] <= 1'b1;
                        end else if (slot_reset_wdog_reg[j] || (is_slot_write && (aw_slot_sel == SLOT_IDX_W'(j)) && (slot_aw_offset == 12'h00C) && s_axil_wstrb[2] && s_axil_wdata[19])) begin
                            wdog_cs_to_reg[j] <= 1'b0;
                        end
                    end

                    if (is_slot_write && (slot_aw_offset == 12'h004) && s_axil_wstrb[2]) begin
                        wdog_en_cs_reg[aw_slot_sel] <= s_axil_wdata[17];
                    end
                end
            end
        end else begin : gen_no_wdog_cs
            assign wdog_en_cs_wire = '0;
            assign wdog_cs_pr_wire = '0;
            assign wdog_cs_to_wire = '0;
            assign raw_cs_pr       = '0;
            assign raw_cs_to       = '0;
        end
    endgenerate

    generate
        if (ENABLE_WDOG_DMA_SLAVE) begin : gen_wdog_ds
            logic [NUM_SLOTS-1:0] wdog_en_ds_reg;
            assign wdog_en_ds_wire = wdog_en_ds_reg;

            always_ff @(posedge clk_i or negedge rstn_i) begin
                if (!rstn_i) begin
                    wdog_en_ds_reg <= '1;
                end else if (is_slot_write && (slot_aw_offset == 12'h004) && s_axil_wstrb[2]) begin
                    wdog_en_ds_reg[aw_slot_sel] <= s_axil_wdata[18];
                end
            end
        end else begin : gen_no_wdog_ds
            assign wdog_en_ds_wire = '0;
        end
    endgenerate

    generate
        if (ENABLE_WDOG_CTRL_MASTER) begin : gen_wdog_cm
            logic [NUM_SLOTS-1:0] wdog_en_cm_reg;
            assign wdog_en_cm_wire = wdog_en_cm_reg;

            always_ff @(posedge clk_i or negedge rstn_i) begin
                if (!rstn_i) begin
                    wdog_en_cm_reg <= '1;
                end else if (is_slot_write && (slot_aw_offset == 12'h004) && s_axil_wstrb[2]) begin
                    wdog_en_cm_reg[aw_slot_sel] <= s_axil_wdata[19];
                end
            end
        end else begin : gen_no_wdog_cm
            assign wdog_en_cm_wire = '0;
        end
    endgenerate

    generate
        if (ENABLE_WDOG_CTRL_MASTER || ENABLE_WDOG_DMA_SLAVE) begin : gen_wdog_soc
            logic [NUM_SLOTS-1:0] wdog_soc_reg;
            assign wdog_soc_wire = wdog_soc_reg;

            for (genvar j = 0; j < NUM_SLOTS; j++) begin : gen_raw_soc
                wire cm_fault = (slot_wdog_cm_to_w_i[j] | slot_wdog_cm_to_r_i[j] | slot_wdog_cm_pr_w_i[j] | slot_wdog_cm_pr_r_i[j]) & wdog_en_cm_wire[j];
                wire ds_fault = (slot_wdog_ds_to_w_i[j] | slot_wdog_ds_to_r_i[j] | slot_wdog_ds_pr_w_i[j] | slot_wdog_ds_pr_r_i[j]) & wdog_en_ds_wire[j];
                assign raw_soc[j] = cm_fault | ds_fault;
            end

            always_ff @(posedge clk_i or negedge rstn_i) begin
                if (!rstn_i) begin
                    wdog_soc_reg <= '0;
                end else begin
                    for (int j = 0; j < NUM_SLOTS; j++) begin
                        if (raw_soc[j]) begin
                            wdog_soc_reg[j] <= 1'b1;
                        end else if (slot_reset_wdog_reg[j] || (is_slot_write && (aw_slot_sel == SLOT_IDX_W'(j)) && (slot_aw_offset == 12'h00C) && s_axil_wstrb[2] && s_axil_wdata[20])) begin
                            wdog_soc_reg[j] <= 1'b0;
                        end
                    end
                end
            end
        end else begin : gen_no_wdog_soc
            assign wdog_soc_wire = '0;
            assign raw_soc       = '0;
        end
    endgenerate

    // =========================================================================
    // OPTIONAL SUBSYSTEM: Wishbone Bridges
    // =========================================================================
    wire [NUM_SLOTS-1:0] wb_s_enable_wire;
    wire [NUM_SLOTS-1:0] wb_m_enable_wire;

    generate
        if (ENABLE_BRIDGE_CTRL) begin : gen_bridge_ctrl_reg
            logic [NUM_SLOTS-1:0] wb_s_enable_reg;
            assign wb_s_enable_wire = wb_s_enable_reg;
            assign wb_s_enable_o    = wb_s_enable_reg;

            always_ff @(posedge clk_i or negedge rstn_i) begin
                if (!rstn_i) begin
                    wb_s_enable_reg <= '0;
                end else if (is_slot_write && (slot_aw_offset == 12'h004) && s_axil_wstrb[3]) begin
                    wb_s_enable_reg[aw_slot_sel] <= s_axil_wdata[24];
                end
            end
        end else begin : gen_no_bridge_ctrl_reg
            assign wb_s_enable_wire = '0;
            assign wb_s_enable_o    = '0;
        end
    endgenerate

    generate
        if (ENABLE_BRIDGE_DMA) begin : gen_bridge_dma_reg
            logic [NUM_SLOTS-1:0] wb_m_enable_reg;
            assign wb_m_enable_wire = wb_m_enable_reg;
            assign wb_m_enable_o    = wb_m_enable_reg;

            always_ff @(posedge clk_i or negedge rstn_i) begin
                if (!rstn_i) begin
                    wb_m_enable_reg <= '0;
                end else if (is_slot_write && (slot_aw_offset == 12'h004) && s_axil_wstrb[3]) begin
                    wb_m_enable_reg[aw_slot_sel] <= s_axil_wdata[25];
                end
            end
        end else begin : gen_no_bridge_dma_reg
            assign wb_m_enable_wire = '0;
            assign wb_m_enable_o    = '0;
        end
    endgenerate

    // =========================================================================
    // PER-SLOT OUTPUT AGGREGATION (Resets, Decoupler Force, Fault IRQ)
    // =========================================================================
    for (genvar i = 0; i < NUM_SLOTS; i++) begin : gen_slot_outputs
        assign slot_reset_o[i] = {
            6'd0,
            slot_reset_bridge_dma_reg[i],
            slot_reset_bridge_ctrl_reg[i],
            7'd0,
            slot_reset_wdog_reg[i],
            11'd0,
            slot_reset_npu_reg[i],
            slot_reset_fabric_reg[i]
        };

        assign decoupler_force_o[i] = dec_force_reg[i] | 
                                      raw_dm_pr[i] | raw_dm_to[i] | raw_cs_pr[i] | raw_cs_to[i] | raw_soc[i] |
                                      wdog_dm_pr_wire[i] | wdog_dm_to_wire[i] | wdog_cs_pr_wire[i] | wdog_cs_to_wire[i] | wdog_soc_wire[i] |
                                      slot_pmp_r_violation_i[i] | pmp_r_flag_wire[i] |
                                      slot_pmp_w_violation_i[i] | pmp_w_flag_wire[i];

        assign slot_fault_irq_o[i]   = pmp_r_flag_wire[i]  | pmp_w_flag_wire[i]  |
                                      wdog_dm_to_wire[i] | wdog_dm_pr_wire[i] |
                                      wdog_cs_to_wire[i] | wdog_cs_pr_wire[i] | wdog_soc_wire[i];
    end

    // =========================================================================
    // CORE REGISTER WRITE & CONFIG ENGINE
    // =========================================================================
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            axi_awready                <= 1'b0;
            axi_wready                 <= 1'b0;
            axi_bvalid                 <= 1'b0;
            config_count_reg           <= '0;
            efpga_config_data_o        <= '0;
            efpga_config_we_o          <= 1'b0;
            user_design_loaded_reg     <= 1'b0;
            com_active_q               <= 1'b0;
            bitbang_active_q           <= 1'b0;
            bitbang_sticky_reg         <= 1'b0;
            slot_reset_fabric_reg      <= '0;
            slot_reset_npu_reg         <= '0;
            slot_reset_wdog_reg        <= '0;
            slot_reset_bridge_ctrl_reg <= '0;
            slot_reset_bridge_dma_reg  <= '0;
            dec_req_reg                <= '1;
            dec_force_reg              <= '1;
            slot_debug_out_reg         <= '0;
            dma_awprot_reg             <= '0;
            dma_arprot_reg             <= '0;
        end else begin
            efpga_config_we_o <= 1'b0;
            com_active_q      <= efpga_com_active_i;
            bitbang_active_q  <= efpga_bitbang_active_i;

            if (efpga_bitbang_active_i && !bitbang_active_q) begin
                bitbang_sticky_reg <= 1'b1;
            end

            if (axi_write_en) begin
                axi_awready <= 1'b1;
                axi_wready  <= 1'b1;
                axi_bvalid  <= 1'b1;

                if (local_awaddr < 16'h1000) begin
                    case (local_awaddr[11:0] & 12'hFFC)
                        12'h004: begin
                            if (s_axil_wstrb[0]) begin
                                user_design_loaded_reg <= s_axil_wdata[2];
                                if (s_axil_wdata[4]) bitbang_sticky_reg <= 1'b0; // W1C
                            end
                        end
                        12'h008: begin
                            config_count_reg       <= config_count_reg + 32'd1;
                            efpga_config_data_o    <= {s_axil_wdata[7:0], s_axil_wdata[15:8], s_axil_wdata[23:16], s_axil_wdata[31:24]};
                            efpga_config_we_o      <= 1'b1;
                            user_design_loaded_reg <= 1'b1;
                        end
                        default: ;
                    endcase
                end else if (aw_slot_idx < 4'(NUM_SLOTS)) begin
                    case (slot_aw_offset)
                        12'h000: begin
                            if (s_axil_wstrb[0]) begin
                                slot_reset_fabric_reg[aw_slot_sel] <= s_axil_wdata[3:0];
                                slot_reset_npu_reg[aw_slot_sel]    <= s_axil_wdata[4];
                            end
                            if (s_axil_wstrb[2]) begin
                                slot_reset_wdog_reg[aw_slot_sel]   <= s_axil_wdata[16];
                            end
                            if (s_axil_wstrb[3]) begin
                                slot_reset_bridge_ctrl_reg[aw_slot_sel] <= s_axil_wdata[24];
                                slot_reset_bridge_dma_reg[aw_slot_sel]  <= s_axil_wdata[25];
                            end
                        end
                        12'h004: begin
                            if (s_axil_wstrb[0]) begin
                                dec_req_reg[aw_slot_sel]   <= s_axil_wdata[0];
                                dec_force_reg[aw_slot_sel] <= s_axil_wdata[1];
                            end
                            if (s_axil_wstrb[1]) begin
                                dma_awprot_reg[aw_slot_sel] <= s_axil_wdata[12:10];
                                dma_arprot_reg[aw_slot_sel] <= s_axil_wdata[15:13];
                            end
                        end
                        12'h010: begin
                            if (s_axil_wstrb[0]) slot_debug_out_reg[aw_slot_sel][7:0]   <= s_axil_wdata[7:0];
                            if (s_axil_wstrb[1]) slot_debug_out_reg[aw_slot_sel][15:8]  <= s_axil_wdata[15:8];
                            if (s_axil_wstrb[2]) slot_debug_out_reg[aw_slot_sel][23:16] <= s_axil_wdata[23:16];
                            if (s_axil_wstrb[3]) slot_debug_out_reg[aw_slot_sel][31:24] <= s_axil_wdata[31:24];
                        end
                        default: ;
                    endcase
                end
            end else begin
                axi_awready <= 1'b0;
                axi_wready  <= 1'b0;
            end

            if (s_axil_bready && axi_bvalid) axi_bvalid <= 1'b0;
        end
    end

    // =========================================================================
    // AXI READ STATE MACHINE
    // =========================================================================
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            axi_rdata   <= 32'h00000000;
        end else begin
            if (s_axil_arvalid && !axi_arready && !axi_rvalid) begin
                axi_arready <= 1'b1;
                axi_rvalid  <= 1'b1;

                if (local_araddr < 16'h1000) begin
                    case (local_araddr[11:0] & 12'hFFC)
                        12'h000: axi_rdata <= HW_VERSION;
                        12'h004: axi_rdata <= {27'd0, bitbang_sticky_reg, efpga_bitbang_active_i, user_design_loaded_reg, efpga_com_active_i, 1'b0};
                        12'h008: axi_rdata <= 32'h00000000;
                        12'h00C: axi_rdata <= config_count_reg;
                        default: axi_rdata <= 32'hBAD00000;
                    endcase
                end else if (ar_slot_idx < 4'(NUM_SLOTS)) begin
                    if ((local_araddr[11:0] & 12'hFFC) < 12'h018) begin
                        case (local_araddr[11:0] & 12'hFFC)
                            12'h000: axi_rdata <= slot_reset_o[ar_slot_sel];
                            12'h004: axi_rdata <= {
                                6'd0, wb_m_enable_wire[ar_slot_sel], wb_s_enable_wire[ar_slot_sel],
                                4'd0, wdog_en_cm_wire[ar_slot_sel], wdog_en_ds_wire[ar_slot_sel], wdog_en_cs_wire[ar_slot_sel], wdog_en_dm_wire[ar_slot_sel],
                                dma_arprot_reg[ar_slot_sel], dma_awprot_reg[ar_slot_sel], 1'b0, pmp_g_en_wire[ar_slot_sel],
                                6'd0, dec_force_reg[ar_slot_sel], dec_req_reg[ar_slot_sel]
                            };
                            12'h008: axi_rdata <= {
                                11'd0, wdog_soc_wire[ar_slot_sel], wdog_cs_to_wire[ar_slot_sel], wdog_cs_pr_wire[ar_slot_sel], wdog_dm_to_wire[ar_slot_sel], wdog_dm_pr_wire[ar_slot_sel],
                                6'd0, pmp_w_flag_wire[ar_slot_sel], pmp_r_flag_wire[ar_slot_sel],
                                5'd0, decoupler_dma_act_i[ar_slot_sel], decoupler_host_act_i[ar_slot_sel], decoupler_is_decoupled_i[ar_slot_sel]
                            };
                            12'h00C: axi_rdata <= 32'h00000000;
                            12'h010: axi_rdata <= slot_debug_out_reg[ar_slot_sel];
                            12'h014: axi_rdata <= slot_debug_in_i[ar_slot_sel];
                            default: axi_rdata <= 32'hBAD00001;
                        endcase
                    end else if (PMP_ACTIVE) begin
                        if (pmp_ar_region_idx < 8'(NUM_PMP_REGIONS)) begin
                            if (pmp_ar_offset[2] == 1'b0) axi_rdata <= pmp_base_o[ar_slot_sel][pmp_ar_region_idx];
                            else                          axi_rdata <= pmp_limit_o[ar_slot_sel][pmp_ar_region_idx];
                        end else begin
                            axi_rdata <= 32'hBAD00002;
                        end
                    end else begin
                        axi_rdata <= 32'h00000000;
                    end
                end else begin
                    axi_rdata <= 32'hBAD00003;
                end
            end else begin
                axi_arready <= 1'b0;
                if (s_axil_rready && axi_rvalid) axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
