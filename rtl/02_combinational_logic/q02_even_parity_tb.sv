module tb;

    localparam int WIDTH = 8;

    logic [WIDTH-1:0] in;
    logic             parity;
    logic             expected;
    int error_count = 0;

    even_parity #(
        .WIDTH(WIDTH)
    ) dut_even_parity (
        .in(in),
        .parity(parity)
    );

    initial begin
        in = '0;
        expected = 1'b0;
        #1 if (parity !== expected) begin
            $display("Wrong result: input: %0h, output: %0b, golden: %0b", in, parity, expected);
            error_count++;
        end

        in = 8'b0000_0001;
        expected = 1'b1;
        #1 if (parity !== expected) begin
            $display("Wrong result: input: %0h, output: %0b, golden: %0b", in, parity, expected);
            error_count++;
        end

        in = 8'b1010_0101;
        expected = 1'b0;
        #1 if (parity !== expected) begin
            $display("Wrong result: input: %0h, output: %0b, golden: %0b", in, parity, expected);
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
