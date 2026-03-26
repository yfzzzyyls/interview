module shift_register #(
    parameter int WIDTH = 8
) (
    input  logic             clk,
    input  logic             rst,
    input  logic             serial_in,
    output logic [WIDTH-1:0] q
);

    // Shift register with synchronous active-high reset.
    // - On each posedge clk:
    //   - if rst is 1, q resets to 0
    //   - else shift left by 1 bit and load serial_in into q[0]
    // - WIDTH controls the width of q.

    // logic [WIDTH-1:0] shift_register;

    // always_ff @(posedge clk) begin
    //     if(rst) begin
    //         shift_register <= '0;
    //     end
    //     else begin
    //         shift_register <= ( (shift_register << 1) | { {(WIDTH-1){1'b0}}, serial_in } );
    //     end
    // end

    // assign q = shift_register;

    always_ff @(posedge clk) begin
        if(rst) begin
            q <= '0;
        end
        else begin
            q <= ( (q << 1) | { {(WIDTH-1){1'b0}}, serial_in } );
        end
    end

endmodule
