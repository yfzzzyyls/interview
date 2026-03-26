// Question 3: Set One Bit
//
// Write synthesizable combinational RTL.
//
// Requirement:
// Set bit `BIT_IDX` of the input vector to 1.
// All other bits must pass through unchanged.
//
// Assumptions:
// - `0 <= BIT_IDX < WIDTH`
//
// Example with default parameters WIDTH=8, BIT_IDX=2:
// in  = 8'b1010_0001  -> out = 8'b1010_0101
// in  = 8'h00         -> out = 8'h04

module set_bit #(
    parameter int WIDTH   = 8,
    parameter int BIT_IDX = 2
) (
    input  logic [WIDTH-1:0] in,
    output logic [WIDTH-1:0] out
);
    // assign out = {in[WIDTH-1:BIT_IDX+1], 1'b1, in[BIT_IDX-1:0]};

    logic [WIDTH-1:0] mask;
    assign mask = { {(WIDTH-1){1'b0}}, 1'b1 } << BIT_IDX;
    assign out = in | mask;
endmodule
