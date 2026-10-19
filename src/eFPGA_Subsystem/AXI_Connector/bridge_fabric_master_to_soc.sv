/* ==============================================================================
   Module: bridge_fabric_master_to_soc
   Direction: eFPGA Fabric (AXI-Full or WB Master) -> SoC (AXI-Full DMA)
============================================================================== */

module bridge_fabric_master_to_soc #(
    parameter int AXI_ID_WIDTH = 8
)(
    input  logic        clk,
    input  logic        resetn,
    input  logic        cfg_wb_enable, 

    // Fabric Side 
    input  logic [AXI_ID_WIDTH-1:0] fab_awid,    input  logic [31:0] fab_awaddr,  input  logic [7:0]  fab_awlen,    input  logic [2:0]  fab_awsize,
    input  logic [1:0]  fab_awburst,             input  logic        fab_awlock,  input  logic [3:0]  fab_awcache,  input  logic [2:0]  fab_awprot,
    input  logic        fab_awvalid,             output logic        fab_awready, input  logic [31:0] fab_wdata,    input  logic [3:0]  fab_wstrb,
    input  logic        fab_wlast,               input  logic        fab_wvalid,  output logic        fab_wready,   output logic [AXI_ID_WIDTH-1:0] fab_bid,
    output logic [1:0]  fab_bresp,               output logic        fab_bvalid,  input  logic        fab_bready,   input  logic [AXI_ID_WIDTH-1:0] fab_arid,
    input  logic [31:0] fab_araddr,              input  logic [7:0]  fab_arlen,   input  logic [2:0]  fab_arsize,   input  logic [1:0]  fab_arburst,
    input  logic        fab_arlock,              input  logic [3:0]  fab_arcache, input  logic [2:0]  fab_arprot,   input  logic        fab_arvalid,
    output logic        fab_arready,             output logic [AXI_ID_WIDTH-1:0] fab_rid, output logic [31:0] fab_rdata,  output logic [1:0]  fab_rresp,
    output logic        fab_rlast,               output logic        fab_rvalid,  input  logic        fab_rready,

    // SoC Side 
    output logic [AXI_ID_WIDTH-1:0] soc_awid,    output logic [31:0] soc_awaddr,  output logic [7:0]  soc_awlen,    output logic [2:0]  soc_awsize,
    output logic [1:0]  soc_awburst,             output logic        soc_awlock,  output logic [3:0]  soc_awcache,  output logic [2:0]  soc_awprot,
    output logic        soc_awvalid,             input  logic        soc_awready, output logic [31:0] soc_wdata,    output logic [3:0]  soc_wstrb,
    output logic        soc_wlast,               output logic        soc_wvalid,  input  logic        soc_wready,   input  logic [AXI_ID_WIDTH-1:0] soc_bid,
    input  logic [1:0]  soc_bresp,               input  logic        soc_bvalid,  output logic        soc_bready,   output logic [AXI_ID_WIDTH-1:0] soc_arid,
    output logic [31:0] soc_araddr,              output logic [7:0]  soc_arlen,   output logic [2:0]  soc_arsize,   output logic [1:0]  soc_arburst,
    output logic        soc_arlock,              output logic [3:0]  soc_arcache, output logic [2:0]  soc_arprot,   output logic        soc_arvalid,
    input  logic        soc_arready,             input  logic [AXI_ID_WIDTH-1:0] soc_rid, input  logic [31:0] soc_rdata,  input  logic [1:0]  soc_rresp,
    input  logic        soc_rlast,               input  logic        soc_rvalid,  output logic        soc_rready
);

    typedef enum logic [1:0] {IDLE, AXI_WRITE, AXI_READ} m_state_t;
    m_state_t m_state;

    logic aw_done, w_done;
    logic wb_stall, wb_ack, incoming_req;

    logic [31:0] int_soc_awaddr, int_soc_wdata, int_soc_araddr;
    logic [3:0]  int_soc_wstrb;
    logic        int_soc_awvalid, int_soc_wvalid, int_soc_arvalid;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            m_state         <= IDLE;
            int_soc_awvalid <= 0; int_soc_wvalid <= 0; int_soc_arvalid <= 0;
            aw_done         <= 0; w_done         <= 0;
            wb_ack          <= 0;
        end else begin
            wb_ack <= 0; // Default 1-cycle ACK pulse

            case (m_state)
                IDLE: begin
                    aw_done <= 0; w_done <= 0;

                    if (cfg_wb_enable && fab_awvalid && fab_wvalid) begin
                        if (fab_awlock) begin // WE=1
                            int_soc_awaddr  <= fab_awaddr;
                            int_soc_wdata   <= fab_wdata;
                            int_soc_wstrb   <= fab_wstrb;
                            int_soc_awvalid <= 1'b1;
                            int_soc_wvalid  <= 1'b1;
                            m_state         <= AXI_WRITE;
                        end else begin // WE=0
                            int_soc_araddr  <= fab_awaddr;
                            int_soc_arvalid <= 1'b1;
                            m_state         <= AXI_READ;
                        end
                    end
                end

                AXI_WRITE: begin
                    if (soc_awready) begin int_soc_awvalid <= 1'b0; aw_done <= 1'b1; end
                    if (soc_wready)  begin int_soc_wvalid  <= 1'b0; w_done  <= 1'b1; end
                    
                    if ((soc_awready || aw_done) && (soc_wready || w_done)) begin
                        // AXI Spec requires BREADY defaults to High for fast turnaround.
                        if (soc_bvalid) begin
                            wb_ack  <= 1'b1;
                            m_state <= IDLE;
                        end
                    end
                end

                AXI_READ: begin
                    if (soc_arready) int_soc_arvalid <= 1'b0;
                    
                    // RREADY defaults to High for fast turnaround.
                    if (soc_rvalid) begin
                        wb_ack  <= 1'b1;
                        m_state <= IDLE;
                    end
                end

                default: ;
            endcase
        end
    end

    // --- Pure Single-Driver Output Multiplexing ---

    assign incoming_req = cfg_wb_enable && fab_awvalid && fab_wvalid;
    assign wb_stall     = (m_state != IDLE) || incoming_req;

    // Straight Passthroughs (IDs and payload flow continuously)
    assign soc_awid  = fab_awid;   assign soc_arid  = fab_arid;
    assign fab_bid   = soc_bid;    assign fab_rid   = soc_rid;
    assign fab_rdata = soc_rdata;  assign fab_rlast = soc_rlast;

    // To SoC
    assign soc_awaddr  = cfg_wb_enable ? int_soc_awaddr  : fab_awaddr;
    assign soc_awlen   = cfg_wb_enable ? 8'h00           : fab_awlen;
    assign soc_awsize  = cfg_wb_enable ? 3'b010          : fab_awsize; 
    assign soc_awburst = cfg_wb_enable ? 2'b01           : fab_awburst;
    assign soc_awlock  = cfg_wb_enable ? 1'b0            : fab_awlock;
    assign soc_awcache = cfg_wb_enable ? 4'b0011         : fab_awcache;
    assign soc_awprot  = cfg_wb_enable ? 3'b000          : fab_awprot;
    assign soc_awvalid = cfg_wb_enable ? int_soc_awvalid : fab_awvalid;

    assign soc_wdata   = cfg_wb_enable ? int_soc_wdata   : fab_wdata;
    assign soc_wstrb   = cfg_wb_enable ? int_soc_wstrb   : fab_wstrb;
    assign soc_wlast   = cfg_wb_enable ? 1'b1            : fab_wlast; 
    assign soc_wvalid  = cfg_wb_enable ? int_soc_wvalid  : fab_wvalid;
    
    assign soc_bready  = cfg_wb_enable ? 1'b1            : fab_bready; // Prevent deadlock!

    assign soc_araddr  = cfg_wb_enable ? int_soc_araddr  : fab_araddr;
    assign soc_arlen   = cfg_wb_enable ? 8'h00           : fab_arlen;
    assign soc_arsize  = cfg_wb_enable ? 3'b010          : fab_arsize;
    assign soc_arburst = cfg_wb_enable ? 2'b01           : fab_arburst;
    assign soc_arlock  = cfg_wb_enable ? 1'b0            : fab_arlock;
    assign soc_arcache = cfg_wb_enable ? 4'b0011         : fab_arcache;
    assign soc_arprot  = cfg_wb_enable ? 3'b000          : fab_arprot;
    assign soc_arvalid = cfg_wb_enable ? int_soc_arvalid : fab_arvalid;
    
    assign soc_rready  = cfg_wb_enable ? 1'b1            : fab_rready; // Prevent deadlock!

    // To Fabric
    assign fab_awready = cfg_wb_enable ? wb_ack   : soc_awready;
    assign fab_wready  = cfg_wb_enable ? wb_stall : soc_wready; 
    assign fab_arready = cfg_wb_enable ? 1'b0     : soc_arready;
    assign fab_bvalid  = cfg_wb_enable ? 1'b0     : soc_bvalid;
    assign fab_rvalid  = cfg_wb_enable ? 1'b0     : soc_rvalid;
    
    // AXI Errors: If bit [1] is high (SLVERR/DECERR), flag the WB ERR bit
    assign fab_bresp   = cfg_wb_enable ? {1'b0, soc_bresp[1]} : soc_bresp;
    assign fab_rresp   = cfg_wb_enable ? {1'b0, soc_rresp[1]} : soc_rresp;

endmodule