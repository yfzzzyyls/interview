module tb;

    localparam int WIDTH = 8;
    localparam int BIT_IDX = 2;
    localparam logic [WIDTH-1:0] MASK = ~({{(WIDTH-1){1'b0}}, 1'b1} << BIT_IDX);

    logic [WIDTH-1:0] in;
    logic [WIDTH-1:0] out;
    logic [WIDTH-1:0] expected;
    int error_count = 0;

    clear_bit #(
        .WIDTH(WIDTH),
        .BIT_IDX(BIT_IDX)
    ) dut_clear_bit (
        .in(in),
        .out(out)
    );

    initial begin
        in = '0;
        expected = in & MASK;
        #1 if (out !== expected) begin
            $display("Wrong result: input: %0h, output: %0h, golden: %0h", in, out, expected);
            error_count++;
        end

        in = 8'b1010_0101;
        expected = in & MASK;
        #1 if (out !== expected) begin
            $display("Wrong result: input: %0h, output: %0h, golden: %0h", in, out, expected);
            error_count++;
        end

        in = '1;
        expected = in & MASK;
        #1 if (out !== expected) begin
            $display("Wrong result: input: %0h, output: %0h, golden: %0h", in, out, expected);
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
