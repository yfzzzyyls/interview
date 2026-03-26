// Question 5: Clamp To Max
//
// Write synthesizable combinational RTL.
//
// Requirement:
// If `in` is greater than `MAX_VAL`, drive `out` with `MAX_VAL`.
// Otherwise, pass `in` through unchanged.
//
// Example with default parameters WIDTH=8, MAX_VAL=8'h9F:
// in=8'h20 -> out=8'h20
// in=8'h9F -> out=8'h9F
// in=8'hC4 -> out=8'h9F

module clamp_max #(
    parameter int WIDTH = 8,
    parameter logic [WIDTH-1:0] MAX_VAL = 8'h9F
) (
    input  logic [WIDTH-1:0] in,
    output logic [WIDTH-1:0] out
);
    // write your RTL here
    assign out = (in > MAX_VAL) ? MAX_VAL : in;
endmodule
