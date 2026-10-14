/* ==============================================================================
   Module: bridge_soc_to_fabric_slave
   Direction: SoC (AXI-Lite Manager) -> eFPGA Fabric (AXI-Lite or WB Slave)
============================================================================== */

module bridge_soc_to_fabric_slave (
    input  logic        clk,
    input  logic        resetn,
    input  logic        cfg_wb_enable,

    // SoC Side 
    input  logic [31:0] soc_awaddr,  input  logic [2:0]  soc_awprot,  input  logic        soc_awvalid, output logic        soc_awready,
    input  logic [31:0] soc_wdata,   input  logic [3:0]  soc_wstrb,   input  logic        soc_wvalid,  output logic        soc_wready,
    output logic [1:0]  soc_bresp,   output logic        soc_bvalid,  input  logic        soc_bready,
    input  logic [31:0] soc_araddr,  input  logic [2:0]  soc_arprot,  input  logic        soc_arvalid, output logic        soc_arready,
    output logic [31:0] soc_rdata,   output logic [1:0]  soc_rresp,   output logic        soc_rvalid,  input  logic        soc_rready,

    // Fabric Side 
    output logic [31:0] fab_awaddr,  output logic [2:0]  fab_awprot,  output logic        fab_awvalid, input  logic        fab_awready,
    output logic [31:0] fab_wdata,   output logic [3:0]  fab_wstrb,   output logic        fab_wvalid,  input  logic        fab_wready,
    input  logic [1:0]  fab_bresp,   input  logic        fab_bvalid,  output logic        fab_bready,
    output logic [31:0] fab_araddr,  output logic [2:0]  fab_arprot,  output logic        fab_arvalid, input  logic        fab_arready,
    input  logic [31:0] fab_rdata,   input  logic [1:0]  fab_rresp,   input  logic        fab_rvalid,  output logic        fab_rready
);

    typedef enum logic [1:0] {IDLE, WB_WRITE, WB_READ, RESP} state_t;
    state_t state;

    logic [31:0] wb_addr_reg, wb_data_reg, wb_rdata_reg;
    logic [3:0]  wb_sel_reg;
    logic        wb_we_reg, wb_err_reg;

    // Internal registers strictly for state machine tracking
    logic int_soc_awready, int_soc_wready, int_soc_arready;
    logic int_soc_bvalid,  int_soc_rvalid;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
            int_soc_awready <= 0; int_soc_wready <= 0; int_soc_arready <= 0;
            int_soc_bvalid  <= 0; int_soc_rvalid <= 0;
        end else begin
            // Pulse logic: Ready signals default to 0 every cycle.
            int_soc_awready <= 0; int_soc_wready <= 0; int_soc_arready <= 0;

            case (state)
                IDLE: begin
                    if (cfg_wb_enable) begin
                        if (soc_awvalid && soc_wvalid) begin
                            wb_addr_reg     <= soc_awaddr;
                            wb_data_reg     <= soc_wdata;
                            wb_sel_reg      <= soc_wstrb;
                            wb_we_reg       <= 1'b1;
                            int_soc_awready <= 1'b1;
                            int_soc_wready  <= 1'b1;
                            state           <= WB_WRITE;
                        end else if (soc_arvalid) begin
                            wb_addr_reg     <= soc_araddr;
                            wb_we_reg       <= 1'b0;
                            int_soc_arready <= 1'b1;
                            state           <= WB_READ;
                        end
                    end
                end

                WB_WRITE, WB_READ: begin
                    if (fab_awready) begin 
                        wb_rdata_reg <= fab_rdata;
                        wb_err_reg   <= fab_bresp[0]; 
                        state        <= RESP;
                    end
                end

                RESP: begin
                    if (wb_we_reg) begin
                        int_soc_bvalid <= 1'b1; // Hold BVALID until accepted
                        if (soc_bready && int_soc_bvalid) begin
                            int_soc_bvalid <= 1'b0;
                            state          <= IDLE;
                        end
                    end else begin
                        int_soc_rvalid <= 1'b1; // Hold RVALID until accepted
                        if (soc_rready && int_soc_rvalid) begin
                            int_soc_rvalid <= 1'b0;
                            state          <= IDLE;
                        end
                    end
                end

                default: ;
            endcase
        end
    end

    // --- Pure Single-Driver Output Multiplexing ---
    
    // To Fabric
    assign fab_awaddr  = cfg_wb_enable ? wb_addr_reg : soc_awaddr;
    assign fab_awprot  = cfg_wb_enable ? {2'b00, wb_we_reg} : soc_awprot;
    assign fab_awvalid = cfg_wb_enable ? (state == WB_WRITE || state == WB_READ) : soc_awvalid;
    
    assign fab_wdata   = cfg_wb_enable ? wb_data_reg : soc_wdata;
    assign fab_wstrb   = cfg_wb_enable ? wb_sel_reg  : soc_wstrb;
    assign fab_wvalid  = cfg_wb_enable ? (state == WB_WRITE || state == WB_READ) : soc_wvalid;
    
    assign fab_araddr  = cfg_wb_enable ? wb_addr_reg : soc_araddr; // Route address on Wishbone read cycles
    assign fab_arprot  = cfg_wb_enable ? 3'b000      : soc_arprot;
    assign fab_arvalid = cfg_wb_enable ? 1'b0        : soc_arvalid;
    
    assign fab_bready  = cfg_wb_enable ? 1'b0        : soc_bready;
    assign fab_rready  = cfg_wb_enable ? 1'b0        : soc_rready;

    // To SoC
    assign soc_awready = cfg_wb_enable ? int_soc_awready : fab_awready;
    assign soc_wready  = cfg_wb_enable ? int_soc_wready  : fab_wready;
    assign soc_arready = cfg_wb_enable ? int_soc_arready : fab_arready;
    
    assign soc_bvalid  = cfg_wb_enable ? int_soc_bvalid  : fab_bvalid;
    assign soc_rvalid  = cfg_wb_enable ? int_soc_rvalid  : fab_rvalid;
    
    // AXI Errors: Map WB ERR to AXI SLVERR (2'b10)
    assign soc_bresp   = cfg_wb_enable ? {wb_err_reg, 1'b0} : fab_bresp;
    assign soc_rresp   = cfg_wb_enable ? {wb_err_reg, 1'b0} : fab_rresp;
    assign soc_rdata   = cfg_wb_enable ? wb_rdata_reg       : fab_rdata;

endmodule