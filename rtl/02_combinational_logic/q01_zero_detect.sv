// Question 1: Zero Detect
//
// Write synthesizable combinational RTL.
//
// Requirement:
// Assert `is_zero` when the entire input vector is all zeros.
// Otherwise, deassert `is_zero`.
//
// Example with default parameter WIDTH=8:
// in      = 8'h00 -> is_zero = 1'b1
// in      = 8'h80 -> is_zero = 1'b0

module zero_detect #(
    parameter int WIDTH = 8
) (
    input  logic [WIDTH-1:0] in,
    output logic             is_zero
);
    assign is_zero = ( in == {(WIDTH){1'b0}} ) ;
    
endmodule
