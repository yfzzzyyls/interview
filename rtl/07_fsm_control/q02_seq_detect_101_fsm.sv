module seq_detect_101_fsm (
    input  logic clk,
    input  logic rst,
    input  logic bit_in,
    output logic detect
);

    typedef enum logic [1:0] {
        IDLE,
        S1,
        S10
    } state_t;

    state_t state, next_state;

    logic detect_comb;

    always_comb begin
        next_state = state;
   
        case (state)
            IDLE: begin
                if (bit_in) begin
                    next_state = S1;
                end
            end

            S1: begin
                if (bit_in) begin
                    next_state = S1;
                end
                else begin
                    next_state = S10;
                end
            end

            S10: begin
                if (bit_in) begin
                    next_state = S1;
                end
                else begin
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always_comb begin
        detect_comb = (state == S10) && bit_in;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state  <= IDLE;
            detect <= 1'b0;
        end else begin
            state  <= next_state;
            detect <= detect_comb;
        end
    end


endmodule
