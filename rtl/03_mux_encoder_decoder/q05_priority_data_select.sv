// Question 5: Priority Data Select
//
// Write synthesizable combinational RTL.
//
// Requirement:
// Given four request bits and four associated data inputs, select the data
// belonging to the highest-priority asserted request.
//
// Priority:
// - req[3] is highest priority
// - req[0] is lowest priority
//
// Behavior:
// - If any request is asserted, drive `valid=1` and `out` with the
//   corresponding data input
// - If no request is asserted, drive `valid=0` and `out='0`
//
// Example with default WIDTH=8:
// req=4'b0000 -> valid=0, out=8'h00
// req=4'b0001 -> valid=1, out=d0
// req=4'b0101 -> valid=1, out=d2
// req=4'b1010 -> valid=1, out=d3

module priority_data_select #(
    parameter int WIDTH = 8
) (
    input  logic [3:0]       req,
    input  logic [WIDTH-1:0] d0,
    input  logic [WIDTH-1:0] d1,
    input  logic [WIDTH-1:0] d2,
    input  logic [WIDTH-1:0] d3,
    output logic             valid,
    output logic [WIDTH-1:0] out
);
    // write your RTL here
    // assign valid = !(req == 0);

    // always_comb begin
    //     for (int i = 0; i < 4; i++) begin
    //         if (req[i]) begin
    //             out =   (i[1:0] == 2'b00) ? d0 :
    //                     (i[1:0] == 2'b01) ? d1 :
    //                     (i[1:0] == 2'b10) ? d2 :
    //                     (i[1:0] == 2'b11) ? d3 :
    //                             {(WIDTH){1'b0}};
    //         end
    //     end
    // end

    always_comb begin
        valid = 1'b0;
        out   = '0;

        if (req[3]) begin
            valid = 1'b1;
            out   = d3;
        end
        else if (req[2]) begin
            valid = 1'b1;
            out   = d2;
        end
        else if (req[1]) begin
            valid = 1'b1;
            out   = d1;
        end
        else if (req[0]) begin
            valid = 1'b1;
            out   = d0;
        end
    end

endmodule
