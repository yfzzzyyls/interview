module seq_detect_101 (
    input  logic clk,
    input  logic rst,
    input  logic bit_in,
    output logic detect
);

    // Sequence detector for the bit pattern 1-0-1.
    // - On each posedge clk:
    //   - if rst is 1, the FSM returns to its idle state
    //   - else it consumes bit_in and updates state
    // - detect should pulse high for one cycle when the sequence 1-0-1 is seen.
    // - Overlapping matches are allowed.

    logic [2:0] state;

    always_ff @(posedge clk) begin
        if(rst) begin 
            state <= 1'b0;
            detect <= 1'b0;
        end
        else begin
            state <= {state[1:0], bit_in};
            detect <= ( {state[1:0], bit_in} == 3'b101 );
        end
    end

endmodule
