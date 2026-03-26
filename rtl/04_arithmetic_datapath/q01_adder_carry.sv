// Question 1: Adder With Carry
//
// Write synthesizable combinational RTL.
//
// Requirement:
// Add `a`, `b`, and `cin`.
// - `sum` is the lower WIDTH bits of the result
// - `cout` is the carry-out bit
//
// Example with default WIDTH=8:
// a=8'h01, b=8'h02, cin=0 -> sum=8'h03, cout=0
// a=8'hFF, b=8'h01, cin=0 -> sum=8'h00, cout=1
// a=8'h0F, b=8'h00, cin=1 -> sum=8'h10, cout=0

module adder_carry #(
    parameter int WIDTH = 8
) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic             cin,
    output logic [WIDTH-1:0] sum,
    output logic             cout
);
    // write your RTL here
    logic [WIDTH: 0] result;

    assign result = a + b + cin;
    assign {sum, cout} = result;

endmodule
