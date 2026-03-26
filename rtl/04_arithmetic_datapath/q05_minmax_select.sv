// Question 5: Min/Max Select
//
// Write synthesizable combinational RTL.
//
// Requirement:
// Compare `a` and `b`.
// - `min_val` should be the smaller of the two
// - `max_val` should be the larger of the two
// - if they are equal, both outputs should be that shared value
//
// Example with default WIDTH=8:
// a=8'h09, b=8'h03 -> min_val=8'h03, max_val=8'h09
// a=8'h03, b=8'h09 -> min_val=8'h03, max_val=8'h09
// a=8'h55, b=8'h55 -> min_val=8'h55, max_val=8'h55

module minmax_select #(
    parameter int WIDTH = 8
) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    output logic [WIDTH-1:0] min_val,
    output logic [WIDTH-1:0] max_val
);
    // write your RTL here
    assign min_val = (a < b) ? a :
                        ( a > b) ? b :
                                    a;
    assign max_val = (a > b) ? a :
                        ( a < b) ? b :
                                    a;

endmodule
