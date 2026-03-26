module tb;

    localparam int WIDTH = 8;
    localparam logic [WIDTH-1:0] MAX_VAL = 8'h9F;

    logic [WIDTH-1:0] in;
    logic [WIDTH-1:0] out;
    logic [WIDTH-1:0] expected;
    int error_count = 0;

    clamp_max #(
        .WIDTH(WIDTH),
        .MAX_VAL(MAX_VAL)
    ) dut_clamp_max (
        .in(in),
        .out(out)
    );

    initial begin
        in = 8'h20;
        expected = 8'h20;
        #1 if (out !== expected) begin
            $display("Wrong result: in: %0h, output: %0h, golden: %0h", in, out, expected);
            error_count++;
        end

        in = 8'h9F;
        expected = 8'h9F;
        #1 if (out !== expected) begin
            $display("Wrong result: in: %0h, output: %0h, golden: %0h", in, out, expected);
            error_count++;
        end

        in = 8'hC4;
        expected = 8'h9F;
        #1 if (out !== expected) begin
            $display("Wrong result: in: %0h, output: %0h, golden: %0h", in, out, expected);
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
