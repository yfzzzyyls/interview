// Question 3: Absolute Difference
//
// Write synthesizable combinational RTL.
//
// Requirement:
// Compute the absolute difference between `a` and `b`.
// - If `a >= b`, `diff = a - b`
// - If `a < b`,  `diff = b - a`
//
// Example with default WIDTH=8:
// a=8'h09, b=8'h03 -> diff=8'h06
// a=8'h03, b=8'h09 -> diff=8'h06
// a=8'h55, b=8'h55 -> diff=8'h00

module abs_diff #(
    parameter int WIDTH = 8
) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    output logic [WIDTH-1:0] diff
);
    // write your RTL here
    assign diff = ( a >= b) ? a - b : b - a;
endmodule
