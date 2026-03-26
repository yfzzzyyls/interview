module dff_enable #(
    parameter int WIDTH = 8
) (
    input  logic             clk,
    input  logic             en,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);

    // D flip-flop with enable.
    // - On each posedge clk, if en is 1, q captures d.
    // - If en is 0, q holds its previous value.
    // - WIDTH controls the width of d and q.
    always_ff @(posedge clk) begin
        if(en) begin
            q <= d;
        end
    end
endmodule
