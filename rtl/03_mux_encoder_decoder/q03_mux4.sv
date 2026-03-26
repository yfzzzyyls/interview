// Question 3: 4-to-1 Mux
//
// Write synthesizable combinational RTL.
//
// Requirement:
// Select one of four WIDTH-bit inputs based on `sel`.
//
// Mapping:
// - sel=2'd0 -> out=d0
// - sel=2'd1 -> out=d1
// - sel=2'd2 -> out=d2
// - sel=2'd3 -> out=d3
//
// Example with default WIDTH=8:
// sel=2'd0 -> out=d0
// sel=2'd2 -> out=d2

module mux4 #(
    parameter int WIDTH = 8
) (
    input  logic [WIDTH-1:0] d0,
    input  logic [WIDTH-1:0] d1,
    input  logic [WIDTH-1:0] d2,
    input  logic [WIDTH-1:0] d3,
    input  logic [1:0]       sel,
    output logic [WIDTH-1:0] out
);
    assign out = (sel == 2'b00) ? d0 :
                 (sel == 2'b01) ? d1 :
                 (sel == 2'b10) ? d2 : 
                                  d3;
  
    // always_comb begin
    //     case(sel)
    //         2'b00: begin
    //             out = d0;
    //         end
    //         2'b01: begin
    //             out = d1;
    //         end
    //         2'b10: begin
    //             out = d2;
    //         end
    //         2'b11: begin
    //             out = d3;
    //         end
    //         default: begin
    //             out = d0;
    //         end
    //     endcase
    // end
endmodule
