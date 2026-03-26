// Question 6: Mini ALU Slice
//
// Write synthesizable combinational RTL.
//
// Requirement:
// Based on `op`, perform one of the following operations on `a` and `b`:
// - op=2'd0: add      -> y = a + b
// - op=2'd1: subtract -> y = a - b
// - op=2'd2: min      -> y = smaller of a and b
// - op=2'd3: max      -> y = larger of a and b
//
// Also output:
// - `carry_borrow`
//   - for add: carry-out
//   - for subtract: borrow-out
//   - for min/max: 0
// - `is_zero`: 1 when y == 0, else 0
//
// Assumption:
// - unsigned arithmetic
//
// Example with default WIDTH=8:
// op=0, a=8'hFF, b=8'h01 -> y=8'h00, carry_borrow=1, is_zero=1
// op=1, a=8'h03, b=8'h05 -> y=8'hFE, carry_borrow=1, is_zero=0
// op=2, a=8'h09, b=8'h03 -> y=8'h03, carry_borrow=0, is_zero=0
// op=3, a=8'h09, b=8'h03 -> y=8'h09, carry_borrow=0, is_zero=0

module alu_minislice #(
    parameter int WIDTH = 8
) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic [1:0]       op,
    output logic [WIDTH-1:0] y,
    output logic             carry_borrow,
    output logic             is_zero
);
    // write your RTL here

    logic [WIDTH:0] result;
    always_comb begin
        if(op == 2'b00) begin
            result = {1'b0, a} + {1'b0, b};
            {carry_borrow, y} = result;
            is_zero = ( y == {(WIDTH){1'b0}} );
        end
        else if(op == 2'b01) begin
            result = {1'b0, a} - {1'b0, b};
            {carry_borrow, y} = result;
            is_zero = ( y == '0 );
        end
        else if(op == 2'b11) begin
            carry_borrow = 1'b0;
            is_zero = 1'b0;
            y = (a > b) ? a : b;
        end
        else if(op == 2'b10) begin
            carry_borrow = 1'b0;
            is_zero = 1'b0;
            y = (a < b) ? a : b;
        end
    end
endmodule
