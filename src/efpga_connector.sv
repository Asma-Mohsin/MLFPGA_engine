`timescale 1ns / 1ps

module efpga_connector #(
    parameter int NUM_SLOTS = 1,
    parameter int NUM_PMP_REGIONS = 2, // Parametric PMP regions
    parameter int AXI_ID_WIDTH = 8,
    parameter logic [31:0] HW_VERSION = 32'hFAB00001,
    parameter bit PAGE_GRANULARITY = 1'b1, // 1 = 4KB, 0 = Word
    parameter int ADDR_WIDTH = 32,
    
    // --- IP Generation Parameters ---
    parameter bit ENABLE_PMP              = 1'b1, // Synthesize Physical Memory Protection
    parameter bit ENABLE_WDOG_CTRL_SLAVE  = 1'b1, // Monitors Fabric AXI-Lite (Control)
    parameter bit ENABLE_WDOG_DMA_MASTER  = 1'b1, // Monitors Fabric AXI-Full (DMA)
    parameter bit ENABLE_WDOG_CTRL_MASTER = 1'b0, // Monitors SoC AXI-Lite
    parameter bit ENABLE_WDOG_DMA_SLAVE   = 1'b0, // Monitors SoC RAM
    parameter bit ENABLE_BRIDGE_CTRL      = 1'b0, // Synthesize SOC->Fabric Bridge
    parameter bit ENABLE_BRIDGE_DMA       = 1'b0, // Synthesize Fabric->SOC Bridge
    parameter bit ENABLE_REG_SLICES       = 1'b1  // Synthesize Skid Buffers on SoC Edge
)(
    input logic clk_i,
    input logic rstn_i,
    input logic rst_i,

    // Manager AXI-Lite Slave (From Crossbar M1)
    input  logic [31:0] mgr_s_awaddr, input  logic [2:0] mgr_s_awprot, input  logic mgr_s_awvalid, output logic mgr_s_awready,
    input  logic [31:0] mgr_s_wdata,  input  logic [3:0] mgr_s_wstrb,  input  logic mgr_s_wvalid,  output logic mgr_s_wready,
    output logic [1:0]  mgr_s_bresp,  output logic       mgr_s_bvalid, input  logic mgr_s_bready,
    input  logic [31:0] mgr_s_araddr, input  logic [2:0] mgr_s_arprot, input  logic mgr_s_arvalid, output logic mgr_s_arready,
    output logic [31:0] mgr_s_rdata,  output logic [1:0] mgr_s_rresp,  output logic mgr_s_rvalid,  input  logic mgr_s_rready,

    // --- Control Array (Connector -> Fabric Slave) ---
    input  logic [NUM_SLOTS*32-1:0] ctrl_s_awaddr, input  logic [NUM_SLOTS*3-1:0] ctrl_s_awprot, input  logic [NUM_SLOTS-1:0] ctrl_s_awvalid, output logic [NUM_SLOTS-1:0] ctrl_s_awready,
    input  logic [NUM_SLOTS*32-1:0] ctrl_s_wdata,  input  logic [NUM_SLOTS*4-1:0] ctrl_s_wstrb,  input  logic [NUM_SLOTS-1:0] ctrl_s_wvalid,  output logic [NUM_SLOTS-1:0] ctrl_s_wready,
    output logic [NUM_SLOTS*2-1:0]  ctrl_s_bresp,  output logic [NUM_SLOTS-1:0]   ctrl_s_bvalid, input  logic [NUM_SLOTS-1:0] ctrl_s_bready,
    input  logic [NUM_SLOTS*32-1:0] ctrl_s_araddr, input  logic [NUM_SLOTS*3-1:0] ctrl_s_arprot, input  logic [NUM_SLOTS-1:0] ctrl_s_arvalid, output logic [NUM_SLOTS-1:0] ctrl_s_arready,
    output logic [NUM_SLOTS*32-1:0] ctrl_s_rdata,  output logic [NUM_SLOTS*2-1:0] ctrl_s_rresp,  output logic [NUM_SLOTS-1:0] ctrl_s_rvalid,  input  logic [NUM_SLOTS-1:0] ctrl_s_rready,
    
    output logic [NUM_SLOTS*32-1:0] ctrl_m_awaddr, output logic [NUM_SLOTS*3-1:0] ctrl_m_awprot, output logic [NUM_SLOTS-1:0] ctrl_m_awvalid, input  logic [NUM_SLOTS-1:0] ctrl_m_awready,
    output logic [NUM_SLOTS*32-1:0] ctrl_m_wdata,  output logic [NUM_SLOTS*4-1:0] ctrl_m_wstrb,  output logic [NUM_SLOTS-1:0] ctrl_m_wvalid,  input  logic [NUM_SLOTS-1:0] ctrl_m_wready,
    input  logic [NUM_SLOTS*2-1:0]  ctrl_m_bresp,  input  logic [NUM_SLOTS-1:0]   ctrl_m_bvalid, output logic [NUM_SLOTS-1:0] ctrl_m_bready,
    output logic [NUM_SLOTS*32-1:0] ctrl_m_araddr, output logic [NUM_SLOTS*3-1:0] ctrl_m_arprot, output logic [NUM_SLOTS-1:0] ctrl_m_arvalid, input  logic [NUM_SLOTS-1:0] ctrl_m_arready,
    input  logic [NUM_SLOTS*32-1:0] ctrl_m_rdata,  input  logic [NUM_SLOTS*2-1:0]  ctrl_m_rresp,  input  logic [NUM_SLOTS-1:0] ctrl_m_rvalid,  output logic [NUM_SLOTS-1:0] ctrl_m_rready,
    
    // --- DMA Array (Fabric Master -> Connector) ---
    input  logic [NUM_SLOTS*AXI_ID_WIDTH-1:0] dma_s_awid,    input  logic [NUM_SLOTS*32-1:0] dma_s_awaddr,  input  logic [NUM_SLOTS*8-1:0] dma_s_awlen,      input  logic [NUM_SLOTS*3-1:0] dma_s_awsize,
    input  logic [NUM_SLOTS*2-1:0]            dma_s_awburst, input  logic [NUM_SLOTS-1:0]    dma_s_awlock,  input  logic [NUM_SLOTS*4-1:0] dma_s_awcache,    input  logic [NUM_SLOTS*3-1:0] dma_s_awprot,
    input  logic [NUM_SLOTS-1:0]              dma_s_awvalid, output logic [NUM_SLOTS-1:0]    dma_s_awready, input  logic [NUM_SLOTS*32-1:0] dma_s_wdata,     input  logic [NUM_SLOTS*4-1:0] dma_s_wstrb,
    input  logic [NUM_SLOTS-1:0]              dma_s_wlast,   input  logic [NUM_SLOTS-1:0]    dma_s_wvalid,  output logic [NUM_SLOTS-1:0]    dma_s_wready,    output logic [NUM_SLOTS*AXI_ID_WIDTH-1:0] dma_s_bid,
    output logic [NUM_SLOTS*2-1:0]            dma_s_bresp,   output logic [NUM_SLOTS-1:0]    dma_s_bvalid,  input  logic [NUM_SLOTS-1:0]    dma_s_bready,    input  logic [NUM_SLOTS*AXI_ID_WIDTH-1:0] dma_s_arid,
    input  logic [NUM_SLOTS*32-1:0]           dma_s_araddr,  input  logic [NUM_SLOTS*8-1:0]  dma_s_arlen,   input  logic [NUM_SLOTS*3-1:0]  dma_s_arsize,    input  logic [NUM_SLOTS*2-1:0] dma_s_arburst,
    input  logic [NUM_SLOTS-1:0]              dma_s_arlock,  input  logic [NUM_SLOTS*4-1:0]  dma_s_arcache, input  logic [NUM_SLOTS*3-1:0]  dma_s_arprot,    input  logic [NUM_SLOTS-1:0] dma_s_arvalid,
    output logic [NUM_SLOTS-1:0]              dma_s_arready, output logic [NUM_SLOTS*AXI_ID_WIDTH-1:0] dma_s_rid, output logic [NUM_SLOTS*32-1:0] dma_s_rdata,  output logic [NUM_SLOTS*2-1:0] dma_s_rresp,
    output logic [NUM_SLOTS-1:0]              dma_s_rlast,   output logic [NUM_SLOTS-1:0]    dma_s_rvalid,  input  logic [NUM_SLOTS-1:0]    dma_s_rready,
    
    output logic [NUM_SLOTS*AXI_ID_WIDTH-1:0] dma_m_awid,    output logic [NUM_SLOTS*32-1:0] dma_m_awaddr,  output logic [NUM_SLOTS*8-1:0]  dma_m_awlen,    output logic [NUM_SLOTS*3-1:0] dma_m_awsize,
    output logic [NUM_SLOTS*2-1:0]            dma_m_awburst, output logic [NUM_SLOTS-1:0]    dma_m_awlock,  output logic [NUM_SLOTS*4-1:0]  dma_m_awcache,  output logic [NUM_SLOTS*3-1:0] dma_m_awprot,
    output logic [NUM_SLOTS-1:0]              dma_m_awvalid, input  logic [NUM_SLOTS-1:0]    dma_m_awready, output logic [NUM_SLOTS*32-1:0] dma_m_wdata,    output logic [NUM_SLOTS*4-1:0] dma_m_wstrb,
    output logic [NUM_SLOTS-1:0]              dma_m_wlast,   output logic [NUM_SLOTS-1:0]    dma_m_wvalid,  input  logic [NUM_SLOTS-1:0]    dma_m_wready,   input  logic [NUM_SLOTS*AXI_ID_WIDTH-1:0] dma_m_bid,
    input  logic [NUM_SLOTS*2-1:0]            dma_m_bresp,   input  logic [NUM_SLOTS-1:0]    dma_m_bvalid,  output logic [NUM_SLOTS-1:0]    dma_m_bready,   output logic [NUM_SLOTS*AXI_ID_WIDTH-1:0] dma_m_arid,
    output logic [NUM_SLOTS*32-1:0]           dma_m_araddr,  output logic [NUM_SLOTS*8-1:0]  dma_m_arlen,   output logic [NUM_SLOTS*3-1:0]  dma_m_arsize,   output logic [NUM_SLOTS*2-1:0] dma_m_arburst,
    output logic [NUM_SLOTS-1:0]              dma_m_arlock,  output logic [NUM_SLOTS*4-1:0]  dma_m_arcache, output logic [NUM_SLOTS*3-1:0]  dma_m_arprot,   output logic [NUM_SLOTS-1:0] dma_m_arvalid,
    input  logic [NUM_SLOTS-1:0]              dma_m_arready, input  logic [NUM_SLOTS*AXI_ID_WIDTH-1:0] dma_m_rid, input  logic [NUM_SLOTS*32-1:0] dma_m_rdata,  input  logic [NUM_SLOTS*2-1:0] dma_m_rresp,
    input  logic [NUM_SLOTS-1:0]              dma_m_rlast,   input  logic [NUM_SLOTS-1:0]    dma_m_rvalid,  output logic [NUM_SLOTS-1:0]    dma_m_rready,

    // Direct eFPGA Control Wires
    output logic        efpga_config_we_o,
    output logic [31:0] efpga_config_data_o,
    output logic [NUM_SLOTS-1:0][3:0] slot_fabric_rst_n_o,
    output logic [NUM_SLOTS-1:0]      slot_npu_rst_n_o,
    input  logic        efpga_com_active_i,
    input  logic        efpga_bitbang_active_i,
    input  logic [NUM_SLOTS-1:0][31:0] slot_debug_in_i,
    output logic [NUM_SLOTS-1:0][31:0] slot_debug_out_o,

    // Fault Interrupt Output
    output logic [NUM_SLOTS-1:0] fault_irq_o,

    // Host-Configured DMA Protection Levels
    output logic [NUM_SLOTS*3-1:0] slot_dma_awprot_o,
    output logic [NUM_SLOTS*3-1:0] slot_dma_arprot_o
);

    // ===================================================================
    // Internal Global Wires & Fault Aggregation
    // ===================================================================
    logic [NUM_SLOTS-1:0] dec_req, dec_force;
    logic [NUM_SLOTS-1:0] dec_is_dec, dec_host_act, dec_dma_act;
    logic [NUM_SLOTS-1:0] pmp_r_violation, pmp_w_violation;
    logic [NUM_SLOTS-1:0] slot_wb_s_en, slot_wb_m_en; 
    logic [NUM_SLOTS-1:0] p_g_en;
    logic [NUM_SLOTS-1:0][NUM_PMP_REGIONS-1:0][31:0] p_base;
    logic [NUM_SLOTS-1:0][NUM_PMP_REGIONS-1:0][31:0] p_limit;

    localparam bit ANY_WDOG_ENABLED = ENABLE_WDOG_CTRL_SLAVE | ENABLE_WDOG_DMA_MASTER | ENABLE_WDOG_CTRL_MASTER | ENABLE_WDOG_DMA_SLAVE;

    logic [NUM_SLOTS-1:0][31:0] slot_reset_reg;

    // Fault Arrays for the 4 Watchdogs
    logic [NUM_SLOTS-1:0] wdog_cs_to_w, wdog_cs_to_r, wdog_cs_pr_w, wdog_cs_pr_r;
    logic [NUM_SLOTS-1:0] wdog_dm_to_w, wdog_dm_to_r, wdog_dm_pr_w, wdog_dm_pr_r;
    logic [NUM_SLOTS-1:0] wdog_cm_to_w, wdog_cm_to_r, wdog_cm_pr_w, wdog_cm_pr_r;
    logic [NUM_SLOTS-1:0] wdog_ds_to_w, wdog_ds_to_r, wdog_ds_pr_w, wdog_ds_pr_r;

    efpga_manager #(
        .NUM_SLOTS(NUM_SLOTS),
        .NUM_PMP_REGIONS(NUM_PMP_REGIONS),
        .HW_VERSION(HW_VERSION),
        .PAGE_GRANULARITY(PAGE_GRANULARITY), // 1 = 4KB, 0 = Word
        .ADDR_WIDTH(ADDR_WIDTH),
        .ENABLE_PMP(ENABLE_PMP),
        .ENABLE_WDOG_CTRL_SLAVE(ENABLE_WDOG_CTRL_SLAVE),
        .ENABLE_WDOG_DMA_MASTER(ENABLE_WDOG_DMA_MASTER),
        .ENABLE_WDOG_CTRL_MASTER(ENABLE_WDOG_CTRL_MASTER),
        .ENABLE_WDOG_DMA_SLAVE(ENABLE_WDOG_DMA_SLAVE),
        .ENABLE_BRIDGE_CTRL(ENABLE_BRIDGE_CTRL),
        .ENABLE_BRIDGE_DMA(ENABLE_BRIDGE_DMA)
    ) manager_inst (
        .clk_i(clk_i), .rstn_i(rstn_i),
        .s_axil_awaddr(mgr_s_awaddr), .s_axil_awprot(mgr_s_awprot), .s_axil_awvalid(mgr_s_awvalid), .s_axil_awready(mgr_s_awready),
        .s_axil_wdata(mgr_s_wdata),   .s_axil_wstrb(mgr_s_wstrb),   .s_axil_wvalid(mgr_s_wvalid),   .s_axil_wready(mgr_s_wready),
        .s_axil_bresp(mgr_s_bresp),   .s_axil_bvalid(mgr_s_bvalid), .s_axil_bready(mgr_s_bready),
        .s_axil_araddr(mgr_s_araddr), .s_axil_arprot(mgr_s_arprot), .s_axil_arvalid(mgr_s_arvalid), .s_axil_arready(mgr_s_arready),
        .s_axil_rdata(mgr_s_rdata),   .s_axil_rresp(mgr_s_rresp),   .s_axil_rvalid(mgr_s_rvalid),   .s_axil_rready(mgr_s_rready),
        
        .efpga_config_data_o(efpga_config_data_o), .efpga_config_we_o(efpga_config_we_o), 
        .efpga_com_active_i(efpga_com_active_i),
        .efpga_bitbang_active_i(efpga_bitbang_active_i),
        .slot_debug_in_i(slot_debug_in_i), .slot_debug_out_o(slot_debug_out_o), .slot_reset_o(slot_reset_reg),            
        
        .decoupler_req_o(dec_req), .decoupler_force_o(dec_force),
        .decoupler_is_decoupled_i(dec_is_dec), .decoupler_host_act_i(dec_host_act), .decoupler_dma_act_i(dec_dma_act),
        
        .slot_pmp_r_violation_i(pmp_r_violation), .slot_pmp_w_violation_i(pmp_w_violation),
        
        // 16 fault arrays wired in
        .slot_wdog_cs_to_w_i(wdog_cs_to_w), .slot_wdog_cs_to_r_i(wdog_cs_to_r), .slot_wdog_cs_pr_w_i(wdog_cs_pr_w), .slot_wdog_cs_pr_r_i(wdog_cs_pr_r),
        .slot_wdog_dm_to_w_i(wdog_dm_to_w), .slot_wdog_dm_to_r_i(wdog_dm_to_r), .slot_wdog_dm_pr_w_i(wdog_dm_pr_w), .slot_wdog_dm_pr_r_i(wdog_dm_pr_r),
        .slot_wdog_cm_to_w_i(wdog_cm_to_w), .slot_wdog_cm_to_r_i(wdog_cm_to_r), .slot_wdog_cm_pr_w_i(wdog_cm_pr_w), .slot_wdog_cm_pr_r_i(wdog_cm_pr_r),
        .slot_wdog_ds_to_w_i(wdog_ds_to_w), .slot_wdog_ds_to_r_i(wdog_ds_to_r), .slot_wdog_ds_pr_w_i(wdog_ds_pr_w), .slot_wdog_ds_pr_r_i(wdog_ds_pr_r),
        
        .pmp_g_en_o(p_g_en), .pmp_base_o(p_base), .pmp_limit_o(p_limit),
        .wb_s_enable_o(slot_wb_s_en), .wb_m_enable_o(slot_wb_m_en),
        .slot_fault_irq_o(fault_irq_o),
        .slot_dma_awprot_o(slot_dma_awprot_o),
        .slot_dma_arprot_o(slot_dma_arprot_o)
    );

    // ===================================================================
    // Per-Slot Generate Loop 
    // ===================================================================
    genvar i;
    generate
        for (i = 0; i < NUM_SLOTS; i++) begin : slot_gen

            // -----------------------------------------------------------
            // RESET GENERATION (Synchronous Soft Reset + Cold Reset)
            // -----------------------------------------------------------
            wire [3:0] slot_fabric_rst_n      = {4{rstn_i}} & ~slot_reset_reg[i][3:0];
            wire       slot_npu_rst_n         = rstn_i & ~slot_reset_reg[i][4];
            wire       slot_wdog_rst_n        = rstn_i & ~slot_reset_reg[i][16];
            wire       slot_bridge_ctrl_rst_n = rstn_i & ~slot_reset_reg[i][24];
            wire       slot_bridge_dma_rst_n  = rstn_i & ~slot_reset_reg[i][25];

            assign slot_fabric_rst_n_o[i] = slot_fabric_rst_n;
            assign slot_npu_rst_n_o[i]    = slot_npu_rst_n;

            // -----------------------------------------------------------
            // REG SLICE INTERMEDIATE WIRES (Fabric Side of Reg Slice)
            // -----------------------------------------------------------
            logic [31:0] slice_ctrl_awaddr; 
            logic [2:0]  slice_ctrl_awprot; 
            logic        slice_ctrl_awvalid, slice_ctrl_awready;
            
            logic [31:0] slice_ctrl_wdata;  
            logic [3:0]  slice_ctrl_wstrb;  
            logic        slice_ctrl_wvalid,  slice_ctrl_wready;
            
            logic [1:0]  slice_ctrl_bresp;  
            logic        slice_ctrl_bvalid, slice_ctrl_bready;
            
            logic [31:0] slice_ctrl_araddr; 
            logic [2:0]  slice_ctrl_arprot; 
            logic        slice_ctrl_arvalid, slice_ctrl_arready;
            
            logic [31:0] slice_ctrl_rdata;  
            logic [1:0]  slice_ctrl_rresp;  
            logic        slice_ctrl_rvalid,  slice_ctrl_rready;

            logic [AXI_ID_WIDTH-1:0] slice_dma_awid; logic [31:0] slice_dma_awaddr; logic [7:0] slice_dma_awlen; logic [2:0] slice_dma_awsize; logic [1:0] slice_dma_awburst; 
            logic slice_dma_awlock; logic [3:0] slice_dma_awcache; logic [2:0] slice_dma_awprot; logic slice_dma_awvalid, slice_dma_awready;
            logic [31:0] slice_dma_wdata;  logic [3:0] slice_dma_wstrb; logic slice_dma_wlast, slice_dma_wvalid, slice_dma_wready;
            logic [AXI_ID_WIDTH-1:0] slice_dma_bid; logic [1:0] slice_dma_bresp; logic slice_dma_bvalid, slice_dma_bready;
            logic [AXI_ID_WIDTH-1:0] slice_dma_arid; logic [31:0] slice_dma_araddr; logic [7:0] slice_dma_arlen; logic [2:0] slice_dma_arsize; logic [1:0] slice_dma_arburst; 
            logic slice_dma_arlock; logic [3:0] slice_dma_arcache; logic [2:0] slice_dma_arprot; logic slice_dma_arvalid, slice_dma_arready;
            logic [AXI_ID_WIDTH-1:0] slice_dma_rid; logic [31:0] slice_dma_rdata; logic [1:0] slice_dma_rresp; logic slice_dma_rvalid, slice_dma_rready, slice_dma_rlast;

            // -----------------------------------------------------------
            // STAGE 0: AXI / AXI-Lite Full Skid Buffers (SoC Edge)
            // -----------------------------------------------------------
            if (ENABLE_REG_SLICES) begin : gen_reg_slice
                // AXI-Lite Control (SoC Crossbar -> Connector Logic)
                axil_register #(
                    .DATA_WIDTH(32), .ADDR_WIDTH(32), .STRB_WIDTH(4),
                    .AW_REG_TYPE(2), .W_REG_TYPE(2), .B_REG_TYPE(2), .AR_REG_TYPE(2), .R_REG_TYPE(2)
                ) ctrl_slice (
                    .clk            (clk_i), 
                    .rst            (rst_i), // Forencich IP uses active-high reset
                    
                    // Slave (Connected directly to SoC Crossbar)
                    .s_axil_awaddr  (ctrl_s_awaddr[i*32 +: 32]), .s_axil_awprot  (ctrl_s_awprot[i*3 +: 3]), .s_axil_awvalid(ctrl_s_awvalid[i]), .s_axil_awready(ctrl_s_awready[i]),
                    .s_axil_wdata   (ctrl_s_wdata[i*32 +: 32]),  .s_axil_wstrb   (ctrl_s_wstrb[i*4 +: 4]),  .s_axil_wvalid (ctrl_s_wvalid[i]),  .s_axil_wready (ctrl_s_wready[i]),
                    .s_axil_bresp   (ctrl_s_bresp[i*2 +: 2]),    .s_axil_bvalid  (ctrl_s_bvalid[i]),        .s_axil_bready (ctrl_s_bready[i]),
                    .s_axil_araddr  (ctrl_s_araddr[i*32 +: 32]), .s_axil_arprot  (ctrl_s_arprot[i*3 +: 3]), .s_axil_arvalid(ctrl_s_arvalid[i]), .s_axil_arready(ctrl_s_arready[i]),
                    .s_axil_rdata   (ctrl_s_rdata[i*32 +: 32]),  .s_axil_rresp   (ctrl_s_rresp[i*2 +: 2]),  .s_axil_rvalid (ctrl_s_rvalid[i]),  .s_axil_rready (ctrl_s_rready[i]),

                    // Master (Connected to internal Decouplers/Watchdogs)
                    .m_axil_awaddr  (slice_ctrl_awaddr),  .m_axil_awprot  (slice_ctrl_awprot),  .m_axil_awvalid(slice_ctrl_awvalid), .m_axil_awready(slice_ctrl_awready),
                    .m_axil_wdata   (slice_ctrl_wdata),   .m_axil_wstrb   (slice_ctrl_wstrb),   .m_axil_wvalid (slice_ctrl_wvalid),  .m_axil_wready (slice_ctrl_wready),
                    .m_axil_bresp   (slice_ctrl_bresp),   .m_axil_bvalid  (slice_ctrl_bvalid),  .m_axil_bready (slice_ctrl_bready),
                    .m_axil_araddr  (slice_ctrl_araddr),  .m_axil_arprot  (slice_ctrl_arprot),  .m_axil_arvalid(slice_ctrl_arvalid), .m_axil_arready(slice_ctrl_arready),
                    .m_axil_rdata   (slice_ctrl_rdata),   .m_axil_rresp   (slice_ctrl_rresp),   .m_axil_rvalid (slice_ctrl_rvalid),  .m_axil_rready (slice_ctrl_rready)
                );

                // AXI-Full DMA (Connector Logic -> SoC Crossbar)
                axi_register #(
                    .DATA_WIDTH(32), .ADDR_WIDTH(32), .ID_WIDTH(AXI_ID_WIDTH),
                    .AWUSER_ENABLE(0), .WUSER_ENABLE(0), .BUSER_ENABLE(0), .ARUSER_ENABLE(0), .RUSER_ENABLE(0),
                    .AW_REG_TYPE(2), .W_REG_TYPE(2), .B_REG_TYPE(2), .AR_REG_TYPE(2), .R_REG_TYPE(2)
                ) dma_slice (
                    .clk            (clk_i), 
                    .rst            (rst_i),
                    
                    // Slave (Connected to internal Decouplers/Watchdogs)
                    .s_axi_awid     (slice_dma_awid),    .s_axi_awaddr  (slice_dma_awaddr),  .s_axi_awlen  (slice_dma_awlen),  .s_axi_awsize (slice_dma_awsize), .s_axi_awburst(slice_dma_awburst),
                    .s_axi_awlock   (slice_dma_awlock),  .s_axi_awcache (slice_dma_awcache), .s_axi_awprot (slice_dma_awprot), 
                    .s_axi_awqos    (4'd0),              .s_axi_awregion(4'd0),              .s_axi_awuser (1'b0),
                    .s_axi_awvalid  (slice_dma_awvalid), .s_axi_awready (slice_dma_awready),
                    
                    .s_axi_wdata    (slice_dma_wdata),   .s_axi_wstrb   (slice_dma_wstrb),   .s_axi_wlast  (slice_dma_wlast),
                    .s_axi_wuser    (1'b0),              .s_axi_wvalid  (slice_dma_wvalid),  .s_axi_wready (slice_dma_wready),
                    
                    .s_axi_bid      (slice_dma_bid),     .s_axi_bresp   (slice_dma_bresp),   .s_axi_buser  (),                 .s_axi_bvalid (slice_dma_bvalid), .s_axi_bready (slice_dma_bready),
                    
                    .s_axi_arid     (slice_dma_arid),    .s_axi_araddr  (slice_dma_araddr),  .s_axi_arlen  (slice_dma_arlen),  .s_axi_arsize (slice_dma_arsize), .s_axi_arburst(slice_dma_arburst),
                    .s_axi_arlock   (slice_dma_arlock),  .s_axi_arcache (slice_dma_arcache), .s_axi_arprot (slice_dma_arprot), 
                    .s_axi_arqos    (4'd0),              .s_axi_arregion(4'd0),              .s_axi_aruser (1'b0),
                    .s_axi_arvalid  (slice_dma_arvalid), .s_axi_arready (slice_dma_arready),
                    
                    .s_axi_rid      (slice_dma_rid),     .s_axi_rdata   (slice_dma_rdata),   .s_axi_rresp  (slice_dma_rresp),  .s_axi_rlast  (slice_dma_rlast),
                    .s_axi_ruser    (),                  .s_axi_rvalid  (slice_dma_rvalid),  .s_axi_rready (slice_dma_rready),

                    // Master (Connected directly to SoC Crossbar)
                    .m_axi_awid     (dma_m_awid[i*AXI_ID_WIDTH +: AXI_ID_WIDTH]), .m_axi_awaddr (dma_m_awaddr[i*32 +: 32]), .m_axi_awlen  (dma_m_awlen[i*8 +: 8]), .m_axi_awsize (dma_m_awsize[i*3 +: 3]), .m_axi_awburst(dma_m_awburst[i*2 +: 2]),
                    .m_axi_awlock   (dma_m_awlock[i]), .m_axi_awcache(dma_m_awcache[i*4 +: 4]), .m_axi_awprot (dma_m_awprot[i*3 +: 3]), 
                    .m_axi_awqos    (), .m_axi_awregion(), .m_axi_awuser (),
                    .m_axi_awvalid  (dma_m_awvalid[i]), .m_axi_awready(dma_m_awready[i]),
                    
                    .m_axi_wdata    (dma_m_wdata[i*32 +: 32]), .m_axi_wstrb  (dma_m_wstrb[i*4 +: 4]), .m_axi_wlast  (dma_m_wlast[i]), 
                    .m_axi_wuser    (), .m_axi_wvalid (dma_m_wvalid[i]), .m_axi_wready (dma_m_wready[i]),
                    
                    .m_axi_bid      (dma_m_bid[i*AXI_ID_WIDTH +: AXI_ID_WIDTH]), .m_axi_bresp  (dma_m_bresp[i*2 +: 2]), .m_axi_buser  (1'b0), .m_axi_bvalid (dma_m_bvalid[i]), .m_axi_bready (dma_m_bready[i]),
                    
                    .m_axi_arid     (dma_m_arid[i*AXI_ID_WIDTH +: AXI_ID_WIDTH]), .m_axi_araddr (dma_m_araddr[i*32 +: 32]), .m_axi_arlen  (dma_m_arlen[i*8 +: 8]), .m_axi_arsize (dma_m_arsize[i*3 +: 3]), .m_axi_arburst(dma_m_arburst[i*2 +: 2]),
                    .m_axi_arlock   (dma_m_arlock[i]), .m_axi_arcache(dma_m_arcache[i*4 +: 4]), .m_axi_arprot (dma_m_arprot[i*3 +: 3]), 
                    .m_axi_arqos    (), .m_axi_arregion(), .m_axi_aruser (),
                    .m_axi_arvalid  (dma_m_arvalid[i]), .m_axi_arready(dma_m_arready[i]),
                    
                    .m_axi_rid      (dma_m_rid[i*AXI_ID_WIDTH +: AXI_ID_WIDTH]), .m_axi_rdata  (dma_m_rdata[i*32 +: 32]), .m_axi_rresp  (dma_m_rresp[i*2 +: 2]), .m_axi_rlast  (dma_m_rlast[i]), 
                    .m_axi_ruser    (1'b0), .m_axi_rvalid (dma_m_rvalid[i]), .m_axi_rready (dma_m_rready[i])
                );
            end else begin : gen_no_reg_slice
                // Pure Bypass - Map Crossbar wires straight to Internal slice logic
                assign slice_ctrl_awaddr = ctrl_s_awaddr[i*32 +: 32]; assign slice_ctrl_awprot = ctrl_s_awprot[i*3 +: 3]; assign slice_ctrl_awvalid = ctrl_s_awvalid[i]; assign ctrl_s_awready[i] = slice_ctrl_awready;
                assign slice_ctrl_wdata  = ctrl_s_wdata[i*32 +: 32];  assign slice_ctrl_wstrb  = ctrl_s_wstrb[i*4 +: 4];  assign slice_ctrl_wvalid  = ctrl_s_wvalid[i];  assign ctrl_s_wready[i]  = slice_ctrl_wready;
                assign ctrl_s_bresp[i*2 +: 2] = slice_ctrl_bresp;     assign ctrl_s_bvalid[i]  = slice_ctrl_bvalid;       assign slice_ctrl_bready  = ctrl_s_bready[i];
                assign slice_ctrl_araddr = ctrl_s_araddr[i*32 +: 32]; assign slice_ctrl_arprot = ctrl_s_arprot[i*3 +: 3]; assign slice_ctrl_arvalid = ctrl_s_arvalid[i]; assign ctrl_s_arready[i] = slice_ctrl_arready;
                assign ctrl_s_rdata[i*32 +: 32] = slice_ctrl_rdata;   assign ctrl_s_rresp[i*2 +: 2] = slice_ctrl_rresp;   assign ctrl_s_rvalid[i]   = slice_ctrl_rvalid;   assign slice_ctrl_rready = ctrl_s_rready[i];

                assign dma_m_awid[i*AXI_ID_WIDTH +: AXI_ID_WIDTH] = slice_dma_awid; assign dma_m_awaddr[i*32 +: 32] = slice_dma_awaddr; assign dma_m_awlen[i*8 +: 8] = slice_dma_awlen; assign dma_m_awsize[i*3 +: 3] = slice_dma_awsize; assign dma_m_awburst[i*2 +: 2] = slice_dma_awburst; assign dma_m_awlock[i] = slice_dma_awlock; assign dma_m_awcache[i*4 +: 4] = slice_dma_awcache; assign dma_m_awprot[i*3 +: 3] = slice_dma_awprot; assign dma_m_awvalid[i] = slice_dma_awvalid; assign slice_dma_awready = dma_m_awready[i];
                assign dma_m_wdata[i*32 +: 32] = slice_dma_wdata; assign dma_m_wstrb[i*4 +: 4] = slice_dma_wstrb; assign dma_m_wlast[i] = slice_dma_wlast; assign dma_m_wvalid[i] = slice_dma_wvalid; assign slice_dma_wready = dma_m_wready[i];
                assign slice_dma_bid = dma_m_bid[i*AXI_ID_WIDTH +: AXI_ID_WIDTH]; assign slice_dma_bresp = dma_m_bresp[i*2 +: 2]; assign slice_dma_bvalid = dma_m_bvalid[i]; assign dma_m_bready[i] = slice_dma_bready;
                assign dma_m_arid[i*AXI_ID_WIDTH +: AXI_ID_WIDTH] = slice_dma_arid; assign dma_m_araddr[i*32 +: 32] = slice_dma_araddr; assign dma_m_arlen[i*8 +: 8] = slice_dma_arlen; assign dma_m_arsize[i*3 +: 3] = slice_dma_arsize; assign dma_m_arburst[i*2 +: 2] = slice_dma_arburst; assign dma_m_arlock[i] = slice_dma_arlock; assign dma_m_arcache[i*4 +: 4] = slice_dma_arcache; assign dma_m_arprot[i*3 +: 3] = slice_dma_arprot; assign dma_m_arvalid[i] = slice_dma_arvalid; assign slice_dma_arready = dma_m_arready[i];
                assign slice_dma_rid = dma_m_rid[i*AXI_ID_WIDTH +: AXI_ID_WIDTH]; assign slice_dma_rdata = dma_m_rdata[i*32 +: 32]; assign slice_dma_rresp = dma_m_rresp[i*2 +: 2]; assign slice_dma_rlast = dma_m_rlast[i]; assign slice_dma_rvalid = dma_m_rvalid[i]; assign dma_m_rready[i] = slice_dma_rready;
            end

            // -----------------------------------------------------------
            // INTERNAL WIRES: Decoupler <---> Bridges 
            // -----------------------------------------------------------
            logic [31:0] dec_ctrl_awaddr; 
            logic [2:0]  dec_ctrl_awprot; 
            logic        dec_ctrl_awvalid, dec_ctrl_awready;
            
            logic [31:0] dec_ctrl_wdata;  
            logic [3:0]  dec_ctrl_wstrb;  
            logic        dec_ctrl_wvalid,  dec_ctrl_wready;
            
            logic [1:0]  dec_ctrl_bresp;  
            logic        dec_ctrl_bvalid, dec_ctrl_bready;
            
            logic [31:0] dec_ctrl_araddr; 
            logic [2:0]  dec_ctrl_arprot; 
            logic        dec_ctrl_arvalid, dec_ctrl_arready;
            
            logic [31:0] dec_ctrl_rdata;  
            logic [1:0]  dec_ctrl_rresp;  
            logic        dec_ctrl_rvalid,  dec_ctrl_rready;

            logic [AXI_ID_WIDTH-1:0] dec_dma_awid; logic [31:0] dec_dma_awaddr; logic [7:0] dec_dma_awlen; logic [2:0] dec_dma_awsize; logic [1:0] dec_dma_awburst; 
            logic dec_dma_awlock; logic [3:0] dec_dma_awcache; logic [2:0] dec_dma_awprot; logic dec_dma_awvalid, dec_dma_awready;
            logic [31:0] dec_dma_wdata;  logic [3:0] dec_dma_wstrb; logic dec_dma_wlast, dec_dma_wvalid, dec_dma_wready;
            logic [AXI_ID_WIDTH-1:0] dec_dma_bid; logic [1:0] dec_dma_bresp; logic dec_dma_bvalid, dec_dma_bready;
            logic [AXI_ID_WIDTH-1:0] dec_dma_arid; logic [31:0] dec_dma_araddr; logic [7:0] dec_dma_arlen; logic [2:0] dec_dma_arsize; logic [1:0] dec_dma_arburst; 
            logic dec_dma_arlock; logic [3:0] dec_dma_arcache; logic [2:0] dec_dma_arprot; logic dec_dma_arvalid, dec_dma_arready;
            logic [AXI_ID_WIDTH-1:0] dec_dma_rid; logic [31:0] dec_dma_rdata; logic [1:0] dec_dma_rresp; logic dec_dma_rvalid, dec_dma_rready, dec_dma_rlast;

            // -----------------------------------------------------------
            // WATCHDOG 1: SoC AXI-Lite Master (Fabric Side of Slice)
            // -----------------------------------------------------------
            if (ENABLE_WDOG_CTRL_MASTER) begin : gen_wdog_cm
                wire cm_fault_to_w, cm_fault_to_r;
                wire cm_fault_drop_w, cm_fault_drop_r;
                wire cm_fault_unst_w, cm_fault_unst_r;

                axil_watchdog_master_monitor #(
                    .ENABLE_TIMEOUT          (1'b1),
                    .ENABLE_DROPPED_VALID    (1'b1),
                    .ENABLE_PAYLOAD_STABILITY(1'b0),
                    .WATCHDOG_LIMIT          (512)
                ) inst_wdog_cm (
                    .clk_i(clk_i), .rstn_i(slot_wdog_rst_n),
                    .awvalid(slice_ctrl_awvalid), .awready(slice_ctrl_awready), .awaddr(slice_ctrl_awaddr), .awprot(slice_ctrl_awprot),
                    .wvalid (slice_ctrl_wvalid),  .wready (slice_ctrl_wready),  .wdata(slice_ctrl_wdata),   .wstrb(slice_ctrl_wstrb),
                    .bvalid (slice_ctrl_bvalid),  .bready (slice_ctrl_bready),
                    .arvalid(slice_ctrl_arvalid), .arready(slice_ctrl_arready), .araddr(slice_ctrl_araddr), .arprot(slice_ctrl_arprot),
                    .rvalid (slice_ctrl_rvalid),  .rready (slice_ctrl_rready),
                    .fault_timeout_w_o      (cm_fault_to_w),
                    .fault_timeout_r_o      (cm_fault_to_r),
                    .fault_dropped_valid_w_o(cm_fault_drop_w),
                    .fault_dropped_valid_r_o(cm_fault_drop_r),
                    .fault_unstable_w_o     (cm_fault_unst_w),
                    .fault_unstable_r_o     (cm_fault_unst_r)
                );
                assign wdog_cm_to_w[i] = cm_fault_to_w;
                assign wdog_cm_to_r[i] = cm_fault_to_r;
                assign wdog_cm_pr_w[i] = cm_fault_drop_w | cm_fault_unst_w;
                assign wdog_cm_pr_r[i] = cm_fault_drop_r | cm_fault_unst_r;
            end else begin : gen_no_wdog_cm
                assign wdog_cm_to_w[i] = 1'b0; assign wdog_cm_to_r[i] = 1'b0; assign wdog_cm_pr_w[i] = 1'b0; assign wdog_cm_pr_r[i] = 1'b0;
            end

            // -----------------------------------------------------------
            // STAGE 1: AXI Decoupler (Internal Logic <-> Bridges)
            // -----------------------------------------------------------
            axi_decoupler #(
                .AXI_ID_WIDTH (AXI_ID_WIDTH)
            ) decoupler_inst (
                .clk_i             (clk_i),
                .rstn_i            (rstn_i),
                .decouple_req_i    (dec_req[i]),
                .force_decouple_i  (dec_force[i]),
                .is_decoupled_o    (dec_is_dec[i]),
                .host_active_o     (dec_host_act[i]),
                .dma_active_o      (dec_dma_act[i]),
                
                // SoC Side (Connected to Fabric Side of Register Slices)
                .ctrl_s_axil_awaddr(slice_ctrl_awaddr), .ctrl_s_axil_awprot(slice_ctrl_awprot), .ctrl_s_axil_awvalid(slice_ctrl_awvalid), .ctrl_s_axil_awready(slice_ctrl_awready),
                .ctrl_s_axil_wdata (slice_ctrl_wdata),  .ctrl_s_axil_wstrb (slice_ctrl_wstrb),  .ctrl_s_axil_wvalid (slice_ctrl_wvalid),  .ctrl_s_axil_wready (slice_ctrl_wready),
                .ctrl_s_axil_bresp (slice_ctrl_bresp),  .ctrl_s_axil_bvalid(slice_ctrl_bvalid), .ctrl_s_axil_bready (slice_ctrl_bready),
                .ctrl_s_axil_araddr(slice_ctrl_araddr), .ctrl_s_axil_arprot(slice_ctrl_arprot), .ctrl_s_axil_arvalid(slice_ctrl_arvalid), .ctrl_s_axil_arready(slice_ctrl_arready),
                .ctrl_s_axil_rdata (slice_ctrl_rdata),  .ctrl_s_axil_rresp (slice_ctrl_rresp),  .ctrl_s_axil_rvalid (slice_ctrl_rvalid),  .ctrl_s_axil_rready (slice_ctrl_rready),
                
                // Fabric Side Control (Drives internal `dec_ctrl_` wires to Bridge 1)
                .ctrl_m_axil_awaddr(dec_ctrl_awaddr),  .ctrl_m_axil_awprot(dec_ctrl_awprot),  .ctrl_m_axil_awvalid(dec_ctrl_awvalid), .ctrl_m_axil_awready(dec_ctrl_awready),
                .ctrl_m_axil_wdata (dec_ctrl_wdata),   .ctrl_m_axil_wstrb (dec_ctrl_wstrb),   .ctrl_m_axil_wvalid (dec_ctrl_wvalid),  .ctrl_m_axil_wready (dec_ctrl_wready),
                .ctrl_m_axil_bresp (dec_ctrl_bresp),   .ctrl_m_axil_bvalid(dec_ctrl_bvalid),  .ctrl_m_axil_bready (dec_ctrl_bready),
                .ctrl_m_axil_araddr(dec_ctrl_araddr),  .ctrl_m_axil_arprot(dec_ctrl_arprot),  .ctrl_m_axil_arvalid(dec_ctrl_arvalid), .ctrl_m_axil_arready(dec_ctrl_arready),
                .ctrl_m_axil_rdata (dec_ctrl_rdata),   .ctrl_m_axil_rresp (dec_ctrl_rresp),   .ctrl_m_axil_rvalid (dec_ctrl_rvalid),  .ctrl_m_axil_rready (dec_ctrl_rready),
                
                // Fabric Side DMA (Driven by internal `dec_dma_` wires from Bridge 2)
                .dma_s_axi_awid    (dec_dma_awid),     .dma_s_axi_awaddr  (dec_dma_awaddr),  .dma_s_axi_awlen   (dec_dma_awlen),   .dma_s_axi_awsize (dec_dma_awsize), .dma_s_axi_awburst(dec_dma_awburst), 
                .dma_s_axi_awlock  (dec_dma_awlock),   .dma_s_axi_awcache (dec_dma_awcache), .dma_s_axi_awprot  (dec_dma_awprot),  .dma_s_axi_awvalid(dec_dma_awvalid),.dma_s_axi_awready(dec_dma_awready), 
                .dma_s_axi_wdata   (dec_dma_wdata),    .dma_s_axi_wstrb   (dec_dma_wstrb),   .dma_s_axi_wlast   (dec_dma_wlast),   .dma_s_axi_wvalid (dec_dma_wvalid), .dma_s_axi_wready (dec_dma_wready), 
                .dma_s_axi_bid     (dec_dma_bid),      .dma_s_axi_bresp   (dec_dma_bresp),   .dma_s_axi_bvalid  (dec_dma_bvalid),  .dma_s_axi_bready (dec_dma_bready), 
                .dma_s_axi_arid    (dec_dma_arid),     .dma_s_axi_araddr  (dec_dma_araddr),  .dma_s_axi_arlen   (dec_dma_arlen),   .dma_s_axi_arsize (dec_dma_arsize), .dma_s_axi_arburst(dec_dma_arburst),
                .dma_s_axi_arlock  (dec_dma_arlock),   .dma_s_axi_arcache (dec_dma_arcache), .dma_s_axi_arprot  (dec_dma_arprot),  .dma_s_axi_arvalid(dec_dma_arvalid),.dma_s_axi_arready(dec_dma_arready), 
                .dma_s_axi_rid     (dec_dma_rid),      .dma_s_axi_rdata   (dec_dma_rdata),   .dma_s_axi_rresp   (dec_dma_rresp),   .dma_s_axi_rlast  (dec_dma_rlast),  .dma_s_axi_rvalid (dec_dma_rvalid),  .dma_s_axi_rready (dec_dma_rready),
                
                // SoC Side DMA (Connected to Fabric Side of Register Slices)
                .dma_m_axi_awid    (slice_dma_awid),   .dma_m_axi_awaddr  (slice_dma_awaddr), .dma_m_axi_awlen   (slice_dma_awlen), .dma_m_axi_awsize (slice_dma_awsize), .dma_m_axi_awburst(slice_dma_awburst),
                .dma_m_axi_awlock  (slice_dma_awlock), .dma_m_axi_awcache (slice_dma_awcache),.dma_m_axi_awprot  (slice_dma_awprot),.dma_m_axi_awvalid (slice_dma_awvalid),.dma_m_axi_awready(slice_dma_awready),
                .dma_m_axi_wdata   (slice_dma_wdata),  .dma_m_axi_wstrb   (slice_dma_wstrb),  .dma_m_axi_wlast   (slice_dma_wlast), .dma_m_axi_wvalid  (slice_dma_wvalid), .dma_m_axi_wready (slice_dma_wready),
                .dma_m_axi_bid     (slice_dma_bid),    .dma_m_axi_bresp   (slice_dma_bresp),  .dma_m_axi_bvalid  (slice_dma_bvalid),.dma_m_axi_bready  (slice_dma_bready),
                .dma_m_axi_arid    (slice_dma_arid),   .dma_m_axi_araddr  (slice_dma_araddr), .dma_m_axi_arlen   (slice_dma_arlen), .dma_m_axi_arsize  (slice_dma_arsize), .dma_m_axi_arburst(slice_dma_arburst),
                .dma_m_axi_arlock  (slice_dma_arlock), .dma_m_axi_arcache (slice_dma_arcache),.dma_m_axi_arprot  (slice_dma_arprot),.dma_m_axi_arvalid  (slice_dma_arvalid),.dma_m_axi_arready(slice_dma_arready),
                .dma_m_axi_rid     (slice_dma_rid),    .dma_m_axi_rdata   (slice_dma_rdata),  .dma_m_axi_rresp   (slice_dma_rresp), .dma_m_axi_rlast   (slice_dma_rlast),  .dma_m_axi_rvalid  (slice_dma_rvalid), .dma_m_axi_rready (slice_dma_rready)
            );

            // -----------------------------------------------------------
            // WATCHDOG 2: Fabric AXI-Lite Slave (Fabric Side)
            // -----------------------------------------------------------
            if (ENABLE_WDOG_CTRL_SLAVE) begin : gen_wdog_cs
                wire cs_fault_to_w, cs_fault_to_r;
                wire cs_fault_drop_w, cs_fault_drop_r;
                wire cs_fault_unst_w, cs_fault_unst_r;

                axil_watchdog_slave_monitor #(
                    .ENABLE_TIMEOUT          (1'b1),
                    .ENABLE_DROPPED_VALID    (1'b1),
                    .ENABLE_PAYLOAD_STABILITY(1'b0),
                    .WATCHDOG_LIMIT          (512)
                ) inst_wdog_cs (
                    .clk_i(clk_i), .rstn_i(slot_wdog_rst_n),
                    .awvalid(dec_ctrl_awvalid), .awready(dec_ctrl_awready),
                    .wvalid (dec_ctrl_wvalid),  .wready (dec_ctrl_wready),
                    .bvalid (dec_ctrl_bvalid),  .bready (dec_ctrl_bready), .bresp(dec_ctrl_bresp),
                    .arvalid(dec_ctrl_arvalid), .arready(dec_ctrl_arready),
                    .rvalid (dec_ctrl_rvalid),  .rready (dec_ctrl_rready), .rdata(dec_ctrl_rdata), .rresp(dec_ctrl_rresp),
                    .fault_timeout_w_o      (cs_fault_to_w),
                    .fault_timeout_r_o      (cs_fault_to_r),
                    .fault_dropped_valid_w_o(cs_fault_drop_w),
                    .fault_dropped_valid_r_o(cs_fault_drop_r),
                    .fault_unstable_w_o     (cs_fault_unst_w),
                    .fault_unstable_r_o     (cs_fault_unst_r)
                );
                assign wdog_cs_to_w[i] = cs_fault_to_w;
                assign wdog_cs_to_r[i] = cs_fault_to_r;
                assign wdog_cs_pr_w[i] = cs_fault_drop_w | cs_fault_unst_w;
                assign wdog_cs_pr_r[i] = cs_fault_drop_r | cs_fault_unst_r;
            end else begin : gen_no_wdog_cs
                assign wdog_cs_to_w[i] = 1'b0; assign wdog_cs_to_r[i] = 1'b0; assign wdog_cs_pr_w[i] = 1'b0; assign wdog_cs_pr_r[i] = 1'b0;
            end

            // -----------------------------------------------------------
            // STAGE 2: Security Modules (PMP taps the Decoupled DMA lines)
            // -----------------------------------------------------------
            if (ENABLE_PMP) begin : gen_pmp
                pmp_math #(
                    .NUM_PMP_REGIONS(NUM_PMP_REGIONS),
                    .PAGE_GRANULARITY(PAGE_GRANULARITY), // 1 = 4KB, 0 = Word
                    .ADDR_WIDTH(ADDR_WIDTH)
                ) pmp_inst (
                    .g_en_i         (p_g_en[i]),
                    .base_i         (p_base[i]),
                    .limit_i        (p_limit[i]),
                    
                    .awaddr_i       (dec_dma_awaddr),  .awlen_i (dec_dma_awlen),  .awsize_i (dec_dma_awsize),  .awprot_i (dec_dma_awprot),  .awvalid_i (dec_dma_awvalid),
                    .araddr_i       (dec_dma_araddr),  .arlen_i (dec_dma_arlen),  .arsize_i (dec_dma_arsize),  .arprot_i (dec_dma_arprot),  .arvalid_i (dec_dma_arvalid),
                    
                    .violation_r_o  (pmp_r_violation[i]),
                    .violation_w_o  (pmp_w_violation[i])
                );
            end else begin : gen_no_pmp
                assign pmp_r_violation[i] = 0;
                assign pmp_w_violation[i] = 0;
            end

            // -----------------------------------------------------------
            // WATCHDOG 3: Fabric AXI-Full Master (Fabric Side)
            // -----------------------------------------------------------
            if (ENABLE_WDOG_DMA_MASTER) begin : gen_wdog_dm
                wire dm_fault_to_w, dm_fault_to_r;
                wire dm_fault_drop_w, dm_fault_drop_r;
                wire dm_fault_unst_w, dm_fault_unst_r;
                wire dm_fault_4k_w, dm_fault_4k_r;
                wire dm_fault_size_w, dm_fault_size_r;
                wire dm_fault_burst_w, dm_fault_burst_r;
                wire dm_fault_wlast;

                axi_watchdog_master_monitor #(
                    .ENABLE_TIMEOUT          (1'b1),
                    .ENABLE_DROPPED_VALID    (1'b1),
                    .ENABLE_PAYLOAD_STABILITY(1'b0),
                    .ENABLE_4K_CHECK         (1'b1),
                    .ENABLE_SIZE_CHECK       (1'b1),
                    .ENABLE_BURST_CHECK      (1'b1),
                    .ENABLE_WLAST_CHECK      (1'b1),
                    .MAX_OUTSTANDING_WRITES  (1),
                    .WATCHDOG_LIMIT          (512),
                    .AXI_ID_WIDTH            (AXI_ID_WIDTH)
                ) inst_wdog_dm (
                    .clk_i(clk_i), .rstn_i(slot_wdog_rst_n),
                    .awvalid(dec_dma_awvalid), .awready(dec_dma_awready), .awid(dec_dma_awid), .awaddr(dec_dma_awaddr), .awlen(dec_dma_awlen), .awsize(dec_dma_awsize), .awburst(dec_dma_awburst), .awlock(dec_dma_awlock), .awcache(dec_dma_awcache), .awprot(dec_dma_awprot),
                    .wvalid (dec_dma_wvalid),  .wready (dec_dma_wready),  .wlast(dec_dma_wlast), .wdata(dec_dma_wdata), .wstrb(dec_dma_wstrb),
                    .bvalid (dec_dma_bvalid),  .bready (dec_dma_bready),
                    .arvalid(dec_dma_arvalid), .arready(dec_dma_arready), .arid(dec_dma_arid), .araddr(dec_dma_araddr), .arlen(dec_dma_arlen), .arsize(dec_dma_arsize), .arburst(dec_dma_arburst), .arlock(dec_dma_arlock), .arcache(dec_dma_arcache), .arprot(dec_dma_arprot),
                    .rvalid (dec_dma_rvalid),  .rready (dec_dma_rready),  .rlast(dec_dma_rlast),
                    .fault_timeout_w_o       (dm_fault_to_w),
                    .fault_timeout_r_o       (dm_fault_to_r),
                    .fault_dropped_valid_w_o (dm_fault_drop_w),
                    .fault_dropped_valid_r_o (dm_fault_drop_r),
                    .fault_unstable_w_o      (dm_fault_unst_w),
                    .fault_unstable_r_o      (dm_fault_unst_r),
                    .fault_4k_cross_w_o      (dm_fault_4k_w),
                    .fault_4k_cross_r_o      (dm_fault_4k_r),
                    .fault_illegal_size_w_o  (dm_fault_size_w),
                    .fault_illegal_size_r_o  (dm_fault_size_r),
                    .fault_illegal_burst_w_o (dm_fault_burst_w),
                    .fault_illegal_burst_r_o (dm_fault_burst_r),
                    .fault_wlast_timing_o    (dm_fault_wlast)
                );
                assign wdog_dm_to_w[i] = dm_fault_to_w;
                assign wdog_dm_to_r[i] = dm_fault_to_r;
                assign wdog_dm_pr_w[i] = dm_fault_drop_w | dm_fault_unst_w | dm_fault_4k_w | 
                                         dm_fault_size_w | dm_fault_burst_w | dm_fault_wlast;
                assign wdog_dm_pr_r[i] = dm_fault_drop_r | dm_fault_unst_r | dm_fault_4k_r | 
                                         dm_fault_size_r | dm_fault_burst_r;
            end else begin : gen_no_wdog_dm
                assign wdog_dm_to_w[i] = 1'b0; assign wdog_dm_to_r[i] = 1'b0; assign wdog_dm_pr_w[i] = 1'b0; assign wdog_dm_pr_r[i] = 1'b0;
            end

            // -----------------------------------------------------------
            // STAGE 3: Protocol Bridges (Bypassable)
            // -----------------------------------------------------------
            if (ENABLE_BRIDGE_CTRL) begin : gen_bridge_ctrl
                bridge_soc_to_fabric_slave bridge_ctrl_inst (
                    .clk           (clk_i),
                    .resetn        (slot_bridge_ctrl_rst_n),
                    .cfg_wb_enable (slot_wb_s_en[i]), 
                    
                    // SoC Side (Driven by internal `dec_ctrl_` wires from Decoupler)
                    .soc_awaddr  (dec_ctrl_awaddr),  .soc_awprot  (dec_ctrl_awprot),  .soc_awvalid (dec_ctrl_awvalid), .soc_awready (dec_ctrl_awready),
                    .soc_wdata   (dec_ctrl_wdata),   .soc_wstrb   (dec_ctrl_wstrb),   .soc_wvalid  (dec_ctrl_wvalid),  .soc_wready  (dec_ctrl_wready),
                    .soc_bresp   (dec_ctrl_bresp),   .soc_bvalid  (dec_ctrl_bvalid),  .soc_bready  (dec_ctrl_bready),
                    .soc_araddr  (dec_ctrl_araddr),  .soc_arprot  (dec_ctrl_arprot),  .soc_arvalid (dec_ctrl_arvalid), .soc_arready (dec_ctrl_arready),
                    .soc_rdata   (dec_ctrl_rdata),   .soc_rresp   (dec_ctrl_rresp),   .soc_rvalid  (dec_ctrl_rvalid),  .soc_rready  (dec_ctrl_rready),
                    
                    // Fabric Side (Drives physical eFPGA pins)
                    .fab_awaddr  (ctrl_m_awaddr[i*32 +: 32]), .fab_awprot  (ctrl_m_awprot[i*3 +: 3]), .fab_awvalid (ctrl_m_awvalid[i]), .fab_awready (ctrl_m_awready[i]),
                    .fab_wdata   (ctrl_m_wdata[i*32 +: 32]),  .fab_wstrb   (ctrl_m_wstrb[i*4 +: 4]),  .fab_wvalid  (ctrl_m_wvalid[i]),  .fab_wready  (ctrl_m_wready[i]),
                    .fab_bresp   (ctrl_m_bresp[i*2 +: 2]),    .fab_bvalid  (ctrl_m_bvalid[i]),        .fab_bready  (ctrl_m_bready[i]),
                    .fab_araddr  (ctrl_m_araddr[i*32 +: 32]), .fab_arprot  (ctrl_m_arprot[i*3 +: 3]), .fab_arvalid (ctrl_m_arvalid[i]), .fab_arready (ctrl_m_arready[i]),
                    .fab_rdata   (ctrl_m_rdata[i*32 +: 32]),  .fab_rresp   (ctrl_m_rresp[i*2 +: 2]),  .fab_rvalid  (ctrl_m_rvalid[i]),  .fab_rready  (ctrl_m_rready[i])
                );
            end else begin : gen_bypass_bridge_ctrl
                assign ctrl_m_awaddr[i*32 +: 32] = dec_ctrl_awaddr; assign ctrl_m_awprot[i*3 +: 3] = dec_ctrl_awprot; assign ctrl_m_awvalid[i] = dec_ctrl_awvalid; assign dec_ctrl_awready = ctrl_m_awready[i];
                assign ctrl_m_wdata[i*32 +: 32]  = dec_ctrl_wdata;  assign ctrl_m_wstrb[i*4 +: 4]  = dec_ctrl_wstrb;  assign ctrl_m_wvalid[i]  = dec_ctrl_wvalid;  assign dec_ctrl_wready  = ctrl_m_wready[i];
                assign dec_ctrl_bresp            = ctrl_m_bresp[i*2 +: 2]; assign dec_ctrl_bvalid  = ctrl_m_bvalid[i]; assign ctrl_m_bready[i] = dec_ctrl_bready;
                assign ctrl_m_araddr[i*32 +: 32] = dec_ctrl_araddr; assign ctrl_m_arprot[i*3 +: 3] = dec_ctrl_arprot; assign ctrl_m_arvalid[i] = dec_ctrl_arvalid; assign dec_ctrl_arready = ctrl_m_arready[i];
                assign dec_ctrl_rdata            = ctrl_m_rdata[i*32 +: 32]; assign dec_ctrl_rresp = ctrl_m_rresp[i*2 +: 2]; assign dec_ctrl_rvalid = ctrl_m_rvalid[i]; assign ctrl_m_rready[i] = dec_ctrl_rready;
            end

            if (ENABLE_BRIDGE_DMA) begin : gen_bridge_dma
                bridge_fabric_master_to_soc #(
                    .AXI_ID_WIDTH (AXI_ID_WIDTH)
                ) bridge_dma_inst (
                    .clk           (clk_i),
                    .resetn        (slot_bridge_dma_rst_n),
                    .cfg_wb_enable (slot_wb_m_en[i]), 
                    
                    // Fabric Side (Driven by physical eFPGA pins, with PROT sandboxed by Manager)
                    .fab_awid    (dma_s_awid[i*AXI_ID_WIDTH +: AXI_ID_WIDTH]), .fab_awaddr (dma_s_awaddr[i*32 +: 32]), .fab_awlen  (dma_s_awlen[i*8 +: 8]), .fab_awsize (dma_s_awsize[i*3 +: 3]), 
                    .fab_awburst (dma_s_awburst[i*2 +: 2]), .fab_awlock  (dma_s_awlock[i]), .fab_awcache(dma_s_awcache[i*4 +: 4]), .fab_awprot(slot_dma_awprot_o[i*3 +: 3]), 
                    .fab_awvalid (dma_s_awvalid[i]), .fab_awready (dma_s_awready[i]),
                    .fab_wdata   (dma_s_wdata[i*32 +: 32]), .fab_wstrb   (dma_s_wstrb[i*4 +: 4]), .fab_wlast   (dma_s_wlast[i]), .fab_wvalid (dma_s_wvalid[i]), .fab_wready  (dma_s_wready[i]), 
                    .fab_bid     (dma_s_bid[i*AXI_ID_WIDTH +: AXI_ID_WIDTH]), .fab_bresp   (dma_s_bresp[i*2 +: 2]), .fab_bvalid  (dma_s_bvalid[i]), .fab_bready  (dma_s_bready[i]),
                    .fab_arid    (dma_s_arid[i*AXI_ID_WIDTH +: AXI_ID_WIDTH]), .fab_araddr (dma_s_araddr[i*32 +: 32]), .fab_arlen  (dma_s_arlen[i*8 +: 8]), .fab_arsize (dma_s_arsize[i*3 +: 3]), 
                    .fab_arburst (dma_s_arburst[i*2 +: 2]), .fab_arlock  (dma_s_arlock[i]), .fab_arcache(dma_s_arcache[i*4 +: 4]), .fab_arprot(slot_dma_arprot_o[i*3 +: 3]), 
                    .fab_arvalid (dma_s_arvalid[i]), .fab_arready (dma_s_arready[i]),
                    .fab_rid     (dma_s_rid[i*AXI_ID_WIDTH +: AXI_ID_WIDTH]), .fab_rdata   (dma_s_rdata[i*32 +: 32]), .fab_rresp   (dma_s_rresp[i*2 +: 2]), .fab_rlast   (dma_s_rlast[i]), 
                    .fab_rvalid  (dma_s_rvalid[i]), .fab_rready  (dma_s_rready[i]),
                    
                    // SoC Side (Drives internal `dec_dma_` wires to Decoupler)
                    .soc_awid    (dec_dma_awid),     .soc_awaddr  (dec_dma_awaddr),  .soc_awlen   (dec_dma_awlen),   .soc_awsize (dec_dma_awsize), .soc_awburst(dec_dma_awburst), 
                    .soc_awlock  (dec_dma_awlock),   .soc_awcache (dec_dma_awcache), .soc_awprot  (dec_dma_awprot),  .soc_awvalid(dec_dma_awvalid),.soc_awready(dec_dma_awready),
                    .soc_wdata   (dec_dma_wdata),    .soc_wstrb   (dec_dma_wstrb),   .soc_wlast   (dec_dma_wlast),   .soc_wvalid (dec_dma_wvalid), .soc_wready (dec_dma_wready),
                    .soc_bid     (dec_dma_bid),      .soc_bresp   (dec_dma_bresp),   .soc_bvalid  (dec_dma_bvalid),  .soc_bready (dec_dma_bready),
                    .soc_arid    (dec_dma_arid),     .soc_araddr  (dec_dma_araddr),  .soc_arlen   (dec_dma_arlen),   .soc_arsize (dec_dma_arsize), .soc_arburst(dec_dma_arburst), 
                    .soc_arlock  (dec_dma_arlock),   .soc_arcache (dec_dma_arcache), .soc_arprot  (dec_dma_arprot),  .soc_arvalid(dec_dma_arvalid),.soc_arready(dec_dma_arready),
                    .soc_rid     (dec_dma_rid),      .soc_rdata   (dec_dma_rdata),   .soc_rresp   (dec_dma_rresp),   .soc_rlast  (dec_dma_rlast),  .soc_rvalid (dec_dma_rvalid),  .soc_rready (dec_dma_rready)
                );
            end else begin : gen_bypass_bridge_dma
                assign dec_dma_awid = dma_s_awid[i*AXI_ID_WIDTH +: AXI_ID_WIDTH]; assign dec_dma_awaddr = dma_s_awaddr[i*32 +: 32]; assign dec_dma_awlen = dma_s_awlen[i*8 +: 8]; assign dec_dma_awsize = dma_s_awsize[i*3 +: 3]; assign dec_dma_awburst = dma_s_awburst[i*2 +: 2]; assign dec_dma_awlock = dma_s_awlock[i]; assign dec_dma_awcache = dma_s_awcache[i*4 +: 4]; assign dec_dma_awprot = slot_dma_awprot_o[i*3 +: 3]; assign dec_dma_awvalid = dma_s_awvalid[i]; assign dma_s_awready[i] = dec_dma_awready;
                assign dec_dma_wdata = dma_s_wdata[i*32 +: 32]; assign dec_dma_wstrb = dma_s_wstrb[i*4 +: 4]; assign dec_dma_wlast = dma_s_wlast[i]; assign dec_dma_wvalid = dma_s_wvalid[i]; assign dma_s_wready[i] = dec_dma_wready;
                assign dma_s_bid[i*AXI_ID_WIDTH +: AXI_ID_WIDTH] = dec_dma_bid; assign dma_s_bresp[i*2 +: 2] = dec_dma_bresp; assign dma_s_bvalid[i] = dec_dma_bvalid; assign dec_dma_bready = dma_s_bready[i];
                assign dec_dma_arid = dma_s_arid[i*AXI_ID_WIDTH +: AXI_ID_WIDTH]; assign dec_dma_araddr = dma_s_araddr[i*32 +: 32]; assign dec_dma_arlen = dma_s_arlen[i*8 +: 8]; assign dec_dma_arsize = dma_s_arsize[i*3 +: 3]; assign dec_dma_arburst = dma_s_arburst[i*2 +: 2]; assign dec_dma_arlock = dma_s_arlock[i]; assign dec_dma_arcache = dma_s_arcache[i*4 +: 4]; assign dec_dma_arprot = slot_dma_arprot_o[i*3 +: 3]; assign dec_dma_arvalid = dma_s_arvalid[i]; assign dma_s_arready[i] = dec_dma_arready;
                assign dma_s_rid[i*AXI_ID_WIDTH +: AXI_ID_WIDTH] = dec_dma_rid; assign dma_s_rdata[i*32 +: 32] = dec_dma_rdata; assign dma_s_rresp[i*2 +: 2] = dec_dma_rresp; assign dma_s_rlast[i] = dec_dma_rlast; assign dma_s_rvalid[i] = dec_dma_rvalid; assign dec_dma_rready = dma_s_rready[i];
            end

            // -----------------------------------------------------------
            // WATCHDOG 4: SoC AXI-Full Slave (Fabric Side of Slice)
            // -----------------------------------------------------------
            if (ENABLE_WDOG_DMA_SLAVE) begin : gen_wdog_ds
                wire ds_fault_to_w, ds_fault_to_r;
                wire ds_fault_drop_w, ds_fault_drop_r;
                wire ds_fault_unst_w, ds_fault_unst_r;

                axi_watchdog_slave_monitor #(
                    .ENABLE_TIMEOUT          (1'b1),
                    .ENABLE_DROPPED_VALID    (1'b1),
                    .ENABLE_PAYLOAD_STABILITY(1'b0),
                    .WATCHDOG_LIMIT          (512),
                    .AXI_ID_WIDTH            (AXI_ID_WIDTH)
                ) inst_wdog_ds (
                    .clk_i(clk_i), .rstn_i(slot_wdog_rst_n),
                    .awvalid(slice_dma_awvalid), .awready(slice_dma_awready),
                    .wvalid (slice_dma_wvalid),  .wready (slice_dma_wready),  .wlast (slice_dma_wlast),
                    .bvalid (slice_dma_bvalid),  .bready (slice_dma_bready),  .bid   (slice_dma_bid), .bresp(slice_dma_bresp),
                    .arvalid(slice_dma_arvalid), .arready(slice_dma_arready),
                    .rvalid (slice_dma_rvalid),  .rready (slice_dma_rready),  .rlast (slice_dma_rlast),  .rid(slice_dma_rid), .rdata(slice_dma_rdata), .rresp(slice_dma_rresp),
                    .fault_timeout_w_o      (ds_fault_to_w),
                    .fault_timeout_r_o      (ds_fault_to_r),
                    .fault_dropped_valid_w_o(ds_fault_drop_w),
                    .fault_dropped_valid_r_o(ds_fault_drop_r),
                    .fault_unstable_w_o     (ds_fault_unst_w),
                    .fault_unstable_r_o     (ds_fault_unst_r)
                );
                assign wdog_ds_to_w[i] = ds_fault_to_w;
                assign wdog_ds_to_r[i] = ds_fault_to_r;
                assign wdog_ds_pr_w[i] = ds_fault_drop_w | ds_fault_unst_w;
                assign wdog_ds_pr_r[i] = ds_fault_drop_r | ds_fault_unst_r;
            end else begin : gen_no_wdog_ds
                assign wdog_ds_to_w[i] = 1'b0; assign wdog_ds_to_r[i] = 1'b0; assign wdog_ds_pr_w[i] = 1'b0; assign wdog_ds_pr_r[i] = 1'b0;
            end
        end
    endgenerate
endmodule