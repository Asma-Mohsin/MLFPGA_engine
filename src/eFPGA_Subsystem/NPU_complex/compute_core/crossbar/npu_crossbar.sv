`timescale 1ns / 1ps

module npu_crossbar #(
    parameter int ARRAY_HEIGHT     = 8,
    parameter int ACTIVATION_WIDTH = 8,
    localparam int BANK_SEL_BITS   = $clog2(ARRAY_HEIGHT),
    localparam int SEL_WIDTH       = BANK_SEL_BITS + 1 // 4 bits: 0..7 = Banks, >=8 (MSB=1) = Zero
)(
    input  wire signed [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0] in_data,
    input  wire        [ARRAY_HEIGHT-1:0][SEL_WIDTH-1:0]        crossbar_sel,
    output logic signed [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0] out_data
);

    genvar r;
    generate
        for (r = 0; r < ARRAY_HEIGHT; r++) begin : gen_row_mux
            always_comb begin
                if (crossbar_sel[r][SEL_WIDTH-1]) begin
                    out_data[r] = '0;
                end else begin
                    out_data[r] = in_data[crossbar_sel[r][BANK_SEL_BITS-1:0]];
                end
            end
        end
    endgenerate

endmodule