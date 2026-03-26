module tb;

    localparam int WIDTH = 8;

    logic [WIDTH-1:0] in;
    logic             is_zero;
    logic             expected;
    int error_count = 0;

    zero_detect #(
        .WIDTH(WIDTH)
    ) dut_zero_detect (
        .in(in),
        .is_zero(is_zero)
    );

    initial begin
        in = '0;
        expected = 1'b1;
        #1 if (is_zero !== expected) begin
            $display("Wrong result: input: %0h, output: %0b, golden: %0b", in, is_zero, expected);
            error_count++;
        end

        in = 8'h80;
        expected = 1'b0;
        #1 if (is_zero !== expected) begin
            $display("Wrong result: input: %0h, output: %0b, golden: %0b", in, is_zero, expected);
            error_count++;
        end

        in = '1;
        expected = 1'b0;
        #1 if (is_zero !== expected) begin
            $display("Wrong result: input: %0h, output: %0b, golden: %0b", in, is_zero, expected);
            error_count++;
        end

        if (error_count == 0) begin
            $display("PASS");
        end
        else begin
            $display("FAIL");
        end

        $finish;
    end
endmodule
