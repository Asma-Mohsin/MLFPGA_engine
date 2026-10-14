`timescale 1ns / 1ps

module efpga_subsystem_top #(
    parameter int NUM_SLOTS        = 1,
    parameter int AXI_ID_WIDTH     = 8,
    parameter logic [31:0] HW_VERSION = 32'hFAB00001,
    parameter int WEIGHT_SPLIT     = 8
) (
    // Global Clock & Synchronized System Resets (from Top Level)
    input  logic                                clk_i,
    input  logic                                rstn_i,      // Synchronized Active-Low Reset
    input  logic                                rst_i,       // Synchronized Active-High Reset

    // =========================================================================
    // AXI4-Lite Slave: Global Manager Interface
    // =========================================================================
    input  logic [31:0]                         s_axil_mgr_awaddr,
    input  logic [2:0]                          s_axil_mgr_awprot,
    input  logic                                s_axil_mgr_awvalid,
    output logic                                s_axil_mgr_awready,
    input  logic [31:0]                         s_axil_mgr_wdata,
    input  logic [3:0]                          s_axil_mgr_wstrb,
    input  logic                                s_axil_mgr_wvalid,
    output logic                                s_axil_mgr_wready,
    output logic [1:0]                          s_axil_mgr_bresp,
    output logic                                s_axil_mgr_bvalid,
    input  logic                                s_axil_mgr_bready,
    input  logic [31:0]                         s_axil_mgr_araddr,
    input  logic [2:0]                          s_axil_mgr_arprot,
    input  logic                                s_axil_mgr_arvalid,
    output logic                                s_axil_mgr_arready,
    output logic [31:0]                         s_axil_mgr_rdata,
    output logic [1:0]                          s_axil_mgr_rresp,
    output logic                                s_axil_mgr_rvalid,
    input  logic                                s_axil_mgr_rready,

    // =========================================================================
    // AXI4-Lite Slave: Slot Control Interface (Array)
    // =========================================================================
    input  logic [NUM_SLOTS*32-1:0]             s_axil_ctrl_awaddr,
    input  logic [NUM_SLOTS*3-1:0]              s_axil_ctrl_awprot,
    input  logic [NUM_SLOTS-1:0]                s_axil_ctrl_awvalid,
    output logic [NUM_SLOTS-1:0]                s_axil_ctrl_awready,
    input  logic [NUM_SLOTS*32-1:0]             s_axil_ctrl_wdata,
    input  logic [NUM_SLOTS*4-1:0]              s_axil_ctrl_wstrb,
    input  logic [NUM_SLOTS-1:0]                s_axil_ctrl_wvalid,
    output logic [NUM_SLOTS-1:0]                s_axil_ctrl_wready,
    output logic [NUM_SLOTS*2-1:0]              s_axil_ctrl_bresp,
    output logic [NUM_SLOTS-1:0]                s_axil_ctrl_bvalid,
    input  logic [NUM_SLOTS-1:0]                s_axil_ctrl_bready,
    input  logic [NUM_SLOTS*32-1:0]             s_axil_ctrl_araddr,
    input  logic [NUM_SLOTS*3-1:0]              s_axil_ctrl_arprot,
    input  logic [NUM_SLOTS-1:0]                s_axil_ctrl_arvalid,
    output logic [NUM_SLOTS-1:0]                s_axil_ctrl_arready,
    output logic [NUM_SLOTS*32-1:0]             s_axil_ctrl_rdata,
    output logic [NUM_SLOTS*2-1:0]              s_axil_ctrl_rresp,
    output logic [NUM_SLOTS-1:0]                s_axil_ctrl_rvalid,
    input  logic [NUM_SLOTS-1:0]                s_axil_ctrl_rready,

    // =========================================================================
    // AXI4 Full Master: Slot DMA Interface (Array)
    // =========================================================================
    output logic [NUM_SLOTS*AXI_ID_WIDTH-1:0]   m_axi_dma_awid,
    output logic [NUM_SLOTS*32-1:0]             m_axi_dma_awaddr,
    output logic [NUM_SLOTS*8-1:0]              m_axi_dma_awlen,
    output logic [NUM_SLOTS*3-1:0]              m_axi_dma_awsize,
    output logic [NUM_SLOTS*2-1:0]              m_axi_dma_awburst,
    output logic [NUM_SLOTS-1:0]                m_axi_dma_awlock,
    output logic [NUM_SLOTS*4-1:0]              m_axi_dma_awcache,
    output logic [NUM_SLOTS*3-1:0]              m_axi_dma_awprot,
    output logic [NUM_SLOTS-1:0]                m_axi_dma_awvalid,
    input  logic [NUM_SLOTS-1:0]                m_axi_dma_awready,
    output logic [NUM_SLOTS*32-1:0]             m_axi_dma_wdata,
    output logic [NUM_SLOTS*4-1:0]              m_axi_dma_wstrb,
    output logic [NUM_SLOTS-1:0]                m_axi_dma_wlast,
    output logic [NUM_SLOTS-1:0]                m_axi_dma_wvalid,
    input  logic [NUM_SLOTS-1:0]                m_axi_dma_wready,
    input  logic [NUM_SLOTS*AXI_ID_WIDTH-1:0]   m_axi_dma_bid,
    input  logic [NUM_SLOTS*2-1:0]              m_axi_dma_bresp,
    input  logic [NUM_SLOTS-1:0]                m_axi_dma_bvalid,
    output logic [NUM_SLOTS-1:0]                m_axi_dma_bready,
    output logic [NUM_SLOTS*AXI_ID_WIDTH-1:0]   m_axi_dma_arid,
    output logic [NUM_SLOTS*32-1:0]             m_axi_dma_araddr,
    output logic [NUM_SLOTS*8-1:0]              m_axi_dma_arlen,
    output logic [NUM_SLOTS*3-1:0]              m_axi_dma_arsize,
    output logic [NUM_SLOTS*2-1:0]              m_axi_dma_arburst,
    output logic [NUM_SLOTS-1:0]                m_axi_dma_arlock,
    output logic [NUM_SLOTS*4-1:0]              m_axi_dma_arcache,
    output logic [NUM_SLOTS*3-1:0]              m_axi_dma_arprot,
    output logic [NUM_SLOTS-1:0]                m_axi_dma_arvalid,
    input  logic [NUM_SLOTS-1:0]                m_axi_dma_arready,
    input  logic [NUM_SLOTS*AXI_ID_WIDTH-1:0]   m_axi_dma_rid,
    input  logic [NUM_SLOTS*32-1:0]             m_axi_dma_rdata,
    input  logic [NUM_SLOTS*2-1:0]              m_axi_dma_rresp,
    input  logic [NUM_SLOTS-1:0]                m_axi_dma_rlast,
    input  logic [NUM_SLOTS-1:0]                m_axi_dma_rvalid,
    output logic [NUM_SLOTS-1:0]                m_axi_dma_rready,

    // =========================================================================
    // External Padring PMOD Interface
    // =========================================================================
    input  logic [7:0]                          pmod_io_i,
    output logic [7:0]                          pmod_io_o,
    output logic [7:0]                          pmod_io_oe_o,

    // =========================================================================
    // External BitBang Configuration Interface
    // =========================================================================
    input  logic                                efpga_cfg_sclk_i = 1'b0,
    input  logic                                efpga_cfg_sdata_i = 1'b0,

    // =========================================================================
    // Interrupt Lines to CPU and SoC Subsystems
    // =========================================================================
    output logic [3:0]                          efpga_usr_irq_o,
    output logic [NUM_SLOTS-1:0]                efpga_fault_irq_o
);

    // =========================================================================
    // Internal Boundary Signals (Connector <-> Wrapper)
    // =========================================================================
    logic [NUM_SLOTS*32-1:0]            axil_ctrl_m_awaddr, axil_ctrl_m_wdata, axil_ctrl_m_araddr, axil_ctrl_m_rdata;
    logic [NUM_SLOTS*4-1:0]             axil_ctrl_m_wstrb;
    logic [NUM_SLOTS*3-1:0]             axil_ctrl_m_awprot, axil_ctrl_m_arprot;
    logic [NUM_SLOTS*2-1:0]             axil_ctrl_m_bresp, axil_ctrl_m_rresp;
    logic [NUM_SLOTS-1:0]               axil_ctrl_m_awvalid, axil_ctrl_m_awready, axil_ctrl_m_wvalid, axil_ctrl_m_wready, axil_ctrl_m_bvalid, axil_ctrl_m_bready;
    logic [NUM_SLOTS-1:0]               axil_ctrl_m_arvalid, axil_ctrl_m_arready, axil_ctrl_m_rvalid, axil_ctrl_m_rready;

    logic [NUM_SLOTS*32-1:0]            axi4_dma_s_awaddr, axi4_dma_s_wdata, axi4_dma_s_araddr, axi4_dma_s_rdata;
    logic [NUM_SLOTS*4-1:0]             axi4_dma_s_wstrb, axi4_dma_s_awcache, axi4_dma_s_arcache;
    logic [NUM_SLOTS*3-1:0]             axi4_dma_s_awsize, axi4_dma_s_arsize, axi4_dma_s_awprot, axi4_dma_s_arprot;
    logic [NUM_SLOTS*2-1:0]             axi4_dma_s_awburst, axi4_dma_s_arburst, axi4_dma_s_bresp, axi4_dma_s_rresp;
    logic [NUM_SLOTS*AXI_ID_WIDTH-1:0]  axi4_dma_s_awid, axi4_dma_s_bid, axi4_dma_s_arid, axi4_dma_s_rid;
    logic [NUM_SLOTS*8-1:0]             axi4_dma_s_awlen, axi4_dma_s_arlen;
    logic [NUM_SLOTS-1:0]               axi4_dma_s_awvalid, axi4_dma_s_awready, axi4_dma_s_wvalid, axi4_dma_s_wready, axi4_dma_s_bvalid, axi4_dma_s_bready;
    logic [NUM_SLOTS-1:0]               axi4_dma_s_arvalid, axi4_dma_s_arready, axi4_dma_s_rvalid, axi4_dma_s_rready, axi4_dma_s_wlast, axi4_dma_s_rlast;
    logic [NUM_SLOTS-1:0]               axi4_dma_s_awlock, axi4_dma_s_arlock;

    logic [31:0]                        efpga_config_data;
    logic                               efpga_config_we;
    logic [NUM_SLOTS-1:0][3:0]          slot_fabric_rst_n;
    logic [NUM_SLOTS-1:0]               slot_npu_rst_n;
    logic                               efpga_com_active;
    logic [NUM_SLOTS-1:0][31:0]         slot_debug_in;
    logic [NUM_SLOTS-1:0][31:0]         slot_debug_out;
    logic [NUM_SLOTS*3-1:0]             slot_dma_awprot;
    logic [NUM_SLOTS*3-1:0]             slot_dma_arprot;

    // =========================================================================
    // External BitBang Configuration Clock Snooper (4-bit Glitch Filter)
    // =========================================================================
    logic [2:0] sclk_sync;
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            sclk_sync <= 3'b000;
        end else begin
            sclk_sync <= {sclk_sync[1:0], efpga_cfg_sclk_i};
        end
    end
    wire sclk_edge = sclk_sync[2] ^ sclk_sync[1];

    // 4-bit saturating edge filter: confirms 16 transitions on s_clk to reject glitches
    logic [3:0] bb_edge_cnt;
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            bb_edge_cnt <= 4'd0;
        end else if (!slot_fabric_rst_n[0][0]) begin
            bb_edge_cnt <= 4'd0;
        end else if (sclk_edge && (bb_edge_cnt != 4'd15)) begin
            bb_edge_cnt <= bb_edge_cnt + 4'd1;
        end
    end

    wire bitbang_active = (bb_edge_cnt == 4'd15);

    // =========================================================================
    // eFPGA Connector (Isolation, Decouplers, Watchdogs, Dynamic PMP)
    // =========================================================================
    efpga_connector #(
        .NUM_SLOTS(NUM_SLOTS),
        .AXI_ID_WIDTH(AXI_ID_WIDTH),
        .HW_VERSION(HW_VERSION)
    ) efpga_connector_inst (
        .clk_i               (clk_i),
        .rstn_i              (rstn_i),
        .rst_i               (rst_i),

        // Global Manager Interface
        .mgr_s_awaddr        (s_axil_mgr_awaddr),
        .mgr_s_awprot        (s_axil_mgr_awprot),
        .mgr_s_awvalid       (s_axil_mgr_awvalid),
        .mgr_s_awready       (s_axil_mgr_awready),
        .mgr_s_wdata         (s_axil_mgr_wdata),
        .mgr_s_wstrb         (s_axil_mgr_wstrb),
        .mgr_s_wvalid        (s_axil_mgr_wvalid),
        .mgr_s_wready        (s_axil_mgr_wready),
        .mgr_s_bresp         (s_axil_mgr_bresp),
        .mgr_s_bvalid        (s_axil_mgr_bvalid),
        .mgr_s_bready        (s_axil_mgr_bready),
        .mgr_s_araddr        (s_axil_mgr_araddr),
        .mgr_s_arprot        (s_axil_mgr_arprot),
        .mgr_s_arvalid       (s_axil_mgr_arvalid),
        .mgr_s_arready       (s_axil_mgr_arready),
        .mgr_s_rdata         (s_axil_mgr_rdata),
        .mgr_s_rresp         (s_axil_mgr_rresp),
        .mgr_s_rvalid        (s_axil_mgr_rvalid),
        .mgr_s_rready        (s_axil_mgr_rready),

        // Slot Control Interface (External Slaves -> Connector)
        .ctrl_s_awaddr       (s_axil_ctrl_awaddr),
        .ctrl_s_awprot       (s_axil_ctrl_awprot),
        .ctrl_s_awvalid      (s_axil_ctrl_awvalid),
        .ctrl_s_awready      (s_axil_ctrl_awready),
        .ctrl_s_wdata        (s_axil_ctrl_wdata),
        .ctrl_s_wstrb        (s_axil_ctrl_wstrb),
        .ctrl_s_wvalid       (s_axil_ctrl_wvalid),
        .ctrl_s_wready       (s_axil_ctrl_wready),
        .ctrl_s_bresp        (s_axil_ctrl_bresp),
        .ctrl_s_bvalid       (s_axil_ctrl_bvalid),
        .ctrl_s_bready       (s_axil_ctrl_bready),
        .ctrl_s_araddr       (s_axil_ctrl_araddr),
        .ctrl_s_arprot       (s_axil_ctrl_arprot),
        .ctrl_s_arvalid      (s_axil_ctrl_arvalid),
        .ctrl_s_arready      (s_axil_ctrl_arready),
        .ctrl_s_rdata        (s_axil_ctrl_rdata),
        .ctrl_s_rresp        (s_axil_ctrl_rresp),
        .ctrl_s_rvalid       (s_axil_ctrl_rvalid),
        .ctrl_s_rready       (s_axil_ctrl_rready),

        // Protected Control Interface (Connector -> Fabric Wrapper)
        .ctrl_m_awaddr       (axil_ctrl_m_awaddr),
        .ctrl_m_awprot       (axil_ctrl_m_awprot),
        .ctrl_m_awvalid      (axil_ctrl_m_awvalid),
        .ctrl_m_awready      (axil_ctrl_m_awready),
        .ctrl_m_wdata        (axil_ctrl_m_wdata),
        .ctrl_m_wstrb        (axil_ctrl_m_wstrb),
        .ctrl_m_wvalid       (axil_ctrl_m_wvalid),
        .ctrl_m_wready       (axil_ctrl_m_wready),
        .ctrl_m_bresp        (axil_ctrl_m_bresp),
        .ctrl_m_bvalid       (axil_ctrl_m_bvalid),
        .ctrl_m_bready       (axil_ctrl_m_bready),
        .ctrl_m_araddr       (axil_ctrl_m_araddr),
        .ctrl_m_arprot       (axil_ctrl_m_arprot),
        .ctrl_m_arvalid      (axil_ctrl_m_arvalid),
        .ctrl_m_arready      (axil_ctrl_m_arready),
        .ctrl_m_rdata        (axil_ctrl_m_rdata),
        .ctrl_m_rresp        (axil_ctrl_m_rresp),
        .ctrl_m_rvalid       (axil_ctrl_m_rvalid),
        .ctrl_m_rready       (axil_ctrl_m_rready),

        // Protected DMA Interface (Fabric Wrapper -> Connector)
        .dma_s_awid          (axi4_dma_s_awid),
        .dma_s_awaddr        (axi4_dma_s_awaddr),
        .dma_s_awlen         (axi4_dma_s_awlen),
        .dma_s_awsize        (axi4_dma_s_awsize),
        .dma_s_awburst       (axi4_dma_s_awburst),
        .dma_s_awlock        (axi4_dma_s_awlock),
        .dma_s_awcache       (axi4_dma_s_awcache),
        .dma_s_awprot        (axi4_dma_s_awprot),
        .dma_s_awvalid       (axi4_dma_s_awvalid),
        .dma_s_awready       (axi4_dma_s_awready),
        .dma_s_wdata         (axi4_dma_s_wdata),
        .dma_s_wstrb         (axi4_dma_s_wstrb),
        .dma_s_wlast         (axi4_dma_s_wlast),
        .dma_s_wvalid        (axi4_dma_s_wvalid),
        .dma_s_wready        (axi4_dma_s_wready),
        .dma_s_bid           (axi4_dma_s_bid),
        .dma_s_bresp         (axi4_dma_s_bresp),
        .dma_s_bvalid        (axi4_dma_s_bvalid),
        .dma_s_bready        (axi4_dma_s_bready),
        .dma_s_arid          (axi4_dma_s_arid),
        .dma_s_araddr        (axi4_dma_s_araddr),
        .dma_s_arlen         (axi4_dma_s_arlen),
        .dma_s_arsize        (axi4_dma_s_arsize),
        .dma_s_arburst       (axi4_dma_s_arburst),
        .dma_s_arlock        (axi4_dma_s_arlock),
        .dma_s_arcache       (axi4_dma_s_arcache),
        .dma_s_arprot        (axi4_dma_s_arprot),
        .dma_s_arvalid       (axi4_dma_s_arvalid),
        .dma_s_arready       (axi4_dma_s_arready),
        .dma_s_rid           (axi4_dma_s_rid),
        .dma_s_rdata         (axi4_dma_s_rdata),
        .dma_s_rresp         (axi4_dma_s_rresp),
        .dma_s_rlast         (axi4_dma_s_rlast),
        .dma_s_rvalid        (axi4_dma_s_rvalid),
        .dma_s_rready        (axi4_dma_s_rready),

        // Filtered DMA Interface (Connector -> External Masters)
        .dma_m_awid          (m_axi_dma_awid),
        .dma_m_awaddr        (m_axi_dma_awaddr),
        .dma_m_awlen         (m_axi_dma_awlen),
        .dma_m_awsize        (m_axi_dma_awsize),
        .dma_m_awburst       (m_axi_dma_awburst),
        .dma_m_awlock        (m_axi_dma_awlock),
        .dma_m_awcache       (m_axi_dma_awcache),
        .dma_m_awprot        (m_axi_dma_awprot),
        .dma_m_awvalid       (m_axi_dma_awvalid),
        .dma_m_awready       (m_axi_dma_awready),
        .dma_m_wdata         (m_axi_dma_wdata),
        .dma_m_wstrb         (m_axi_dma_wstrb),
        .dma_m_wlast         (m_axi_dma_wlast),
        .dma_m_wvalid        (m_axi_dma_wvalid),
        .dma_m_wready        (m_axi_dma_wready),
        .dma_m_bid           (m_axi_dma_bid),
        .dma_m_bresp         (m_axi_dma_bresp),
        .dma_m_bvalid        (m_axi_dma_bvalid),
        .dma_m_bready        (m_axi_dma_bready),
        .dma_m_arid          (m_axi_dma_arid),
        .dma_m_araddr        (m_axi_dma_araddr),
        .dma_m_arlen         (m_axi_dma_arlen),
        .dma_m_arsize        (m_axi_dma_arsize),
        .dma_m_arburst       (m_axi_dma_arburst),
        .dma_m_arlock        (m_axi_dma_arlock),
        .dma_m_arcache       (m_axi_dma_arcache),
        .dma_m_arprot        (m_axi_dma_arprot),
        .dma_m_arvalid       (m_axi_dma_arvalid),
        .dma_m_arready       (m_axi_dma_arready),
        .dma_m_rid           (m_axi_dma_rid),
        .dma_m_rdata         (m_axi_dma_rdata),
        .dma_m_rresp         (m_axi_dma_rresp),
        .dma_m_rlast         (m_axi_dma_rlast),
        .dma_m_rvalid        (m_axi_dma_rvalid),
        .dma_m_rready        (m_axi_dma_rready),

        // eFPGA Global Management Signals
        .efpga_config_data_o (efpga_config_data),
        .efpga_config_we_o   (efpga_config_we),
        .slot_fabric_rst_n_o (slot_fabric_rst_n),
        .slot_npu_rst_n_o    (slot_npu_rst_n),
        .efpga_com_active_i  (efpga_com_active),
        .efpga_bitbang_active_i (bitbang_active),
        .slot_debug_in_i     (slot_debug_in),
        .slot_debug_out_o    (slot_debug_out),
        .slot_dma_awprot_o   (slot_dma_awprot),
        .slot_dma_arprot_o   (slot_dma_arprot),
        .fault_irq_o         (efpga_fault_irq_o)
    );

    // =========================================================================
    // Direct eFPGA Fabric & Hardened NPU Complex Interconnect
    // =========================================================================
    // Interconnect Buses (eFPGA Fabric <-> NPU Complex)
    wire        [71:0] npu_act_addr;
    wire        [63:0] npu_act_rdata;
    wire        [63:0] npu_act_wdata;
    wire        [7:0]  npu_act_we;
    wire        [15:0] npu_addr;
    wire        [63:0] npu_rdata;
    wire        [5:0]  npu_read_bank_sel;
    wire        [63:0] npu_wdata;
    wire        [15:0] npu_we;
    wire signed [63:0] npu_weight_in;
    wire signed [63:0] npu_out_act;

    wire               npu_array_en;
    wire               npu_psum_systolic_en;
    wire               npu_psum_lut_en;
    wire               npu_swap_weights;
    wire               npu_psum_skew_en;
    wire               npu_compute_bank_swap;
    wire        [29:0] npu_quant_shift_in;
    wire               npu_quant_shift_en;
    wire        [31:0] npu_xbar_sel;
    wire        [7:0]  npu_weight_shift_en;

    // Static DMA Master Attributes
    assign axi4_dma_s_awid   = {NUM_SLOTS{AXI_ID_WIDTH'(1)}};
    assign axi4_dma_s_arid   = {NUM_SLOTS{AXI_ID_WIDTH'(1)}};
    assign axi4_dma_s_awprot = slot_dma_awprot;
    assign axi4_dma_s_arprot = slot_dma_arprot;

`ifdef __ICARUS__
    `ifndef EXCLUDE_FPGA
        `define EXCLUDE_FPGA
    `endif
`endif
`ifdef EXCLUDE_EFPGA
    `ifndef EXCLUDE_FPGA
        `define EXCLUDE_FPGA
    `endif
