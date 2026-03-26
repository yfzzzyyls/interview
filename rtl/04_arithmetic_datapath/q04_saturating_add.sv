// Question 4: Saturating Add
//
// Write synthesizable combinational RTL.
//
// Requirement:
// Compute `a + b`.
// - If the unsigned addition overflows, clamp `sum` to all 1s
// - Otherwise, output the normal sum
//
// Example with default WIDTH=8:
// a=8'h01, b=8'h02 -> sum=8'h03
// a=8'hFE, b=8'h01 -> sum=8'hFF
// a=8'hFF, b=8'h01 -> sum=8'hFF

module saturating_add #(
    parameter int WIDTH = 8
) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    output logic [WIDTH-1:0] sum
);
    // write your RTL here
    logic [WIDTH:0] result;

    always_comb begin
        result = {1'b0, a} + {1'b0, b};
    end

    assign sum = (result[WIDTH] == 1'b1 ? {(WIDTH){1'b1}} : result[WIDTH-1: 0]);
    
endmodule
