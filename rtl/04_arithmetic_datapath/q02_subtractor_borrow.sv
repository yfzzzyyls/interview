// Question 2: Subtractor With Borrow
//
// Write synthesizable combinational RTL.
//
// Requirement:
// Compute `a - b - bin`.
// - `diff` is the lower WIDTH bits of the result
// - `bout` indicates borrow-out
//
// Example with default WIDTH=8:
// a=8'h05, b=8'h02, bin=0 -> diff=8'h03, bout=0
// a=8'h00, b=8'h01, bin=0 -> diff=8'hFF, bout=1
// a=8'h10, b=8'h0F, bin=1 -> diff=8'h00, bout=0

module subtractor_borrow #(
    parameter int WIDTH = 8
) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic             bin,
    output logic [WIDTH-1:0] diff,
    output logic             bout
);

    // assign diff = a - b - bin;
    // assign bout = (b > a) ? 1'b1 : 1'b0;

    logic [WIDTH : 0] result;
    assign result = {1'b0, a} - {1'b0, b} - bin;
    assign {bout, diff} = result;
endmodule
