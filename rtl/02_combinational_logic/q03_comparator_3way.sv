// Question 3: 3-Way Comparator
//
// Write synthesizable combinational RTL.
//
// Requirement:
// Compare inputs `a` and `b`.
// Assert exactly one of the following outputs:
// - `lt` when `a < b`
// - `eq` when `a == b`
// - `gt` when `a > b`
//
// Example with default parameter WIDTH=8:
// a=8'h10, b=8'h20 -> lt=1, eq=0, gt=0
// a=8'h55, b=8'h55 -> lt=0, eq=1, gt=0
// a=8'hF0, b=8'h0F -> lt=0, eq=0, gt=1

module comparator_3way #(
    parameter int WIDTH = 8
) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    output logic             lt,
    output logic             eq,
    output logic             gt
);
    // write your RTL here

    assign lt = (a < b);

    assign eq = (a == b);

    assign gt = (a > b);

endmodule