`endif

`ifndef EXCLUDE_FPGA
    // -------------------------------------------------------------------------
    // FABulous eFPGA Soft-Fabric Top
    // -------------------------------------------------------------------------
    eFPGA_top fabric_inst (
        .CLK                 (clk_i),
        .resetn              (rstn_i),

        // Bitstream Configuration
        .SelfWriteData       (efpga_config_data),
        .SelfWriteStrobe     (efpga_config_we),
        .ComActive           (efpga_com_active),
        .Rx                  (1'b1),
        .ReceiveLED          (),
        .s_clk               (efpga_cfg_sclk_i),
        .s_data              (efpga_cfg_sdata_i),

        // Slot 0 Control (AXI-Lite Slave from Connector)
        .AXIL_S_SOC_AWADDR   (axil_ctrl_m_awaddr[9:0]),
        .AXIL_S_SOC_AWPROT   (axil_ctrl_m_awprot[2:0]),
        .AXIL_S_SOC_AWVALID  (axil_ctrl_m_awvalid[0]),
        .AXIL_S_SOC_AWREADY  (axil_ctrl_m_awready[0]),
        .AXIL_S_SOC_WDATA    (axil_ctrl_m_wdata[31:0]),
        .AXIL_S_SOC_WSTRB    (axil_ctrl_m_wstrb[3:0]),
        .AXIL_S_SOC_WVALID   (axil_ctrl_m_wvalid[0]),
        .AXIL_S_SOC_WREADY   (axil_ctrl_m_wready[0]),
        .AXIL_S_SOC_BRESP    (axil_ctrl_m_bresp[1:0]),
        .AXIL_S_SOC_BVALID   (axil_ctrl_m_bvalid[0]),
        .AXIL_S_SOC_BREADY   (axil_ctrl_m_bready[0]),
        .AXIL_S_SOC_ARADDR   (axil_ctrl_m_araddr[9:0]),
        .AXIL_S_SOC_ARPROT   (axil_ctrl_m_arprot[2:0]),
        .AXIL_S_SOC_ARVALID  (axil_ctrl_m_arvalid[0]),
        .AXIL_S_SOC_ARREADY  (axil_ctrl_m_arready[0]),
        .AXIL_S_SOC_RDATA    (axil_ctrl_m_rdata[31:0]),
        .AXIL_S_SOC_RRESP    (axil_ctrl_m_rresp[1:0]),
        .AXIL_S_SOC_RVALID   (axil_ctrl_m_rvalid[0]),
        .AXIL_S_SOC_RREADY   (axil_ctrl_m_rready[0]),

        // Slot 0 DMA (AXI4 Master to Connector)
        .AXI_M_SOC_AWADDR    (axi4_dma_s_awaddr[31:0]),
        .AXI_M_SOC_AWLEN     (axi4_dma_s_awlen[7:0]),
        .AXI_M_SOC_AWSIZE    (axi4_dma_s_awsize[2:0]),
        .AXI_M_SOC_AWBURST   (axi4_dma_s_awburst[1:0]),
        .AXI_M_SOC_AWLOCK    (axi4_dma_s_awlock[0]),
        .AXI_M_SOC_AWCACHE   (axi4_dma_s_awcache[3:0]),
        .AXI_M_SOC_AWVALID   (axi4_dma_s_awvalid[0]),
        .AXI_M_SOC_AWREADY   (axi4_dma_s_awready[0]),
        .AXI_M_SOC_WDATA     (axi4_dma_s_wdata[31:0]),
        .AXI_M_SOC_WSTRB     (axi4_dma_s_wstrb[3:0]),
        .AXI_M_SOC_WLAST     (axi4_dma_s_wlast[0]),
        .AXI_M_SOC_WVALID    (axi4_dma_s_wvalid[0]),
        .AXI_M_SOC_WREADY    (axi4_dma_s_wready[0]),
        .AXI_M_SOC_BRESP     (axi4_dma_s_bresp[1:0]),
        .AXI_M_SOC_BVALID    (axi4_dma_s_bvalid[0]),
        .AXI_M_SOC_BREADY    (axi4_dma_s_bready[0]),
        .AXI_M_SOC_ARADDR    (axi4_dma_s_araddr[31:0]),
        .AXI_M_SOC_ARLEN     (axi4_dma_s_arlen[7:0]),
        .AXI_M_SOC_ARSIZE    (axi4_dma_s_arsize[2:0]),
        .AXI_M_SOC_ARBURST   (axi4_dma_s_arburst[1:0]),
        .AXI_M_SOC_ARLOCK    (axi4_dma_s_arlock[0]),
        .AXI_M_SOC_ARCACHE   (axi4_dma_s_arcache[3:0]),
        .AXI_M_SOC_ARVALID   (axi4_dma_s_arvalid[0]),
        .AXI_M_SOC_ARREADY   (axi4_dma_s_arready[0]),
        .AXI_M_SOC_RDATA     (axi4_dma_s_rdata[31:0]),
        .AXI_M_SOC_RRESP     (axi4_dma_s_rresp[1:0]),
        .AXI_M_SOC_RLAST     (axi4_dma_s_rlast[0]),
        .AXI_M_SOC_RVALID    (axi4_dma_s_rvalid[0]),
        .AXI_M_SOC_RREADY    (axi4_dma_s_rready[0]),

        // Debug & Slot Control
        .DEBUG_IN            (slot_debug_in[0]),
        .DEBUG_OUT           (slot_debug_out[0]),
        .SLOT_SOFT_RST_N     (slot_fabric_rst_n[0]),
        .USR_IRQ             (efpga_usr_irq_o),

        // External PMOD Padring
        .PMOD_IO_I           (pmod_io_i),
        .PMOD_IO_O           (pmod_io_o),
        .PMOD_IO_OE_O        (pmod_io_oe_o),

        // Dedicated NPU Complex Interconnect
        .NPU_ARRAY_EN        (npu_array_en),
        .NPU_PSUM_SYSTOLIC_EN(npu_psum_systolic_en),
        .NPU_PSUM_LUT_EN     (npu_psum_lut_en),
        .NPU_PSUM_SKEW_EN    (npu_psum_skew_en),
        .NPU_COMPUTE_BANK_SWAP(npu_compute_bank_swap),
        .NPU_SWAP_WEIGHTS    (npu_swap_weights),
        .NPU_QUANT_SHIFT_EN  (npu_quant_shift_en),
        .NPU_QUANT_SHIFT_IN  (npu_quant_shift_in),
        .NPU_XBAR_SEL        (npu_xbar_sel),
        .NPU_WEIGHT_SHIFT_EN (npu_weight_shift_en),
        .NPU_WEIGHT_IN       (npu_weight_in),

        .NPU_ADDR            (npu_addr),
        .NPU_WE              (npu_we),
        .NPU_WDATA           (npu_wdata),
        .NPU_RDATA           (npu_rdata),
        .NPU_READ_BANK_SEL   (npu_read_bank_sel),

        .NPU_ACT_ADDR        (npu_act_addr),
        .NPU_ACT_WE          (npu_act_we),
        .NPU_ACT_WDATA       (npu_act_wdata),
        .NPU_ACT_RDATA       (npu_act_rdata),
        .NPU_OUT_ACT         (npu_out_act)
    );

    // -------------------------------------------------------------------------
    // Hardened NPU Complex Core
    // -------------------------------------------------------------------------
    npu_wrapper #(
        .ARRAY_HEIGHT        (8),
        .ARRAY_WIDTH         (8),
        .TILE_SIZE           (16),
        .ACT_HALO_PAD        (2),
        .ACTIVATION_WIDTH    (8),
        .WEIGHT_WIDTH        (8),
        .PSUM_WIDTH          (32),
        .SCALE_WIDTH         (16),
        .WEIGHT_SPLIT        (WEIGHT_SPLIT)
    ) npu_inst (
        .clk_i               (clk_i),
        .rst_n               (slot_npu_rst_n[0]),

        .crossbar_sel        (npu_xbar_sel),

        .array_en            (npu_array_en),
        .psum_systolic_en    (npu_psum_systolic_en),
        .psum_lut_en         (npu_psum_lut_en),
        .weight_shift_en     (npu_weight_shift_en[WEIGHT_SPLIT-1:0]),
        .swap_weights        (npu_swap_weights),
        .psum_skew_en        (npu_psum_skew_en),
        .compute_bank_swap   (npu_compute_bank_swap),

        .weight_shift_in     (npu_weight_in),
        .quant_shift_in      (npu_quant_shift_in),
        .quant_shift_en      (npu_quant_shift_en),

        .psum_A_addr         (npu_addr[7:0]),
        .psum_A_we           (npu_we[7:0]),
        .psum_A_wdata        (npu_wdata[31:0]),
        .psum_A_read_bank_sel(npu_read_bank_sel[2:0]),
        .psum_A_rdata        (npu_rdata[31:0]),

        .psum_B_addr         (npu_addr[15:8]),
        .psum_B_we           (npu_we[15:8]),
        .psum_B_wdata        (npu_wdata[63:32]),
        .psum_B_read_bank_sel(npu_read_bank_sel[5:3]),
        .psum_B_rdata        (npu_rdata[63:32]),

        .ext_act_sram_we     (npu_act_we),
        .ext_act_sram_addr   (npu_act_addr),
        .ext_act_sram_wdata  (npu_act_wdata),
        .act_sram_rdata      (npu_act_rdata),

        .out_act             (npu_out_act)
    );

    // Multi-slot termination for slots > 0
    generate
        if (NUM_SLOTS > 1) begin : gen_extra_slots
            assign slot_debug_in[NUM_SLOTS-1:1]         = slot_debug_out[NUM_SLOTS-1:1];
            assign axil_ctrl_m_awready[NUM_SLOTS-1:1]   = '1;
            assign axil_ctrl_m_wready[NUM_SLOTS-1:1]    = '1;
            assign axil_ctrl_m_bresp[NUM_SLOTS*2-1:2]   = '0;
            assign axil_ctrl_m_bvalid[NUM_SLOTS-1:1]    = '0;
            assign axil_ctrl_m_arready[NUM_SLOTS-1:1]   = '1;
            assign axil_ctrl_m_rdata[NUM_SLOTS*32-1:32] = '0;
            assign axil_ctrl_m_rresp[NUM_SLOTS*2-1:2]   = '0;
            assign axil_ctrl_m_rvalid[NUM_SLOTS-1:1]    = '0;

            assign axi4_dma_s_awready[NUM_SLOTS-1:1]    = '1;
            assign axi4_dma_s_wready[NUM_SLOTS-1:1]     = '1;
            assign axi4_dma_s_bresp[NUM_SLOTS*2-1:2]    = '0;
            assign axi4_dma_s_bvalid[NUM_SLOTS-1:1]     = '0;
            assign axi4_dma_s_arready[NUM_SLOTS-1:1]    = '1;
            assign axi4_dma_s_rdata[NUM_SLOTS*32-1:32]  = '0;
            assign axi4_dma_s_rresp[NUM_SLOTS*2-1:2]    = '0;
            assign axi4_dma_s_rlast[NUM_SLOTS-1:1]      = '0;
            assign axi4_dma_s_rvalid[NUM_SLOTS-1:1]     = '0;
        end
    endgenerate

