module tb;

    localparam int WIDTH = 8;

    logic [WIDTH-1:0] a;
    logic [WIDTH-1:0] b;
    logic [WIDTH-1:0] diff;
    logic [WIDTH-1:0] expected_diff;
    int error_count = 0;

    abs_diff #(
        .WIDTH(WIDTH)
    ) dut_abs_diff (
        .a(a),
        .b(b),
        .diff(diff)
    );

    initial begin
        a = 8'h09;
        b = 8'h03;
        expected_diff = 8'h06;
        #1 if (diff !== expected_diff) begin
            $display("Wrong result: a: %0h, b: %0h, output: %0h, golden: %0h",
                     a, b, diff, expected_diff);
            error_count++;
        end

        a = 8'h03;
        b = 8'h09;
        expected_diff = 8'h06;
        #1 if (diff !== expected_diff) begin
            $display("Wrong result: a: %0h, b: %0h, output: %0h, golden: %0h",
                     a, b, diff, expected_diff);
            error_count++;
        end

        a = 8'h55;
        b = 8'h55;
        expected_diff = 8'h00;
        #1 if (diff !== expected_diff) begin
            $display("Wrong result: a: %0h, b: %0h, output: %0h, golden: %0h",
                     a, b, diff, expected_diff);
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
