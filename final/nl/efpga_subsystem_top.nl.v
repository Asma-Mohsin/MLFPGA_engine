module efpga_subsystem_top (clk_i,
    efpga_cfg_sclk_i,
    efpga_cfg_sdata_i,
    efpga_fault_irq_o,
    m_axi_dma_arlock,
    m_axi_dma_arready,
    m_axi_dma_arvalid,
    m_axi_dma_awlock,
    m_axi_dma_awready,
    m_axi_dma_awvalid,
    m_axi_dma_bready,
    m_axi_dma_bvalid,
    m_axi_dma_rlast,
    m_axi_dma_rready,
    m_axi_dma_rvalid,
    m_axi_dma_wlast,
    m_axi_dma_wready,
    m_axi_dma_wvalid,
    rst_efpga_connector_i,
    rst_efpga_connector_n_i,
    rst_efpga_fabric_n_i,
    rst_efpga_npu_n_i,
    s_axil_ctrl_arready,
    s_axil_ctrl_arvalid,
    s_axil_ctrl_awready,
    s_axil_ctrl_awvalid,
    s_axil_ctrl_bready,
    s_axil_ctrl_bvalid,
    s_axil_ctrl_rready,
    s_axil_ctrl_rvalid,
    s_axil_ctrl_wready,
    s_axil_ctrl_wvalid,
    s_axil_mgr_arready,
    s_axil_mgr_arvalid,
    s_axil_mgr_awready,
    s_axil_mgr_awvalid,
    s_axil_mgr_bready,
    s_axil_mgr_bvalid,
    s_axil_mgr_rready,
    s_axil_mgr_rvalid,
    s_axil_mgr_wready,
    s_axil_mgr_wvalid,
    efpga_usr_irq_o,
    m_axi_dma_araddr,
    m_axi_dma_arburst,
    m_axi_dma_arcache,
    m_axi_dma_arid,
    m_axi_dma_arlen,
    m_axi_dma_arprot,
    m_axi_dma_arsize,
    m_axi_dma_awaddr,
    m_axi_dma_awburst,
    m_axi_dma_awcache,
    m_axi_dma_awid,
    m_axi_dma_awlen,
    m_axi_dma_awprot,
    m_axi_dma_awsize,
    m_axi_dma_bid,
    m_axi_dma_bresp,
    m_axi_dma_rdata,
    m_axi_dma_rid,
    m_axi_dma_rresp,
    m_axi_dma_wdata,
    m_axi_dma_wstrb,
    pmod_io_i,
    pmod_io_o,
    pmod_io_oe_o,
    rst_efpga_slot_n_i,
    s_axil_ctrl_araddr,
    s_axil_ctrl_arprot,
    s_axil_ctrl_awaddr,
    s_axil_ctrl_awprot,
    s_axil_ctrl_bresp,
    s_axil_ctrl_rdata,
    s_axil_ctrl_rresp,
    s_axil_ctrl_wdata,
    s_axil_ctrl_wstrb,
    s_axil_mgr_araddr,
    s_axil_mgr_arprot,
    s_axil_mgr_awaddr,
    s_axil_mgr_awprot,
    s_axil_mgr_bresp,
    s_axil_mgr_rdata,
    s_axil_mgr_rresp,
    s_axil_mgr_wdata,
    s_axil_mgr_wstrb,
    VDD,
    VSS);
 input clk_i;
 input efpga_cfg_sclk_i;
 input efpga_cfg_sdata_i;
 output efpga_fault_irq_o;
 output m_axi_dma_arlock;
 input m_axi_dma_arready;
 output m_axi_dma_arvalid;
 output m_axi_dma_awlock;
 input m_axi_dma_awready;
 output m_axi_dma_awvalid;
 output m_axi_dma_bready;
 input m_axi_dma_bvalid;
 input m_axi_dma_rlast;
 output m_axi_dma_rready;
 input m_axi_dma_rvalid;
 output m_axi_dma_wlast;
 input m_axi_dma_wready;
 output m_axi_dma_wvalid;
 input rst_efpga_connector_i;
 input rst_efpga_connector_n_i;
 input rst_efpga_fabric_n_i;
 input rst_efpga_npu_n_i;
 output s_axil_ctrl_arready;
 input s_axil_ctrl_arvalid;
 output s_axil_ctrl_awready;
 input s_axil_ctrl_awvalid;
 input s_axil_ctrl_bready;
 output s_axil_ctrl_bvalid;
 input s_axil_ctrl_rready;
 output s_axil_ctrl_rvalid;
 output s_axil_ctrl_wready;
 input s_axil_ctrl_wvalid;
 output s_axil_mgr_arready;
 input s_axil_mgr_arvalid;
 output s_axil_mgr_awready;
 input s_axil_mgr_awvalid;
 input s_axil_mgr_bready;
 output s_axil_mgr_bvalid;
 input s_axil_mgr_rready;
 output s_axil_mgr_rvalid;
 output s_axil_mgr_wready;
 input s_axil_mgr_wvalid;
 output [3:0] efpga_usr_irq_o;
 output [31:0] m_axi_dma_araddr;
 output [1:0] m_axi_dma_arburst;
 output [3:0] m_axi_dma_arcache;
 output [7:0] m_axi_dma_arid;
 output [7:0] m_axi_dma_arlen;
 output [2:0] m_axi_dma_arprot;
 output [2:0] m_axi_dma_arsize;
 output [31:0] m_axi_dma_awaddr;
 output [1:0] m_axi_dma_awburst;
 output [3:0] m_axi_dma_awcache;
 output [7:0] m_axi_dma_awid;
 output [7:0] m_axi_dma_awlen;
 output [2:0] m_axi_dma_awprot;
 output [2:0] m_axi_dma_awsize;
 input [7:0] m_axi_dma_bid;
 input [1:0] m_axi_dma_bresp;
 input [31:0] m_axi_dma_rdata;
 input [7:0] m_axi_dma_rid;
 input [1:0] m_axi_dma_rresp;
 output [31:0] m_axi_dma_wdata;
 output [3:0] m_axi_dma_wstrb;
 input [7:0] pmod_io_i;
 output [7:0] pmod_io_o;
 output [7:0] pmod_io_oe_o;
 input [3:0] rst_efpga_slot_n_i;
 input [31:0] s_axil_ctrl_araddr;
 input [2:0] s_axil_ctrl_arprot;
 input [31:0] s_axil_ctrl_awaddr;
 input [2:0] s_axil_ctrl_awprot;
 output [1:0] s_axil_ctrl_bresp;
 output [31:0] s_axil_ctrl_rdata;
 output [1:0] s_axil_ctrl_rresp;
 input [31:0] s_axil_ctrl_wdata;
 input [3:0] s_axil_ctrl_wstrb;
 input [31:0] s_axil_mgr_araddr;
 input [2:0] s_axil_mgr_arprot;
 input [31:0] s_axil_mgr_awaddr;
 input [2:0] s_axil_mgr_awprot;
 output [1:0] s_axil_mgr_bresp;
 output [31:0] s_axil_mgr_rdata;
 output [1:0] s_axil_mgr_rresp;
 input [31:0] s_axil_mgr_wdata;
 input [3:0] s_axil_mgr_wstrb;
 inout VDD;
 inout VSS;


 sg13cmos5l_tielo _000_ (.L_LO(efpga_fault_irq_o));
 sg13cmos5l_tielo _001_ (.L_LO(efpga_usr_irq_o[0]));
 sg13cmos5l_tielo _002_ (.L_LO(efpga_usr_irq_o[1]));
 sg13cmos5l_tielo _003_ (.L_LO(efpga_usr_irq_o[2]));
 sg13cmos5l_tielo _004_ (.L_LO(efpga_usr_irq_o[3]));
 sg13cmos5l_tielo _005_ (.L_LO(m_axi_dma_araddr[0]));
 sg13cmos5l_tielo _006_ (.L_LO(m_axi_dma_araddr[1]));
 sg13cmos5l_tielo _007_ (.L_LO(m_axi_dma_araddr[2]));
 sg13cmos5l_tielo _008_ (.L_LO(m_axi_dma_araddr[3]));
 sg13cmos5l_tielo _009_ (.L_LO(m_axi_dma_araddr[4]));
 sg13cmos5l_tielo _010_ (.L_LO(m_axi_dma_araddr[5]));
 sg13cmos5l_tielo _011_ (.L_LO(m_axi_dma_araddr[6]));
 sg13cmos5l_tielo _012_ (.L_LO(m_axi_dma_araddr[7]));
 sg13cmos5l_tielo _013_ (.L_LO(m_axi_dma_araddr[8]));
 sg13cmos5l_tielo _014_ (.L_LO(m_axi_dma_araddr[9]));
 sg13cmos5l_tielo _015_ (.L_LO(m_axi_dma_araddr[10]));
 sg13cmos5l_tielo _016_ (.L_LO(m_axi_dma_araddr[11]));
 sg13cmos5l_tielo _017_ (.L_LO(m_axi_dma_araddr[12]));
 sg13cmos5l_tielo _018_ (.L_LO(m_axi_dma_araddr[13]));
 sg13cmos5l_tielo _019_ (.L_LO(m_axi_dma_araddr[14]));
 sg13cmos5l_tielo _020_ (.L_LO(m_axi_dma_araddr[15]));
 sg13cmos5l_tielo _021_ (.L_LO(m_axi_dma_araddr[16]));
 sg13cmos5l_tielo _022_ (.L_LO(m_axi_dma_araddr[17]));
 sg13cmos5l_tielo _023_ (.L_LO(m_axi_dma_araddr[18]));
 sg13cmos5l_tielo _024_ (.L_LO(m_axi_dma_araddr[19]));
 sg13cmos5l_tielo _025_ (.L_LO(m_axi_dma_araddr[20]));
 sg13cmos5l_tielo _026_ (.L_LO(m_axi_dma_araddr[21]));
 sg13cmos5l_tielo _027_ (.L_LO(m_axi_dma_araddr[22]));
 sg13cmos5l_tielo _028_ (.L_LO(m_axi_dma_araddr[23]));
 sg13cmos5l_tielo _029_ (.L_LO(m_axi_dma_araddr[24]));
 sg13cmos5l_tielo _030_ (.L_LO(m_axi_dma_araddr[25]));
 sg13cmos5l_tielo _031_ (.L_LO(m_axi_dma_araddr[26]));
 sg13cmos5l_tielo _032_ (.L_LO(m_axi_dma_araddr[27]));
 sg13cmos5l_tielo _033_ (.L_LO(m_axi_dma_araddr[28]));
 sg13cmos5l_tielo _034_ (.L_LO(m_axi_dma_araddr[29]));
 sg13cmos5l_tielo _035_ (.L_LO(m_axi_dma_araddr[30]));
 sg13cmos5l_tielo _036_ (.L_LO(m_axi_dma_araddr[31]));
 sg13cmos5l_tielo _037_ (.L_LO(m_axi_dma_arburst[0]));
 sg13cmos5l_tielo _038_ (.L_LO(m_axi_dma_arburst[1]));
 sg13cmos5l_tielo _039_ (.L_LO(m_axi_dma_arcache[0]));
 sg13cmos5l_tielo _040_ (.L_LO(m_axi_dma_arcache[1]));
 sg13cmos5l_tielo _041_ (.L_LO(m_axi_dma_arcache[2]));
 sg13cmos5l_tielo _042_ (.L_LO(m_axi_dma_arcache[3]));
 sg13cmos5l_tielo _043_ (.L_LO(m_axi_dma_arid[0]));
 sg13cmos5l_tielo _044_ (.L_LO(m_axi_dma_arid[1]));
 sg13cmos5l_tielo _045_ (.L_LO(m_axi_dma_arid[2]));
 sg13cmos5l_tielo _046_ (.L_LO(m_axi_dma_arid[3]));
 sg13cmos5l_tielo _047_ (.L_LO(m_axi_dma_arid[4]));
 sg13cmos5l_tielo _048_ (.L_LO(m_axi_dma_arid[5]));
 sg13cmos5l_tielo _049_ (.L_LO(m_axi_dma_arid[6]));
 sg13cmos5l_tielo _050_ (.L_LO(m_axi_dma_arid[7]));
 sg13cmos5l_tielo _051_ (.L_LO(m_axi_dma_arlen[0]));
 sg13cmos5l_tielo _052_ (.L_LO(m_axi_dma_arlen[1]));
 sg13cmos5l_tielo _053_ (.L_LO(m_axi_dma_arlen[2]));
 sg13cmos5l_tielo _054_ (.L_LO(m_axi_dma_arlen[3]));
 sg13cmos5l_tielo _055_ (.L_LO(m_axi_dma_arlen[4]));
 sg13cmos5l_tielo _056_ (.L_LO(m_axi_dma_arlen[5]));
 sg13cmos5l_tielo _057_ (.L_LO(m_axi_dma_arlen[6]));
 sg13cmos5l_tielo _058_ (.L_LO(m_axi_dma_arlen[7]));
 sg13cmos5l_tielo _059_ (.L_LO(m_axi_dma_arlock));
 sg13cmos5l_tielo _060_ (.L_LO(m_axi_dma_arprot[0]));
 sg13cmos5l_tielo _061_ (.L_LO(m_axi_dma_arprot[1]));
 sg13cmos5l_tielo _062_ (.L_LO(m_axi_dma_arprot[2]));
 sg13cmos5l_tielo _063_ (.L_LO(m_axi_dma_arsize[0]));
 sg13cmos5l_tielo _064_ (.L_LO(m_axi_dma_arsize[1]));
 sg13cmos5l_tielo _065_ (.L_LO(m_axi_dma_arsize[2]));
 sg13cmos5l_tielo _066_ (.L_LO(m_axi_dma_arvalid));
 sg13cmos5l_tielo _067_ (.L_LO(m_axi_dma_awaddr[0]));
 sg13cmos5l_tielo _068_ (.L_LO(m_axi_dma_awaddr[1]));
 sg13cmos5l_tielo _069_ (.L_LO(m_axi_dma_awaddr[2]));
 sg13cmos5l_tielo _070_ (.L_LO(m_axi_dma_awaddr[3]));
 sg13cmos5l_tielo _071_ (.L_LO(m_axi_dma_awaddr[4]));
 sg13cmos5l_tielo _072_ (.L_LO(m_axi_dma_awaddr[5]));
 sg13cmos5l_tielo _073_ (.L_LO(m_axi_dma_awaddr[6]));
 sg13cmos5l_tielo _074_ (.L_LO(m_axi_dma_awaddr[7]));
 sg13cmos5l_tielo _075_ (.L_LO(m_axi_dma_awaddr[8]));
 sg13cmos5l_tielo _076_ (.L_LO(m_axi_dma_awaddr[9]));
 sg13cmos5l_tielo _077_ (.L_LO(m_axi_dma_awaddr[10]));
 sg13cmos5l_tielo _078_ (.L_LO(m_axi_dma_awaddr[11]));
 sg13cmos5l_tielo _079_ (.L_LO(m_axi_dma_awaddr[12]));
 sg13cmos5l_tielo _080_ (.L_LO(m_axi_dma_awaddr[13]));
 sg13cmos5l_tielo _081_ (.L_LO(m_axi_dma_awaddr[14]));
 sg13cmos5l_tielo _082_ (.L_LO(m_axi_dma_awaddr[15]));
 sg13cmos5l_tielo _083_ (.L_LO(m_axi_dma_awaddr[16]));
 sg13cmos5l_tielo _084_ (.L_LO(m_axi_dma_awaddr[17]));
 sg13cmos5l_tielo _085_ (.L_LO(m_axi_dma_awaddr[18]));
 sg13cmos5l_tielo _086_ (.L_LO(m_axi_dma_awaddr[19]));
 sg13cmos5l_tielo _087_ (.L_LO(m_axi_dma_awaddr[20]));
 sg13cmos5l_tielo _088_ (.L_LO(m_axi_dma_awaddr[21]));
 sg13cmos5l_tielo _089_ (.L_LO(m_axi_dma_awaddr[22]));
 sg13cmos5l_tielo _090_ (.L_LO(m_axi_dma_awaddr[23]));
 sg13cmos5l_tielo _091_ (.L_LO(m_axi_dma_awaddr[24]));
 sg13cmos5l_tielo _092_ (.L_LO(m_axi_dma_awaddr[25]));
 sg13cmos5l_tielo _093_ (.L_LO(m_axi_dma_awaddr[26]));
 sg13cmos5l_tielo _094_ (.L_LO(m_axi_dma_awaddr[27]));
 sg13cmos5l_tielo _095_ (.L_LO(m_axi_dma_awaddr[28]));
 sg13cmos5l_tielo _096_ (.L_LO(m_axi_dma_awaddr[29]));
 sg13cmos5l_tielo _097_ (.L_LO(m_axi_dma_awaddr[30]));
 sg13cmos5l_tielo _098_ (.L_LO(m_axi_dma_awaddr[31]));
 sg13cmos5l_tielo _099_ (.L_LO(m_axi_dma_awburst[0]));
 sg13cmos5l_tielo _100_ (.L_LO(m_axi_dma_awburst[1]));
 sg13cmos5l_tielo _101_ (.L_LO(m_axi_dma_awcache[0]));
 sg13cmos5l_tielo _102_ (.L_LO(m_axi_dma_awcache[1]));
 sg13cmos5l_tielo _103_ (.L_LO(m_axi_dma_awcache[2]));
 sg13cmos5l_tielo _104_ (.L_LO(m_axi_dma_awcache[3]));
 sg13cmos5l_tielo _105_ (.L_LO(m_axi_dma_awid[0]));
 sg13cmos5l_tielo _106_ (.L_LO(m_axi_dma_awid[1]));
 sg13cmos5l_tielo _107_ (.L_LO(m_axi_dma_awid[2]));
 sg13cmos5l_tielo _108_ (.L_LO(m_axi_dma_awid[3]));
 sg13cmos5l_tielo _109_ (.L_LO(m_axi_dma_awid[4]));
 sg13cmos5l_tielo _110_ (.L_LO(m_axi_dma_awid[5]));
 sg13cmos5l_tielo _111_ (.L_LO(m_axi_dma_awid[6]));
 sg13cmos5l_tielo _112_ (.L_LO(m_axi_dma_awid[7]));
 sg13cmos5l_tielo _113_ (.L_LO(m_axi_dma_awlen[0]));
 sg13cmos5l_tielo _114_ (.L_LO(m_axi_dma_awlen[1]));
 sg13cmos5l_tielo _115_ (.L_LO(m_axi_dma_awlen[2]));
 sg13cmos5l_tielo _116_ (.L_LO(m_axi_dma_awlen[3]));
 sg13cmos5l_tielo _117_ (.L_LO(m_axi_dma_awlen[4]));
 sg13cmos5l_tielo _118_ (.L_LO(m_axi_dma_awlen[5]));
 sg13cmos5l_tielo _119_ (.L_LO(m_axi_dma_awlen[6]));
 sg13cmos5l_tielo _120_ (.L_LO(m_axi_dma_awlen[7]));
 sg13cmos5l_tielo _121_ (.L_LO(m_axi_dma_awlock));
 sg13cmos5l_tielo _122_ (.L_LO(m_axi_dma_awprot[0]));
 sg13cmos5l_tielo _123_ (.L_LO(m_axi_dma_awprot[1]));
 sg13cmos5l_tielo _124_ (.L_LO(m_axi_dma_awprot[2]));
 sg13cmos5l_tielo _125_ (.L_LO(m_axi_dma_awsize[0]));
 sg13cmos5l_tielo _126_ (.L_LO(m_axi_dma_awsize[1]));
 sg13cmos5l_tielo _127_ (.L_LO(m_axi_dma_awsize[2]));
 sg13cmos5l_tielo _128_ (.L_LO(m_axi_dma_awvalid));
 sg13cmos5l_tielo _129_ (.L_LO(m_axi_dma_bready));
 sg13cmos5l_tielo _130_ (.L_LO(m_axi_dma_rready));
 sg13cmos5l_tielo _131_ (.L_LO(m_axi_dma_wdata[0]));
 sg13cmos5l_tielo _132_ (.L_LO(m_axi_dma_wdata[1]));
 sg13cmos5l_tielo _133_ (.L_LO(m_axi_dma_wdata[2]));
 sg13cmos5l_tielo _134_ (.L_LO(m_axi_dma_wdata[3]));
 sg13cmos5l_tielo _135_ (.L_LO(m_axi_dma_wdata[4]));
 sg13cmos5l_tielo _136_ (.L_LO(m_axi_dma_wdata[5]));
 sg13cmos5l_tielo _137_ (.L_LO(m_axi_dma_wdata[6]));
 sg13cmos5l_tielo _138_ (.L_LO(m_axi_dma_wdata[7]));
 sg13cmos5l_tielo _139_ (.L_LO(m_axi_dma_wdata[8]));
 sg13cmos5l_tielo _140_ (.L_LO(m_axi_dma_wdata[9]));
 sg13cmos5l_tielo _141_ (.L_LO(m_axi_dma_wdata[10]));
 sg13cmos5l_tielo _142_ (.L_LO(m_axi_dma_wdata[11]));
 sg13cmos5l_tielo _143_ (.L_LO(m_axi_dma_wdata[12]));
 sg13cmos5l_tielo _144_ (.L_LO(m_axi_dma_wdata[13]));
 sg13cmos5l_tielo _145_ (.L_LO(m_axi_dma_wdata[14]));
 sg13cmos5l_tielo _146_ (.L_LO(m_axi_dma_wdata[15]));
 sg13cmos5l_tielo _147_ (.L_LO(m_axi_dma_wdata[16]));
 sg13cmos5l_tielo _148_ (.L_LO(m_axi_dma_wdata[17]));
 sg13cmos5l_tielo _149_ (.L_LO(m_axi_dma_wdata[18]));
 sg13cmos5l_tielo _150_ (.L_LO(m_axi_dma_wdata[19]));
 sg13cmos5l_tielo _151_ (.L_LO(m_axi_dma_wdata[20]));
 sg13cmos5l_tielo _152_ (.L_LO(m_axi_dma_wdata[21]));
 sg13cmos5l_tielo _153_ (.L_LO(m_axi_dma_wdata[22]));
 sg13cmos5l_tielo _154_ (.L_LO(m_axi_dma_wdata[23]));
 sg13cmos5l_tielo _155_ (.L_LO(m_axi_dma_wdata[24]));
 sg13cmos5l_tielo _156_ (.L_LO(m_axi_dma_wdata[25]));
 sg13cmos5l_tielo _157_ (.L_LO(m_axi_dma_wdata[26]));
 sg13cmos5l_tielo _158_ (.L_LO(m_axi_dma_wdata[27]));
 sg13cmos5l_tielo _159_ (.L_LO(m_axi_dma_wdata[28]));
 sg13cmos5l_tielo _160_ (.L_LO(m_axi_dma_wdata[29]));
 sg13cmos5l_tielo _161_ (.L_LO(m_axi_dma_wdata[30]));
 sg13cmos5l_tielo _162_ (.L_LO(m_axi_dma_wdata[31]));
 sg13cmos5l_tielo _163_ (.L_LO(m_axi_dma_wlast));
 sg13cmos5l_tielo _164_ (.L_LO(m_axi_dma_wstrb[0]));
 sg13cmos5l_tielo _165_ (.L_LO(m_axi_dma_wstrb[1]));
 sg13cmos5l_tielo _166_ (.L_LO(m_axi_dma_wstrb[2]));
 sg13cmos5l_tielo _167_ (.L_LO(m_axi_dma_wstrb[3]));
 sg13cmos5l_tielo _168_ (.L_LO(m_axi_dma_wvalid));
 sg13cmos5l_tielo _169_ (.L_LO(pmod_io_o[0]));
 sg13cmos5l_tielo _170_ (.L_LO(pmod_io_o[1]));
 sg13cmos5l_tielo _171_ (.L_LO(pmod_io_o[2]));
 sg13cmos5l_tielo _172_ (.L_LO(pmod_io_o[3]));
 sg13cmos5l_tielo _173_ (.L_LO(pmod_io_o[4]));
 sg13cmos5l_tielo _174_ (.L_LO(pmod_io_o[5]));
 sg13cmos5l_tielo _175_ (.L_LO(pmod_io_o[6]));
 sg13cmos5l_tielo _176_ (.L_LO(pmod_io_o[7]));
 sg13cmos5l_tielo _177_ (.L_LO(pmod_io_oe_o[0]));
 sg13cmos5l_tielo _178_ (.L_LO(pmod_io_oe_o[1]));
 sg13cmos5l_tielo _179_ (.L_LO(pmod_io_oe_o[2]));
 sg13cmos5l_tielo _180_ (.L_LO(pmod_io_oe_o[3]));
 sg13cmos5l_tielo _181_ (.L_LO(pmod_io_oe_o[4]));
 sg13cmos5l_tielo _182_ (.L_LO(pmod_io_oe_o[5]));
 sg13cmos5l_tielo _183_ (.L_LO(pmod_io_oe_o[6]));
 sg13cmos5l_tielo _184_ (.L_LO(pmod_io_oe_o[7]));
 sg13cmos5l_tielo _185_ (.L_LO(s_axil_ctrl_arready));
 sg13cmos5l_tielo _186_ (.L_LO(s_axil_ctrl_awready));
 sg13cmos5l_tielo _187_ (.L_LO(s_axil_ctrl_bresp[0]));
 sg13cmos5l_tielo _188_ (.L_LO(s_axil_ctrl_bresp[1]));
 sg13cmos5l_tielo _189_ (.L_LO(s_axil_ctrl_bvalid));
 sg13cmos5l_tielo _190_ (.L_LO(s_axil_ctrl_rdata[0]));
 sg13cmos5l_tielo _191_ (.L_LO(s_axil_ctrl_rdata[1]));
 sg13cmos5l_tielo _192_ (.L_LO(s_axil_ctrl_rdata[2]));
 sg13cmos5l_tielo _193_ (.L_LO(s_axil_ctrl_rdata[3]));
 sg13cmos5l_tielo _194_ (.L_LO(s_axil_ctrl_rdata[4]));
 sg13cmos5l_tielo _195_ (.L_LO(s_axil_ctrl_rdata[5]));
 sg13cmos5l_tielo _196_ (.L_LO(s_axil_ctrl_rdata[6]));
 sg13cmos5l_tielo _197_ (.L_LO(s_axil_ctrl_rdata[7]));
 sg13cmos5l_tielo _198_ (.L_LO(s_axil_ctrl_rdata[8]));
 sg13cmos5l_tielo _199_ (.L_LO(s_axil_ctrl_rdata[9]));
 sg13cmos5l_tielo _200_ (.L_LO(s_axil_ctrl_rdata[10]));
 sg13cmos5l_tielo _201_ (.L_LO(s_axil_ctrl_rdata[11]));
 sg13cmos5l_tielo _202_ (.L_LO(s_axil_ctrl_rdata[12]));
 sg13cmos5l_tielo _203_ (.L_LO(s_axil_ctrl_rdata[13]));
 sg13cmos5l_tielo _204_ (.L_LO(s_axil_ctrl_rdata[14]));
 sg13cmos5l_tielo _205_ (.L_LO(s_axil_ctrl_rdata[15]));
 sg13cmos5l_tielo _206_ (.L_LO(s_axil_ctrl_rdata[16]));
 sg13cmos5l_tielo _207_ (.L_LO(s_axil_ctrl_rdata[17]));
 sg13cmos5l_tielo _208_ (.L_LO(s_axil_ctrl_rdata[18]));
 sg13cmos5l_tielo _209_ (.L_LO(s_axil_ctrl_rdata[19]));
 sg13cmos5l_tielo _210_ (.L_LO(s_axil_ctrl_rdata[20]));
 sg13cmos5l_tielo _211_ (.L_LO(s_axil_ctrl_rdata[21]));
 sg13cmos5l_tielo _212_ (.L_LO(s_axil_ctrl_rdata[22]));
 sg13cmos5l_tielo _213_ (.L_LO(s_axil_ctrl_rdata[23]));
 sg13cmos5l_tielo _214_ (.L_LO(s_axil_ctrl_rdata[24]));
 sg13cmos5l_tielo _215_ (.L_LO(s_axil_ctrl_rdata[25]));
 sg13cmos5l_tielo _216_ (.L_LO(s_axil_ctrl_rdata[26]));
 sg13cmos5l_tielo _217_ (.L_LO(s_axil_ctrl_rdata[27]));
 sg13cmos5l_tielo _218_ (.L_LO(s_axil_ctrl_rdata[28]));
 sg13cmos5l_tielo _219_ (.L_LO(s_axil_ctrl_rdata[29]));
 sg13cmos5l_tielo _220_ (.L_LO(s_axil_ctrl_rdata[30]));
 sg13cmos5l_tielo _221_ (.L_LO(s_axil_ctrl_rdata[31]));
 sg13cmos5l_tielo _222_ (.L_LO(s_axil_ctrl_rresp[0]));
 sg13cmos5l_tielo _223_ (.L_LO(s_axil_ctrl_rresp[1]));
 sg13cmos5l_tielo _224_ (.L_LO(s_axil_ctrl_rvalid));
 sg13cmos5l_tielo _225_ (.L_LO(s_axil_ctrl_wready));
 sg13cmos5l_tielo _226_ (.L_LO(s_axil_mgr_arready));
 sg13cmos5l_tielo _227_ (.L_LO(s_axil_mgr_awready));
 sg13cmos5l_tielo _228_ (.L_LO(s_axil_mgr_bresp[0]));
 sg13cmos5l_tielo _229_ (.L_LO(s_axil_mgr_bresp[1]));
 sg13cmos5l_tielo _230_ (.L_LO(s_axil_mgr_bvalid));
 sg13cmos5l_tielo _231_ (.L_LO(s_axil_mgr_rdata[0]));
 sg13cmos5l_tielo _232_ (.L_LO(s_axil_mgr_rdata[1]));
 sg13cmos5l_tielo _233_ (.L_LO(s_axil_mgr_rdata[2]));
 sg13cmos5l_tielo _234_ (.L_LO(s_axil_mgr_rdata[3]));
 sg13cmos5l_tielo _235_ (.L_LO(s_axil_mgr_rdata[4]));
 sg13cmos5l_tielo _236_ (.L_LO(s_axil_mgr_rdata[5]));
 sg13cmos5l_tielo _237_ (.L_LO(s_axil_mgr_rdata[6]));
 sg13cmos5l_tielo _238_ (.L_LO(s_axil_mgr_rdata[7]));
 sg13cmos5l_tielo _239_ (.L_LO(s_axil_mgr_rdata[8]));
 sg13cmos5l_tielo _240_ (.L_LO(s_axil_mgr_rdata[9]));
 sg13cmos5l_tielo _241_ (.L_LO(s_axil_mgr_rdata[10]));
 sg13cmos5l_tielo _242_ (.L_LO(s_axil_mgr_rdata[11]));
 sg13cmos5l_tielo _243_ (.L_LO(s_axil_mgr_rdata[12]));
 sg13cmos5l_tielo _244_ (.L_LO(s_axil_mgr_rdata[13]));
 sg13cmos5l_tielo _245_ (.L_LO(s_axil_mgr_rdata[14]));
 sg13cmos5l_tielo _246_ (.L_LO(s_axil_mgr_rdata[15]));
 sg13cmos5l_tielo _247_ (.L_LO(s_axil_mgr_rdata[16]));
 sg13cmos5l_tielo _248_ (.L_LO(s_axil_mgr_rdata[17]));
 sg13cmos5l_tielo _249_ (.L_LO(s_axil_mgr_rdata[18]));
 sg13cmos5l_tielo _250_ (.L_LO(s_axil_mgr_rdata[19]));
 sg13cmos5l_tielo _251_ (.L_LO(s_axil_mgr_rdata[20]));
 sg13cmos5l_tielo _252_ (.L_LO(s_axil_mgr_rdata[21]));
 sg13cmos5l_tielo _253_ (.L_LO(s_axil_mgr_rdata[22]));
 sg13cmos5l_tielo _254_ (.L_LO(s_axil_mgr_rdata[23]));
 sg13cmos5l_tielo _255_ (.L_LO(s_axil_mgr_rdata[24]));
 sg13cmos5l_tielo _256_ (.L_LO(s_axil_mgr_rdata[25]));
 sg13cmos5l_tielo _257_ (.L_LO(s_axil_mgr_rdata[26]));
 sg13cmos5l_tielo _258_ (.L_LO(s_axil_mgr_rdata[27]));
 sg13cmos5l_tielo _259_ (.L_LO(s_axil_mgr_rdata[28]));
 sg13cmos5l_tielo _260_ (.L_LO(s_axil_mgr_rdata[29]));
 sg13cmos5l_tielo _261_ (.L_LO(s_axil_mgr_rdata[30]));
 sg13cmos5l_tielo _262_ (.L_LO(s_axil_mgr_rdata[31]));
 sg13cmos5l_tielo _263_ (.L_LO(s_axil_mgr_rresp[0]));
 sg13cmos5l_tielo _264_ (.L_LO(s_axil_mgr_rresp[1]));
 sg13cmos5l_tielo _265_ (.L_LO(s_axil_mgr_rvalid));
 sg13cmos5l_tielo _266_ (.L_LO(s_axil_mgr_wready));
endmodule
