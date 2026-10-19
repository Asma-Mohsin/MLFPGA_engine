`timescale 1ns / 1ps

module axil_watchdog_master_monitor #(
    parameter bit ENABLE_TIMEOUT           = 1'b1, 
    parameter bit ENABLE_DROPPED_VALID     = 1'b1,
    parameter bit ENABLE_PAYLOAD_STABILITY = 1'b0,
    parameter int WATCHDOG_LIMIT           = 512
)(
    input  wire clk_i, 
    input  wire rstn_i,
    
    input  wire awvalid, input  wire awready, input wire [31:0] awaddr, input wire [2:0] awprot,
    input  wire wvalid,  input  wire wready,  input wire [31:0] wdata,  input wire [3:0] wstrb,
    input  wire bvalid,  input  wire bready,
    input  wire arvalid, input  wire arready, input wire [31:0] araddr, input wire [2:0] arprot,
    input  wire rvalid,  input  wire rready,
    
    output wire fault_timeout_w_o,
    output wire fault_timeout_r_o,
    output wire fault_dropped_valid_w_o,
    output wire fault_dropped_valid_r_o,
    output wire fault_unstable_w_o,
    output wire fault_unstable_r_o
);

    // ===================================================================
    // Timeout Detection
    // ===================================================================
    generate
        if (ENABLE_TIMEOUT) begin : gen_timeout
            localparam TIMER_W = $clog2(WATCHDOG_LIMIT + 1);
            localparam logic [TIMER_W:0] LIMIT_VAL = (TIMER_W + 1)'(WATCHDOG_LIMIT);
            localparam logic [TIMER_W:0] TIMER_ONE  = (TIMER_W + 1)'(1);

            wire w_stall = (bvalid & ~bready);
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
                wire [34:0] aw_payload = {awaddr, awprot};
                wire [35:0] w_payload  = {wdata, wstrb};
                wire [34:0] ar_payload = {araddr, arprot};

                reg [34:0] aw_payload_q, ar_payload_q;
                reg [35:0] w_payload_q;

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

endmodule