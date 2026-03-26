module johnson_counter #(
    parameter int WIDTH = 4
) (
    input  logic             clk,
    input  logic             rst,
    output logic [WIDTH-1:0] q
);

    // Johnson counter with synchronous active-high reset.
    // - On each posedge clk:
    //   - if rst is 1, q resets to 0
    //   - else shift left by 1 and load ~q[WIDTH-1] into q[0]
    // - WIDTH controls the width of q.

    // logic s;
    // always_comb begin
    //     s = ;
    // end

    always_ff @(posedge clk) begin
        if(rst) begin
            q <= '0;
        end
        else  begin
            q <= ( {q[WIDTH-2: 0], ~q[WIDTH-1]} );
        end
    end

endmodule
