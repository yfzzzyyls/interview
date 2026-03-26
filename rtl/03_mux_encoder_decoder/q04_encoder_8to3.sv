// Question 4: 8-to-3 Encoder
//
// Write synthesizable combinational RTL.
//
// Requirement:
// Encode a one-hot 8-bit input `in` into a 3-bit binary output `code`.
// - If exactly one bit of `in` is asserted, `code` is that bit position
// - If no bits are asserted, drive `valid=0` and `code=3'd0`
//
// Assumption:
// - `in` is either one-hot or all zeros
//
// Examples:
// in=8'b0000_0000 -> valid=0, code=3'd0
// in=8'b0000_0001 -> valid=1, code=3'd0
// in=8'b0001_0000 -> valid=1, code=3'd4
// in=8'b1000_0000 -> valid=1, code=3'd7

module encoder_8to3 (
    input  logic [7:0] in,
    output logic       valid,
    output logic [2:0] code
);
    // write your RTL here

endmodule
