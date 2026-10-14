`timescale 1ns / 1ps

module axi_decoupler #(
    parameter integer AXI_ID_WIDTH = 8
)(
    input  wire        clk_i,
    input  wire        rstn_i,

    input  wire        decouple_req_i,
    input  wire        force_decouple_i,
    output wire        is_decoupled_o,
    output wire        host_active_o,
    output wire        dma_active_o,

    // ===================================================================
    // CONTROL PATH: CPU -> Fabric (AXI-Lite)
    // ===================================================================
    input  wire [31:0] ctrl_s_axil_awaddr,  input  wire [2:0]  ctrl_s_axil_awprot,
    input  wire        ctrl_s_axil_awvalid, output wire        ctrl_s_axil_awready,
    input  wire [31:0] ctrl_s_axil_wdata,   input  wire [3:0]  ctrl_s_axil_wstrb,
    input  wire        ctrl_s_axil_wvalid,  output wire        ctrl_s_axil_wready,
    output wire [1:0]  ctrl_s_axil_bresp,   output wire        ctrl_s_axil_bvalid,  input  wire        ctrl_s_axil_bready,
    input  wire [31:0] ctrl_s_axil_araddr,  input  wire [2:0]  ctrl_s_axil_arprot,
    input  wire        ctrl_s_axil_arvalid, output wire        ctrl_s_axil_arready,
    output wire [31:0] ctrl_s_axil_rdata,   output wire [1:0]  ctrl_s_axil_rresp,
    output wire        ctrl_s_axil_rvalid,  input  wire        ctrl_s_axil_rready,

    output wire [31:0] ctrl_m_axil_awaddr,  output wire [2:0]  ctrl_m_axil_awprot,
    output wire        ctrl_m_axil_awvalid, input  wire        ctrl_m_axil_awready,
    output wire [31:0] ctrl_m_axil_wdata,   output wire [3:0]  ctrl_m_axil_wstrb,
    output wire        ctrl_m_axil_wvalid,  input  wire        ctrl_m_axil_wready,
    input  wire [1:0]  ctrl_m_axil_bresp,   input  wire        ctrl_m_axil_bvalid,  output wire        ctrl_m_axil_bready,
    output wire [31:0] ctrl_m_axil_araddr,  output wire [2:0]  ctrl_m_axil_arprot,
    output wire        ctrl_m_axil_arvalid, input  wire        ctrl_m_axil_arready,
    input  wire [31:0] ctrl_m_axil_rdata,   input  wire [1:0]  ctrl_m_axil_rresp,
    input  wire        ctrl_m_axil_rvalid,  output wire        ctrl_m_axil_rready,

    // ===================================================================
    // DMA PATH: Fabric -> Crossbar/RAM (Full AXI4)
    // ===================================================================
    input  wire [AXI_ID_WIDTH-1:0] dma_s_axi_awid,    input  wire [31:0]             dma_s_axi_awaddr,
    input  wire [7:0]              dma_s_axi_awlen,   input  wire [2:0]              dma_s_axi_awsize,
    input  wire [1:0]              dma_s_axi_awburst, input  wire                    dma_s_axi_awlock,
    input  wire [3:0]              dma_s_axi_awcache, input  wire [2:0]              dma_s_axi_awprot,
    input  wire                    dma_s_axi_awvalid, output wire                    dma_s_axi_awready,
    input  wire [31:0]             dma_s_axi_wdata,   input  wire [3:0]              dma_s_axi_wstrb,
    input  wire                    dma_s_axi_wlast,   input  wire                    dma_s_axi_wvalid,
    output wire                    dma_s_axi_wready,  output wire [AXI_ID_WIDTH-1:0] dma_s_axi_bid,
    output wire [1:0]              dma_s_axi_bresp,   output wire                    dma_s_axi_bvalid,
    input  wire                    dma_s_axi_bready,  input  wire [AXI_ID_WIDTH-1:0] dma_s_axi_arid,
    input  wire [31:0]             dma_s_axi_araddr,  input  wire [7:0]              dma_s_axi_arlen,
    input  wire [2:0]              dma_s_axi_arsize,  input  wire [1:0]              dma_s_axi_arburst,
    input  wire                    dma_s_axi_arlock,  input  wire [3:0]              dma_s_axi_arcache,
    input  wire [2:0]              dma_s_axi_arprot,  input  wire                    dma_s_axi_arvalid,
    output wire                    dma_s_axi_arready, output wire [AXI_ID_WIDTH-1:0] dma_s_axi_rid,
    output wire [31:0]             dma_s_axi_rdata,   output wire [1:0]              dma_s_axi_rresp,
    output wire                    dma_s_axi_rlast,   output wire                    dma_s_axi_rvalid,
    input  wire                    dma_s_axi_rready,

    output wire [AXI_ID_WIDTH-1:0] dma_m_axi_awid,    output wire [31:0]             dma_m_axi_awaddr,
    output wire [7:0]              dma_m_axi_awlen,   output wire [2:0]              dma_m_axi_awsize,
    output wire [1:0]              dma_m_axi_awburst, output wire                    dma_m_axi_awlock,
    output wire [3:0]              dma_m_axi_awcache, output wire [2:0]              dma_m_axi_awprot,
    output wire                    dma_m_axi_awvalid, input  wire                    dma_m_axi_awready,
    output wire [31:0]             dma_m_axi_wdata,   output wire [3:0]              dma_m_axi_wstrb,
    output wire                    dma_m_axi_wlast,   output wire                    dma_m_axi_wvalid,
    input  wire                    dma_m_axi_wready,  input  wire [AXI_ID_WIDTH-1:0] dma_m_axi_bid,
    input  wire [1:0]              dma_m_axi_bresp,   input  wire                    dma_m_axi_bvalid,
    output wire                    dma_m_axi_bready,  output wire [AXI_ID_WIDTH-1:0] dma_m_axi_arid,
    output wire [31:0]             dma_m_axi_araddr,  output wire [7:0]              dma_m_axi_arlen,
    output wire [2:0]              dma_m_axi_arsize,  output wire [1:0]              dma_m_axi_arburst,
    output wire                    dma_m_axi_arlock,  output wire [3:0]              dma_m_axi_arcache,
    output wire [2:0]              dma_m_axi_arprot,  output wire                    dma_m_axi_arvalid,
    input  wire                    dma_m_axi_arready, input  wire [AXI_ID_WIDTH-1:0] dma_m_axi_rid,
    input  wire [31:0]             dma_m_axi_rdata,   input  wire [1:0]              dma_m_axi_rresp,
    input  wire                    dma_m_axi_rlast,   input  wire                    dma_m_axi_rvalid,
    output wire                    dma_m_axi_rready
);

    // ===================================================================
    // TRANSACTION TRACKING & FLUSHER ENGINES
    // ===================================================================
    
    // -------------------------------------------------------------------
    // Host -> Fabric Tracking (Depth-1 Backpressure logic)
    // -------------------------------------------------------------------
    reg ctrl_aw_pending;
    reg ctrl_w_pending;
    reg ctrl_ar_pending;

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            ctrl_aw_pending <= 1'b0;
            ctrl_w_pending  <= 1'b0;
            ctrl_ar_pending <= 1'b0;
        end else begin
            // Address Write Tracker
            case ({ctrl_s_axil_awvalid & ctrl_s_axil_awready, ctrl_s_axil_bvalid & ctrl_s_axil_bready})
                2'b10: ctrl_aw_pending <= 1'b1;
                2'b01: ctrl_aw_pending <= 1'b0;
                2'b11: ctrl_aw_pending <= 1'b1; // Safely absorbs overlapping handshakes
                default: ;
            endcase
            
            // Data Write Tracker
            case ({ctrl_s_axil_wvalid & ctrl_s_axil_wready, ctrl_s_axil_bvalid & ctrl_s_axil_bready})
                2'b10: ctrl_w_pending <= 1'b1;
                2'b01: ctrl_w_pending <= 1'b0;
                2'b11: ctrl_w_pending <= 1'b1;
                default: ;
            endcase
            
            // Address Read Tracker
            case ({ctrl_s_axil_arvalid & ctrl_s_axil_arready, ctrl_s_axil_rvalid & ctrl_s_axil_rready})
                2'b10: ctrl_ar_pending <= 1'b1;
                2'b01: ctrl_ar_pending <= 1'b0;
                2'b11: ctrl_ar_pending <= 1'b1;
                default: ;
            endcase
        end
    end

    // -------------------------------------------------------------------
    // Fabric -> Crossbar Flusher Tracking (Sized for Max AXI Pipelines)
    // -------------------------------------------------------------------
    wire dma_m_aw_fire    = dma_m_axi_awvalid & dma_m_axi_awready;
    wire dma_m_w_fire     = dma_m_axi_wvalid  & dma_m_axi_wready;
    wire dma_m_b_fire     = dma_m_axi_bvalid  & dma_m_axi_bready;
    wire dma_m_ar_fire    = dma_m_axi_arvalid & dma_m_axi_arready;
    wire dma_m_rlast_fire = dma_m_axi_rvalid  & dma_m_axi_rready & dma_m_axi_rlast;

    // 16 bits = 65,535 max beats (supports 255 pending max-length bursts)
    reg [15:0] w_beats_owed; 
    reg [7:0]  b_resp_owed;
    reg [7:0]  r_bursts_owed;

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) w_beats_owed <= 0;
        else case ({dma_m_aw_fire, dma_m_w_fire})
            2'b10: w_beats_owed <= w_beats_owed + {8'b0, dma_m_axi_awlen} + 1;
            2'b01: if (w_beats_owed > 0) w_beats_owed <= w_beats_owed - 1;
            2'b11: w_beats_owed <= w_beats_owed + {8'b0, dma_m_axi_awlen}; 
            default: ;
        endcase
    end

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) b_resp_owed <= 0;
        else case ({dma_m_aw_fire, dma_m_b_fire})
            2'b10: b_resp_owed <= b_resp_owed + 1;
            2'b01: if (b_resp_owed > 0) b_resp_owed <= b_resp_owed - 1;
            2'b11: b_resp_owed <= b_resp_owed;
            default: ;
        endcase
    end

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) r_bursts_owed <= 0;
        else case ({dma_m_ar_fire, dma_m_rlast_fire})
            2'b10: r_bursts_owed <= r_bursts_owed + 1;
            2'b01: if (r_bursts_owed > 0) r_bursts_owed <= r_bursts_owed - 1;
            2'b11: r_bursts_owed <= r_bursts_owed;
            default: ;
        endcase
    end

    assign host_active_o = ctrl_aw_pending | ctrl_w_pending | ctrl_ar_pending | 
                           ctrl_s_axil_awvalid | ctrl_s_axil_arvalid;
                           
    assign dma_active_o  = (w_beats_owed > 0) | (b_resp_owed > 0) | (r_bursts_owed > 0) | 
                           dma_s_axi_awvalid | dma_s_axi_arvalid;

    // ===================================================================
    // THE MASTER SWITCH & RECOUPLE THROTTLE
    // ===================================================================
    reg decoupled_reg;
    assign is_decoupled_o = decoupled_reg;

    // is_safe: Can we safely DECOUPLE? (Bus is completely idle)
    wire is_safe = (~host_active_o) & (~dma_active_o);
    
    // is_drained: Can we safely RECOUPLE? (Fake Slave & Flusher have zero owed responses)
    wire is_drained = (~ctrl_aw_pending) && (~ctrl_w_pending) && (~ctrl_ar_pending) &&
                      (w_beats_owed == 0) && (b_resp_owed == 0) && (r_bursts_owed == 0);

    // We want to recouple, but we are waiting for the Fake Slave/Flusher to drain phantom handshakes.
    wire recouple_pending = decoupled_reg & !decouple_req_i & !force_decouple_i;

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            decoupled_reg <= 1'b1;
        end else if (force_decouple_i) begin
            decoupled_reg <= 1'b1;
        end else begin
            case (decoupled_reg)
                1'b1: begin
                    if (!decouple_req_i && is_drained) begin
                        decoupled_reg <= 1'b0;
                    end
                end
                1'b0: begin
                    if (decouple_req_i && is_safe) begin
                        decoupled_reg <= 1'b1;
                    end
                end
            endcase
        end
    end

    wire effective_decouple = decoupled_reg | force_decouple_i;


    // ===================================================================
    // HOST FAKE SLAVE & CONTROL PATH FIREWALL
    // ===================================================================
    // THE DEPTH-1 BACKPRESSURE: 
    // If a channel is pending, we drop READY to 0. We take no more 
    // work until the BVALID / RVALID response completes. We also stall
    // incoming requests when a recouple is pending.
    
    wire fake_awready = (~recouple_pending) & (~ctrl_aw_pending);
    wire fake_wready  = (~recouple_pending) & (~ctrl_w_pending);
    wire fake_arready = (~recouple_pending) & (~ctrl_ar_pending);

    assign ctrl_s_axil_awready = effective_decouple ? fake_awready : ctrl_m_axil_awready;
    assign ctrl_s_axil_wready  = effective_decouple ? fake_wready  : ctrl_m_axil_wready;
    assign ctrl_s_axil_arready = effective_decouple ? fake_arready : ctrl_m_axil_arready;

    // BVALID only fires when BOTH halves of the write transaction have arrived
    assign ctrl_s_axil_bvalid  = effective_decouple ? (ctrl_aw_pending & ctrl_w_pending) : ctrl_m_axil_bvalid;
    assign ctrl_s_axil_bresp   = effective_decouple ? 2'b10 /*SLVERR*/ : ctrl_m_axil_bresp;
    
    assign ctrl_s_axil_rvalid  = effective_decouple ? ctrl_ar_pending : ctrl_m_axil_rvalid;
    assign ctrl_s_axil_rdata   = effective_decouple ? 32'hBAD01000    : ctrl_m_axil_rdata;
    assign ctrl_s_axil_rresp   = effective_decouple ? 2'b10 /*SLVERR*/: ctrl_m_axil_rresp;

    // Clamped Outputs to Fabric (Firewall)
    assign ctrl_m_axil_awvalid = effective_decouple ? 1'b0 : ctrl_s_axil_awvalid;
    assign ctrl_m_axil_wvalid  = effective_decouple ? 1'b0 : ctrl_s_axil_wvalid;
    assign ctrl_m_axil_bready  = effective_decouple ? 1'b0 : ctrl_s_axil_bready;
    assign ctrl_m_axil_arvalid = effective_decouple ? 1'b0 : ctrl_s_axil_arvalid;
    assign ctrl_m_axil_rready  = effective_decouple ? 1'b0 : ctrl_s_axil_rready;

    assign ctrl_m_axil_awaddr  = ctrl_s_axil_awaddr;
    assign ctrl_m_axil_awprot  = ctrl_s_axil_awprot;
    assign ctrl_m_axil_wdata   = ctrl_s_axil_wdata;
    assign ctrl_m_axil_wstrb   = ctrl_s_axil_wstrb;
    assign ctrl_m_axil_araddr  = ctrl_s_axil_araddr;
    assign ctrl_m_axil_arprot  = ctrl_s_axil_arprot;

    // ===================================================================
    // DMA PIPELINE ISOLATION REGISTERS (Clean Async-Reset Implementation)
    // ===================================================================
    // If a Force Decouple triggers while VALID is high and READY is low, 
    // these registers hold the payload and safely preserve VALID high to the 
    // crossbar until READY arrives, preventing an AXI protocol violation.

    // --- AW Channel Ghost ---
    reg                    ghost_awvalid;
    reg [AXI_ID_WIDTH-1:0] ghost_awid;
    reg [31:0]             ghost_awaddr;
    reg [7:0]              ghost_awlen;
    reg [2:0]              ghost_awsize;
    reg [1:0]              ghost_awburst;
    reg                    ghost_awlock;
    reg [3:0]              ghost_awcache;
    reg [2:0]              ghost_awprot;

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            ghost_awvalid <= 1'b0;
            ghost_awid    <= '0;
            ghost_awaddr  <= '0;
            ghost_awlen   <= '0;
            ghost_awsize  <= '0;
            ghost_awburst <= '0;
            ghost_awlock  <= '0;
            ghost_awcache <= '0;
            ghost_awprot  <= '0;
        end else if (effective_decouple) begin
            if (dma_m_axi_awready) ghost_awvalid <= 1'b0;
        end else begin
            if (dma_s_axi_awvalid && !dma_m_axi_awready) begin
                ghost_awvalid <= 1'b1;
                ghost_awid    <= dma_s_axi_awid;
                ghost_awaddr  <= dma_s_axi_awaddr;
                ghost_awlen   <= dma_s_axi_awlen;
                ghost_awsize  <= dma_s_axi_awsize;
                ghost_awburst <= dma_s_axi_awburst;
                ghost_awlock  <= dma_s_axi_awlock;
                ghost_awcache <= dma_s_axi_awcache;
                ghost_awprot  <= dma_s_axi_awprot;
            end else begin
                ghost_awvalid <= 1'b0;
            end
        end
    end

    // --- AR Channel Ghost ---
    reg                    ghost_arvalid;
    reg [AXI_ID_WIDTH-1:0] ghost_arid;
    reg [31:0]             ghost_araddr;
    reg [7:0]              ghost_arlen;
    reg [2:0]              ghost_arsize;
    reg [1:0]              ghost_arburst;
    reg                    ghost_arlock;
    reg [3:0]              ghost_arcache;
    reg [2:0]              ghost_arprot;

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            ghost_arvalid <= 1'b0;
            ghost_arid    <= '0;
            ghost_araddr  <= '0;
            ghost_arlen   <= '0;
            ghost_arsize  <= '0;
            ghost_arburst <= '0;
            ghost_arlock  <= '0;
            ghost_arcache <= '0;
            ghost_arprot  <= '0;
        end else if (effective_decouple) begin
            if (dma_m_axi_arready) ghost_arvalid <= 1'b0;
        end else begin
            if (dma_s_axi_arvalid && !dma_m_axi_arready) begin
                ghost_arvalid <= 1'b1;
                ghost_arid    <= dma_s_axi_arid;
                ghost_araddr  <= dma_s_axi_araddr;
                ghost_arlen   <= dma_s_axi_arlen;
                ghost_arsize  <= dma_s_axi_arsize;
                ghost_arburst <= dma_s_axi_arburst;
                ghost_arlock  <= dma_s_axi_arlock;
                ghost_arcache <= dma_s_axi_arcache;
                ghost_arprot  <= dma_s_axi_arprot;
            end else begin
                ghost_arvalid <= 1'b0;
            end
        end
    end

    // --- W Channel Ghost ---
    reg                    ghost_wvalid;
    reg [31:0]             ghost_wdata;
    reg [3:0]              ghost_wstrb;
    reg                    ghost_wlast;

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            ghost_wvalid <= 1'b0;
            ghost_wdata  <= '0;
            ghost_wstrb  <= '0;
            ghost_wlast  <= '0;
        end else if (effective_decouple) begin
            if (dma_m_axi_wready) ghost_wvalid <= 1'b0;
        end else begin
            if (dma_s_axi_wvalid && !dma_m_axi_wready) begin
                ghost_wvalid <= 1'b1;
                ghost_wdata  <= dma_s_axi_wdata;
                ghost_wstrb  <= dma_s_axi_wstrb;
                ghost_wlast  <= dma_s_axi_wlast;
            end else begin
                ghost_wvalid <= 1'b0;
            end
        end
    end


    // ===================================================================
    // DMA FLUSHER & FABRIC FIREWALL
    // ===================================================================
    // Valid Muxing: Isolation registers preserve handshakes, otherwise raw input.
    assign dma_m_axi_awvalid = effective_decouple ? ghost_awvalid : dma_s_axi_awvalid;
    assign dma_m_axi_arvalid = effective_decouple ? ghost_arvalid : dma_s_axi_arvalid;
    
    // The W-Channel mixes the isolation register (for the orphaned beat) and the flusher
    assign dma_m_axi_wvalid  = effective_decouple ? (ghost_wvalid | (w_beats_owed > 0)) : dma_s_axi_wvalid;
    
    // B and R Responses are caught by the flusher
    assign dma_m_axi_bready  = effective_decouple ? (b_resp_owed > 0)   : dma_s_axi_bready;
    assign dma_m_axi_rready  = effective_decouple ? (r_bursts_owed > 0) : dma_s_axi_rready;

    // Payload Muxing: If decoupled, use ghost payloads to finish the transaction. 
    // Otherwise, raw wires.
    assign dma_m_axi_awaddr  = effective_decouple ? ghost_awaddr  : dma_s_axi_awaddr;
    assign dma_m_axi_awid    = effective_decouple ? ghost_awid    : dma_s_axi_awid;
    assign dma_m_axi_awlen   = effective_decouple ? ghost_awlen   : dma_s_axi_awlen;
    assign dma_m_axi_awsize  = effective_decouple ? ghost_awsize  : dma_s_axi_awsize;
    assign dma_m_axi_awburst = effective_decouple ? ghost_awburst : dma_s_axi_awburst;
    assign dma_m_axi_awlock  = effective_decouple ? ghost_awlock  : dma_s_axi_awlock;
    assign dma_m_axi_awcache = effective_decouple ? ghost_awcache : dma_s_axi_awcache;
    assign dma_m_axi_awprot  = effective_decouple ? ghost_awprot  : dma_s_axi_awprot;

    assign dma_m_axi_araddr  = effective_decouple ? ghost_araddr  : dma_s_axi_araddr;
    assign dma_m_axi_arid    = effective_decouple ? ghost_arid    : dma_s_axi_arid;
    assign dma_m_axi_arlen   = effective_decouple ? ghost_arlen   : dma_s_axi_arlen;
    assign dma_m_axi_arsize  = effective_decouple ? ghost_arsize  : dma_s_axi_arsize;
    assign dma_m_axi_arburst = effective_decouple ? ghost_arburst : dma_s_axi_arburst;
    assign dma_m_axi_arlock  = effective_decouple ? ghost_arlock  : dma_s_axi_arlock;
    assign dma_m_axi_arcache = effective_decouple ? ghost_arcache : dma_s_axi_arcache;
    assign dma_m_axi_arprot  = effective_decouple ? ghost_arprot  : dma_s_axi_arprot;

    assign dma_m_axi_wdata   = effective_decouple ? ghost_wdata   : dma_s_axi_wdata;
    assign dma_m_axi_wstrb   = effective_decouple ? ghost_wstrb   : dma_s_axi_wstrb;
    assign dma_m_axi_wlast   = effective_decouple ? (ghost_wvalid ? ghost_wlast : (w_beats_owed == 1)) : dma_s_axi_wlast;


    // ===================================================================
    // DMA FABRIC FIREWALL & STALL LOGIC
    // ===================================================================
    // Stall the Fabric (Forces new bitstreams to "wait at the gates")
    assign dma_s_axi_awready = effective_decouple ? 1'b0 : dma_m_axi_awready;
    assign dma_s_axi_arready = effective_decouple ? 1'b0 : dma_m_axi_arready;
    assign dma_s_axi_wready  = effective_decouple ? 1'b0 : dma_m_axi_wready;
    assign dma_s_axi_bvalid  = effective_decouple ? 1'b0 : dma_m_axi_bvalid;
    assign dma_s_axi_rvalid  = effective_decouple ? 1'b0 : dma_m_axi_rvalid;

    assign dma_s_axi_bid     = dma_m_axi_bid;
    assign dma_s_axi_bresp   = dma_m_axi_bresp;
    assign dma_s_axi_rid     = dma_m_axi_rid;
    assign dma_s_axi_rdata   = dma_m_axi_rdata;
    assign dma_s_axi_rresp   = dma_m_axi_rresp;
    assign dma_s_axi_rlast   = dma_m_axi_rlast;

endmodule