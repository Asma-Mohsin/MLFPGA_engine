`timescale 1ns / 1ps

/* ===============================================================================================
 * File: RTL/eFPGA_Subsystem/AXI_Connector/axi_watchdog_master_monitor.sv
 * Module: axi_watchdog_master_monitor
 * Project: CrocoScale SoC — Fabric AXI4 Master Protocol & Security Monitor
 *
 * Architectural Note on Outstanding Write Tracking & Backpressure:
 *   - Outstanding write tracking in awlen_fifo strictly serves WLAST protocol
 *     verification (ENABLE_WLAST_CHECK).
 *   - In compliance with the AXI4 specification, a master asserting AWVALID when
 *     downstream buffers are occupied is standard request behavior and is NOT a
 *     protocol violation. The downstream interconnect / slave is responsible for
 *     holding AWREADY = 0 (backpressure) until queue slots become available.
 *   - MAX_OUTSTANDING_WRITES must remain synchronized with the maximum transaction
 *     acceptance depth of the downstream slave (e.g. crossbar write routing limit).
 * =============================================================================================== */

module axi_watchdog_master_monitor #(
    parameter bit ENABLE_TIMEOUT           = 1'b1,
    parameter bit ENABLE_DROPPED_VALID     = 1'b1,
    parameter bit ENABLE_PAYLOAD_STABILITY = 1'b0,
    parameter bit ENABLE_4K_CHECK          = 1'b1,
    parameter bit ENABLE_SIZE_CHECK        = 1'b1,
    parameter bit ENABLE_BURST_CHECK       = 1'b1,
    parameter bit ENABLE_WLAST_CHECK       = 1'b1,
    parameter int MAX_OUTSTANDING_WRITES   = 1,
    parameter int WATCHDOG_LIMIT           = 512,
    parameter int AXI_ID_WIDTH             = 8
)(
    input  wire clk_i, 
    input  wire rstn_i,
    
    // AXI4-Full Master Interface signals
    input  wire awvalid, input  wire awready, 
    input  wire [AXI_ID_WIDTH-1:0] awid, input wire [31:0] awaddr, input wire [7:0] awlen, input wire [2:0] awsize, input wire [1:0] awburst, input wire awlock, input wire [3:0] awcache, input wire [2:0] awprot,
    
    input  wire wvalid,  input  wire wready,  input wire wlast,
    input  wire [31:0] wdata, input wire [3:0] wstrb,
    
    input  wire bvalid,  input  wire bready,
    
    input  wire arvalid, input  wire arready,
    input  wire [AXI_ID_WIDTH-1:0] arid, input wire [31:0] araddr, input wire [7:0] arlen, input wire [2:0] arsize, input wire [1:0] arburst, input wire arlock, input wire [3:0] arcache, input wire [2:0] arprot,
    
    input  wire rvalid,  input  wire rready,  input wire rlast,
    
    // Direct zero-delay combinational fault lines to firewall
    output wire fault_timeout_w_o,
    output wire fault_timeout_r_o,
    output wire fault_dropped_valid_w_o,
    output wire fault_dropped_valid_r_o,
    output wire fault_unstable_w_o,
    output wire fault_unstable_r_o,
    output wire fault_4k_cross_w_o,
    output wire fault_4k_cross_r_o,
    output wire fault_illegal_size_w_o,
    output wire fault_illegal_size_r_o,
    output wire fault_illegal_burst_w_o,
    output wire fault_illegal_burst_r_o,
    output wire fault_wlast_timing_o
);

    // ===================================================================
    // Transfer Size Legality Check
    // ===================================================================
    wire aw_illegal_size;
    wire ar_illegal_size;
    generate
        if (ENABLE_SIZE_CHECK) begin : gen_size_check
            assign aw_illegal_size = awvalid & (awsize > 3'd2);
            assign ar_illegal_size = arvalid & (arsize > 3'd2);
        end else begin : gen_no_size_check
            assign aw_illegal_size = 1'b0;
            assign ar_illegal_size = 1'b0;
        end
    endgenerate
    assign fault_illegal_size_w_o = aw_illegal_size;
    assign fault_illegal_size_r_o = ar_illegal_size;

    // ===================================================================
    // 4KB Page Boundary Crossing Check
    // ===================================================================
    generate
        if (ENABLE_4K_CHECK) begin : gen_4k_check
            wire [1:0] aw_effective_size = (ENABLE_SIZE_CHECK && (awsize > 3'd2)) ? 2'd2 : awsize[1:0];
            wire [1:0] ar_effective_size = (ENABLE_SIZE_CHECK && (arsize > 3'd2)) ? 2'd2 : arsize[1:0];

            wire [12:0] aw_burst_bytes = 13'((13'(awlen) + 13'd1) << aw_effective_size);
            wire [12:0] ar_burst_bytes = 13'((13'(arlen) + 13'd1) << ar_effective_size);

            wire [12:0] aw_offset_sum  = {1'b0, awaddr[11:0]} + aw_burst_bytes;
            wire [12:0] ar_offset_sum  = {1'b0, araddr[11:0]} + ar_burst_bytes;

            assign fault_4k_cross_w_o = awvalid & (aw_offset_sum[12] && (aw_offset_sum[11:0] != 12'd0));
            assign fault_4k_cross_r_o = arvalid & (ar_offset_sum[12] && (ar_offset_sum[11:0] != 12'd0));
        end else begin : gen_no_4k_check
            assign fault_4k_cross_w_o = 1'b0;
            assign fault_4k_cross_r_o = 1'b0;
        end
    endgenerate

    // ===================================================================
    // Burst Type & Length Legality Checks
    // ===================================================================
    generate
        if (ENABLE_BURST_CHECK) begin : gen_burst_check
            wire aw_burst_reserved = (awburst == 2'b11);
            wire ar_burst_reserved = (arburst == 2'b11);

            wire aw_fixed_illegal_len = (awburst == 2'b00) & (awlen > 8'd15);
            wire ar_fixed_illegal_len = (arburst == 2'b00) & (arlen > 8'd15);

            wire aw_is_wrap = (awburst == 2'b10);
            wire ar_is_wrap = (arburst == 2'b10);

            wire aw_wrap_len_ok = (awlen == 8'd1) | (awlen == 8'd3) | (awlen == 8'd7) | (awlen == 8'd15);
            wire ar_wrap_len_ok = (arlen == 8'd1) | (arlen == 8'd3) | (arlen == 8'd7) | (arlen == 8'd15);

            wire aw_wrap_illegal_len = aw_is_wrap & ~aw_wrap_len_ok;
            wire ar_wrap_illegal_len = ar_is_wrap & ~ar_wrap_len_ok;

            wire [1:0] aw_effective_size = (ENABLE_SIZE_CHECK && (awsize > 3'd2)) ? 2'd2 : awsize[1:0];
            wire [1:0] ar_effective_size = (ENABLE_SIZE_CHECK && (arsize > 3'd2)) ? 2'd2 : arsize[1:0];

            wire [5:0] aw_wrap_mask = 6'(((6'(awlen) + 6'd1) << aw_effective_size) - 6'd1);
            wire [5:0] ar_wrap_mask = 6'(((6'(arlen) + 6'd1) << ar_effective_size) - 6'd1);

            wire aw_wrap_unaligned = aw_is_wrap & aw_wrap_len_ok & ((awaddr[5:0] & aw_wrap_mask) != 6'd0);
            wire ar_wrap_unaligned = ar_is_wrap & ar_wrap_len_ok & ((araddr[5:0] & ar_wrap_mask) != 6'd0);

            assign fault_illegal_burst_w_o = awvalid & (aw_burst_reserved | aw_fixed_illegal_len | aw_wrap_illegal_len | aw_wrap_unaligned);
            assign fault_illegal_burst_r_o = arvalid & (ar_burst_reserved | ar_fixed_illegal_len | ar_wrap_illegal_len | ar_wrap_unaligned);
        end else begin : gen_no_burst_check
            assign fault_illegal_burst_w_o = 1'b0;
            assign fault_illegal_burst_r_o = 1'b0;
        end
    endgenerate

    // ===================================================================
    // Timeout Detection
    // ===================================================================
    generate
        if (ENABLE_TIMEOUT) begin : gen_timeout
            localparam TIMER_W = $clog2(WATCHDOG_LIMIT + 1);
            localparam logic [TIMER_W:0] LIMIT_VAL = (TIMER_W + 1)'(WATCHDOG_LIMIT);
            localparam logic [TIMER_W:0] TIMER_ONE  = (TIMER_W + 1)'(1);

            reg w_in_flight;
            always_ff @(posedge clk_i or negedge rstn_i) begin
                if (!rstn_i) w_in_flight <= 1'b0;
                else if (wvalid & wready) w_in_flight <= ~wlast;
            end

            wire w_stall = (w_in_flight & ~wvalid) | (bvalid & ~bready);
            wire r_stall = (rvalid & ~rready);
            
            reg [TIMER_W:0] w_timer, r_timer;
            always_ff @(posedge clk_i or negedge rstn_i) begin
                if (!rstn_i) begin w_timer <= '0; r_timer <= '0; end
                else begin
                    w_timer <= w_stall ? (w_timer >= LIMIT_VAL ? w_timer : w_timer + TIMER_ONE) : '0;
                    r_timer <= r_stall ? (r_timer >= LIMIT_VAL ? r_timer : r_timer + TIMER_ONE) : '0;
                end
            end
            assign fault_timeout_w_o = (w_timer >= LIMIT_VAL);
            assign fault_timeout_r_o = (r_timer >= LIMIT_VAL);
        end else begin : gen_no_timeout
            assign fault_timeout_w_o = 1'b0;
            assign fault_timeout_r_o = 1'b0;
        end
    endgenerate

    // ===================================================================
    // Handshake Integrity & Payload Stability
    // ===================================================================
    generate
        if (ENABLE_DROPPED_VALID || ENABLE_PAYLOAD_STABILITY) begin : gen_handshake_track
            reg awvalid_q, wvalid_q, arvalid_q, awready_q, wready_q, arready_q;

            always_ff @(posedge clk_i or negedge rstn_i) begin
                if (!rstn_i) begin
                    awvalid_q <= 1'b0; wvalid_q <= 1'b0; arvalid_q <= 1'b0;
                    awready_q <= 1'b0; wready_q <= 1'b0; arready_q <= 1'b0;
                end else begin
                    awvalid_q <= awvalid; wvalid_q <= wvalid; arvalid_q <= arvalid;
                    awready_q <= awready; wready_q <= wready; arready_q <= arready;
                end
            end

            if (ENABLE_DROPPED_VALID) begin : gen_dropped_valid
                assign fault_dropped_valid_w_o = (awvalid_q & ~awready_q & ~awvalid) | (wvalid_q & ~wready_q & ~wvalid);
                assign fault_dropped_valid_r_o = (arvalid_q & ~arready_q & ~arvalid);
            end else begin : gen_no_dropped_valid
                assign fault_dropped_valid_w_o = 1'b0;
                assign fault_dropped_valid_r_o = 1'b0;
            end

            if (ENABLE_PAYLOAD_STABILITY) begin : gen_payload_stability
                localparam AW_W = AXI_ID_WIDTH + 32 + 8 + 3 + 2 + 1 + 4 + 3;
                localparam W_W  = 32 + 4 + 1;
                localparam AR_W = AXI_ID_WIDTH + 32 + 8 + 3 + 2 + 1 + 4 + 3;

                wire [AW_W-1:0] aw_payload = {awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot};
                wire [W_W-1:0]  w_payload  = {wdata, wstrb, wlast};
                wire [AR_W-1:0] ar_payload = {arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot};

                reg [AW_W-1:0] aw_payload_q;
                reg [W_W-1:0]  w_payload_q;
                reg [AR_W-1:0] ar_payload_q;

                always_ff @(posedge clk_i or negedge rstn_i) begin
                    if (!rstn_i) begin
                        aw_payload_q <= '0; w_payload_q <= '0; ar_payload_q <= '0;
                    end else begin
                        aw_payload_q <= aw_payload; w_payload_q <= w_payload; ar_payload_q <= ar_payload;
                    end
                end

                wire aw_unstable = awvalid_q & ~awready_q & awvalid & (aw_payload != aw_payload_q);
                wire w_unstable  = wvalid_q  & ~wready_q  & wvalid  & (w_payload  != w_payload_q);
                wire ar_unstable = arvalid_q & ~arready_q & arvalid & (ar_payload != ar_payload_q);

                assign fault_unstable_w_o = aw_unstable | w_unstable;
                assign fault_unstable_r_o = ar_unstable;
            end else begin : gen_no_payload_stability
                assign fault_unstable_w_o = 1'b0;
                assign fault_unstable_r_o = 1'b0;
            end
        end else begin : gen_no_handshake_track
            assign fault_dropped_valid_w_o = 1'b0;
            assign fault_dropped_valid_r_o = 1'b0;
            assign fault_unstable_w_o      = 1'b0;
            assign fault_unstable_r_o      = 1'b0;
        end
    endgenerate

    generate
        if (ENABLE_WLAST_CHECK) begin : gen_burst_tracking
            localparam int FIFO_DEPTH = (MAX_OUTSTANDING_WRITES < 1) ? 1 : MAX_OUTSTANDING_WRITES;
            localparam int PTR_W      = (FIFO_DEPTH > 1) ? $clog2(FIFO_DEPTH) : 1;
            localparam int CNT_W      = (FIFO_DEPTH > 1) ? ($clog2(FIFO_DEPTH) + 1) : 2;

            reg [7:0] awlen_fifo [0:FIFO_DEPTH-1];
            reg [PTR_W-1:0] awlen_wr_ptr, awlen_rd_ptr;
            reg [CNT_W-1:0] awlen_count;

            wire aw_push = awvalid & awready;
            wire w_pop   = wvalid & wready & wlast;
            wire fifo_full = (awlen_count == CNT_W'(FIFO_DEPTH));

            always_ff @(posedge clk_i or negedge rstn_i) begin
                if (!rstn_i) begin
                    awlen_wr_ptr <= '0;
                    awlen_rd_ptr <= '0;
                    awlen_count  <= '0;
                end else begin
                    case ({aw_push, w_pop})
                        2'b10: begin
                            if (!fifo_full) begin
                                awlen_fifo[awlen_wr_ptr] <= awlen;
                                if (FIFO_DEPTH > 1) begin
                                    awlen_wr_ptr <= (awlen_wr_ptr == PTR_W'(FIFO_DEPTH - 1)) ? '0 : awlen_wr_ptr + 1'b1;
                                end
                                awlen_count <= awlen_count + 1'b1;
                            end
                        end
                        2'b01: begin
                            if (awlen_count > 0) begin
                                if (FIFO_DEPTH > 1) begin
                                    awlen_rd_ptr <= (awlen_rd_ptr == PTR_W'(FIFO_DEPTH - 1)) ? '0 : awlen_rd_ptr + 1'b1;
                                end
                                awlen_count <= awlen_count - 1'b1;
                            end
                        end
                        2'b11: begin
                            awlen_fifo[awlen_wr_ptr] <= awlen;
                            if (FIFO_DEPTH > 1) begin
                                awlen_wr_ptr <= (awlen_wr_ptr == PTR_W'(FIFO_DEPTH - 1)) ? '0 : awlen_wr_ptr + 1'b1;
                                awlen_rd_ptr <= (awlen_rd_ptr == PTR_W'(FIFO_DEPTH - 1)) ? '0 : awlen_rd_ptr + 1'b1;
                            end
                        end
                        default: ;
                    endcase
                end
            end

            reg [7:0] current_w_beat;
            always_ff @(posedge clk_i or negedge rstn_i) begin
                if (!rstn_i) current_w_beat <= 8'd0;
                else if (wvalid & wready) begin
                    if (wlast) current_w_beat <= 8'd0;
                    else current_w_beat <= current_w_beat + 1'b1;
                end
            end

            assign fault_wlast_timing_o = wvalid & (
                (awlen_count == '0) |
                ((current_w_beat == awlen_fifo[awlen_rd_ptr]) != wlast)
            );
        end else begin : gen_no_burst_tracking
            assign fault_wlast_timing_o = 1'b0;
        end
    endgenerate

endmodule