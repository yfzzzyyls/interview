// Question 5: Toggle One Bit
//
// Write synthesizable combinational RTL.
//
// Requirement:
// Toggle bit `BIT_IDX` of the input vector.
// All other bits must pass through unchanged.
//
// Assumptions:
// - `0 <= BIT_IDX < WIDTH`
//
// Example with default parameters WIDTH=8, BIT_IDX=2:
// in  = 8'b1010_0001  -> out = 8'b1010_0101
// in  = 8'hFF         -> out = 8'hFB

module toggle_bit #(
    parameter int WIDTH   = 8,
    parameter int BIT_IDX = 2
) (
    input  logic [WIDTH-1:0] in,
    output logic [WIDTH-1:0] out
);
    // write your RTL here
    logic [WIDTH-1:0] mask;
    always_comb begin
        mask = in;
        mask[BIT_IDX] = ~mask[BIT_IDX];
    end

    assign out = mask;
endmodule