`else // Simulation Bypass when EXCLUDE_FPGA is defined
    assign axil_ctrl_m_awready = {NUM_SLOTS{1'b1}};
    assign axil_ctrl_m_wready  = {NUM_SLOTS{1'b1}};
    assign axil_ctrl_m_bresp   = '0;
    assign axil_ctrl_m_bvalid  = axil_ctrl_m_wvalid & axil_ctrl_m_awvalid;
    assign axil_ctrl_m_arready = {NUM_SLOTS{1'b1}};
    assign axil_ctrl_m_rdata   = 32'hDEADBEEF;
    assign axil_ctrl_m_rresp   = '0;
    assign axil_ctrl_m_rvalid  = axil_ctrl_m_arvalid;

    assign axi4_dma_s_awaddr   = '0;
    assign axi4_dma_s_awlen    = '0;
    assign axi4_dma_s_awsize   = '0;
    assign axi4_dma_s_awburst  = '0;
    assign axi4_dma_s_awlock   = '0;
    assign axi4_dma_s_awcache  = '0;
    assign axi4_dma_s_awvalid  = '0;
    assign axi4_dma_s_wdata    = '0;
    assign axi4_dma_s_wstrb    = '0;
    assign axi4_dma_s_wlast    = '0;
    assign axi4_dma_s_wvalid   = '0;
    assign axi4_dma_s_bready   = '0;
    assign axi4_dma_s_araddr   = '0;
    assign axi4_dma_s_arlen    = '0;
    assign axi4_dma_s_arsize   = '0;
    assign axi4_dma_s_arburst  = '0;
    assign axi4_dma_s_arlock   = '0;
    assign axi4_dma_s_arcache  = '0;
    assign axi4_dma_s_arvalid  = '0;
    assign axi4_dma_s_rready   = '0;

    assign efpga_com_active    = 1'b0;
    assign slot_debug_in       = slot_debug_out;

    assign pmod_io_o           = '0;
    assign pmod_io_oe_o        = '0;
    assign efpga_usr_irq_o     = '0;

    assign npu_act_addr        = '0;
    assign npu_act_wdata       = '0;
    assign npu_act_we          = '0;
    assign npu_addr            = '0;
    assign npu_wdata           = '0;
    assign npu_we              = '0;
    assign npu_read_bank_sel   = '0;
    assign npu_weight_in       = '0;
    assign npu_array_en        = '0;
    assign npu_psum_systolic_en= '0;
    assign npu_psum_lut_en     = '0;
    assign npu_swap_weights    = '0;
    assign npu_psum_skew_en    = '0;
    assign npu_compute_bank_swap = '0;
    assign npu_quant_shift_in  = '0;
    assign npu_quant_shift_en  = '0;
    assign npu_xbar_sel        = '0;
    assign npu_weight_shift_en = '0;
`endif

endmodule