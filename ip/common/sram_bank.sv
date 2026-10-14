`timescale 1ns / 1ps

module sram_bank #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 512,
    parameter int ADDR_WIDTH = $clog2(DEPTH)
)(
    input  wire                          clk_i,
    input  wire                          we,
    input  wire         [ADDR_WIDTH-1:0] addr,
    input  wire signed  [DATA_WIDTH-1:0] wdata,
    output logic signed [DATA_WIDTH-1:0] rdata
);

    reg signed [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always_ff @(posedge clk_i) begin
        if (we) begin
            mem[addr] <= wdata;
        end
        rdata <= mem[addr];
    end

endmodule