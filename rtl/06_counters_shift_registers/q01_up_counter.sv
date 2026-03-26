module up_counter #(
    parameter int WIDTH = 8
) (
    input  logic             clk,
    input  logic             rst,
    output logic [WIDTH-1:0] count
);

    // Up counter with synchronous active-high reset.
    // - On each posedge clk:
    //   - if rst is 1, count resets to 0
    //   - else count increments by 1
    // - WIDTH controls the width of count.

    always_ff @(posedge clk) begin 
        if(rst) begin
            count <= '0;
        end
        else begin
            count <= count + 1'b1;
        end
    end

endmodule
