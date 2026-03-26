module loadable_shift_register #(
    parameter int WIDTH = 8
) (
    input  logic             clk,
    input  logic             rst,
    input  logic             load,
    input  logic             shift_en,
    input  logic             serial_in,
    input  logic [WIDTH-1:0] parallel_in,
    output logic [WIDTH-1:0] q
);

    // Loadable shift register with synchronous active-high reset.
    // - On each posedge clk:
    //   - if rst is 1, q resets to 0
    //   - else if load is 1, q loads parallel_in
    //   - else if shift_en is 1, q shifts left by 1 and loads serial_in into q[0]
    //   - else q holds its previous value
    // - WIDTH controls the width of q and parallel_in.

    always_ff @(posedge clk) begin
        if(rst) begin
            q <= '0;
        end
        else if (load) begin
            q <= parallel_in;
        end
        else if (shift_en) begin
            q <= ( (q << 1) | serial_in );
        end
    end

endmodule
