module sticky_flag (
    input  logic clk,
    input  logic rst,
    input  logic clr,
    input  logic event_i,
    output logic flag
);

    // Sticky flag register.
    // - On each posedge clk:
    //   - if rst is 1, flag resets to 0
    //   - else if clr is 1, flag clears to 0
    //   - else if event_i is 1, flag sets to 1
    //   - else flag holds its previous value
    // - clr has priority over event_i when both are 1 in the same cycle.

    always_ff @(posedge clk) begin
        if (rst) begin
            flag <= 1'b0;
        end
        else if(clr) begin
            flag <= 1'b0;
        end
        else if(event_i) begin
            flag <= 1'b1;
        end
    end

endmodule
