`timescale 1ns / 1ps

module axi_watchdog_slave_monitor #(
    parameter bit ENABLE_TIMEOUT           = 1'b1, 
    parameter bit ENABLE_DROPPED_VALID     = 1'b1,
    parameter bit ENABLE_PAYLOAD_STABILITY = 1'b0,
    parameter int WATCHDOG_LIMIT           = 512,
    parameter int AXI_ID_WIDTH             = 8
)(
    input  wire clk_i, 
    input  wire rstn_i,
    
    input  wire awvalid, input  wire awready,
    input  wire wvalid,  input  wire wready,  input wire wlast,
    
    input  wire bvalid,  input  wire bready,  
    input  wire [AXI_ID_WIDTH-1:0] bid, input wire [1:0] bresp,
    
    input  wire arvalid, input  wire arready,
    
    input  wire rvalid,  input  wire rready,  input wire rlast,
    input  wire [AXI_ID_WIDTH-1:0] rid, input wire [31:0] rdata, input wire [1:0] rresp,
    
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

            wire aw_fire      = awvalid & awready;
            wire w_burst_fire = wvalid & wready & wlast;
            wire b_fire       = bvalid & bready;

            reg signed [7:0] aw_w_delta;
            wire aw_ahead = (aw_w_delta > 8'sd0);
            wire w_ahead  = (aw_w_delta < 8'sd0);
            wire wr_tx_completed = (aw_fire & w_burst_fire) | (aw_fire & w_ahead) | (w_burst_fire & aw_ahead);

            reg [7:0] b_owed, r_owed;
            always_ff @(posedge clk_i or negedge rstn_i) begin
                if (!rstn_i) begin
                    aw_w_delta <= 8'sd0;
                    b_owed     <= 8'd0;
                    r_owed     <= 8'd0;
                end else begin
                    aw_w_delta <= aw_w_delta + (aw_fire ? 8'sd1 : 8'sd0) - (w_burst_fire ? 8'sd1 : 8'sd0);

                    case ({wr_tx_completed, b_fire})
                        2'b10: b_owed <= b_owed + 8'd1;
                        2'b01: if (b_owed > 8'd0) b_owed <= b_owed - 8'd1;
                        default: ;
                    endcase
                    case ({(arvalid & arready), (rvalid & rready & rlast)})
                        2'b10: r_owed <= r_owed + 8'd1;
                        2'b01: if (r_owed > 8'd0) r_owed <= r_owed - 8'd1;
                        default: ;
                    endcase
                end
            end

            wire w_stall = (awvalid & ~awready) | (wvalid & ~wready) | ((b_owed > 8'd0) & ~bvalid);
            wire r_stall = (arvalid & ~arready) | ((r_owed > 8'd0) & ~rvalid); 
            
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
            reg bvalid_q, rvalid_q, bready_q, rready_q;

            always_ff @(posedge clk_i or negedge rstn_i) begin
                if (!rstn_i) begin 
                    bvalid_q <= 1'b0; rvalid_q <= 1'b0; bready_q <= 1'b0; rready_q <= 1'b0; 
                end else begin 
                    bvalid_q <= bvalid; rvalid_q <= rvalid; bready_q <= bready; rready_q <= rready; 
                end
            end

            if (ENABLE_DROPPED_VALID) begin : gen_dropped_valid
                assign fault_dropped_valid_w_o = bvalid_q & ~bready_q & ~bvalid;
                assign fault_dropped_valid_r_o = rvalid_q & ~rready_q & ~rvalid;
            end else begin : gen_no_dropped_valid
                assign fault_dropped_valid_w_o = 1'b0;
                assign fault_dropped_valid_r_o = 1'b0;
            end

            if (ENABLE_PAYLOAD_STABILITY) begin : gen_payload_stability
                localparam B_W = AXI_ID_WIDTH + 2;
                localparam R_W = AXI_ID_WIDTH + 32 + 2 + 1;

                wire [B_W-1:0] b_payload = {bid, bresp};
                wire [R_W-1:0] r_payload = {rid, rdata, rresp, rlast};

                reg [B_W-1:0] b_payload_q;
                reg [R_W-1:0] r_payload_q;

                always_ff @(posedge clk_i or negedge rstn_i) begin
                    if (!rstn_i) begin 
                        b_payload_q <= '0; r_payload_q <= '0;
                    end else begin 
                        b_payload_q <= b_payload; r_payload_q <= r_payload;
                    end
                end

                assign fault_unstable_w_o = bvalid_q & ~bready_q & bvalid & (b_payload != b_payload_q);
                assign fault_unstable_r_o = rvalid_q & ~rready_q & rvalid & (r_payload != r_payload_q);
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