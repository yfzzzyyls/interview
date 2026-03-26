// Question 2: 3-to-8 Decoder
//
// Write synthesizable combinational RTL.
//
// Requirement:
// Decode `sel` into a one-hot 8-bit output.
// - When `en` is 1, exactly one bit of `out` should be asserted
// - When `en` is 0, `out` should be all zeros
//
// Examples:
// en=0, sel=3'd5 -> out=8'b0000_0000
// en=1, sel=3'd0 -> out=8'b0000_0001
// en=1, sel=3'd3 -> out=8'b0000_1000
// en=1, sel=3'd7 -> out=8'b1000_0000

module decoder_3to8 #(parameter int WIDTH = 8) (
    input  logic       en,
    input  logic [2:0] sel,
    output logic [7:0] out
);
    assign out = en ? ({ {(WIDTH-1){1'b0}} , 1'b1 } << sel) : '0;

endmodule
