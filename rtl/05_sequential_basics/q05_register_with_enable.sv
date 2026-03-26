module register_with_enable #(
    parameter int WIDTH = 8
) (
    input  logic             clk,
    input  logic             rst,
    input  logic             en,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);

    // Register with synchronous active-high reset and enable.
    // - On each posedge clk:
    //   - if rst is 1, q resets to 0
    //   - else if en is 1, q captures d
    //   - else q holds its previous value
    // - WIDTH controls the width of d and q.

    always_ff @(posedge clk) begin
        if (rst) begin
            q <= '0;
        end
        else if (en) begin
            q <= d;
        end
    end

endmodule
