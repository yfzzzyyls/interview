// Question 4: Clear One Bit
//
// Write synthesizable combinational RTL.
//
// Requirement:
// Clear bit `BIT_IDX` of the input vector to 0.
// All other bits must pass through unchanged.
//
// Assumptions:
// - `0 <= BIT_IDX < WIDTH`
//
// Example with default parameters WIDTH=8, BIT_IDX=2:
// in  = 8'b1010_0101  -> out = 8'b1010_0001
// in  = 8'hFF         -> out = 8'hFB

module clear_bit #(
    parameter int WIDTH   = 8,
    parameter int BIT_IDX = 2
) (
    input  logic [WIDTH-1:0] in,
    output logic [WIDTH-1:0] out
);
    // write your RTL here
    logic [WIDTH-1:0] mask;
    always_comb begin
        mask = '1;
        mask[BIT_IDX] = 1'b0;
    end

    assign out = in & mask;
    // assign out = { in[WIDTH-1:BIT_IDX+1], 1'b0, in[BIT_IDX-1:0] };

endmodule
