// Question 1: Nibble swap
//
// Write synthesizable combinational RTL.
//
// Requirement:
// Swap the upper and lower 4-bit nibbles of an 8-bit input.
//
// Examples:
// in  = 8'hA3         -> out = 8'h3A
// in  = 8'b1101_0010  -> out = 8'b0010_1101

module nibble_swap (
    input logic [7:0] in,
    output logic [7:0] out
);

    always_comb begin
        out = {in[3:0], in[7:4]};
        // out[7:4] = in[3:0];
        // out[3:0] = in[7:4];
    end

endmodule
