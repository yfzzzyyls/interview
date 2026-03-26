// Question 2: Reverse bits
//
// Write synthesizable combinational RTL.
//
// Requirement:
// Reverse the bit order of an 8-bit input.
//
// Examples:
// in  = 8'hA3         -> out = 8'hC5
// in  = 8'b1101_0010  -> out = 8'b0100_1011

module reverse_bits (
    input  logic [7:0] in,
    output logic [7:0] out
);
    // write your RTL here
    assign out = {in[0], in[1], in[2], in[3], in[4], in[5], in[6], in[7]};
endmodule
