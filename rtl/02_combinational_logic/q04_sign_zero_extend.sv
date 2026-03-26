// Question 4: Sign/Zero Extend
//
// Write synthesizable combinational RTL.
//
// Requirement:
// Extend `in` from `IN_WIDTH` bits to `OUT_WIDTH` bits.
// - When `sign_ext` is 1, perform sign extension.
// - When `sign_ext` is 0, perform zero extension.
//
// Assumptions:
// - `OUT_WIDTH >= IN_WIDTH`
//
// Example with IN_WIDTH=8, OUT_WIDTH=16:
// in=8'h80, sign_ext=1 -> out=16'hFF80
// in=8'h80, sign_ext=0 -> out=16'h0080
// in=8'h7F, sign_ext=1 -> out=16'h007F

module sign_zero_extend #(
    parameter int IN_WIDTH  = 8,
    parameter int OUT_WIDTH = 16
) (
    input  logic [IN_WIDTH-1:0]  in,
    input  logic                 sign_ext,
    output logic [OUT_WIDTH-1:0] out
);
    // write your RTL here

    always_comb begin
        if(sign_ext) begin 
            out = { {(OUT_WIDTH-IN_WIDTH){in[IN_WIDTH - 1]}}, in };
        end 
        else begin
            out = { {(OUT_WIDTH-IN_WIDTH){1'b0}}, in };
        end 
    end

endmodule
