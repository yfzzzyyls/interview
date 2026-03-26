// Question 2: Even Parity Bit
//
// Write synthesizable combinational RTL.
//
// Requirement:
// Generate an even-parity bit for `in`.
// The output `parity` should make the total number of 1s in `{in, parity}` even.
//
// Example with default parameter WIDTH=8:
// in     = 8'b0000_0000 -> parity = 1'b0
// in     = 8'b0000_0001 -> parity = 1'b1
// in     = 8'b1010_0101 -> parity = 1'b0

module even_parity #(
    parameter int WIDTH = 8
) (
    input  logic [WIDTH-1:0] in,
    output logic             parity
);
    // write your RTL here
    assign parity = ^in;
endmodule
