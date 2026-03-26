module tb;

    localparam int WIDTH = 8;

    logic [WIDTH-1:0] a;
    logic [WIDTH-1:0] b;
    logic [WIDTH-1:0] sum;
    logic [WIDTH-1:0] expected_sum;
    int error_count = 0;

    saturating_add #(
        .WIDTH(WIDTH)
    ) dut_saturating_add (
        .a(a),
        .b(b),
        .sum(sum)
    );

    initial begin
        a = 8'h01;
        b = 8'h02;
        expected_sum = 8'h03;
        #1 if (sum !== expected_sum) begin
            $display("Wrong result: a: %0h, b: %0h, output: %0h, golden: %0h",
                     a, b, sum, expected_sum);
            error_count++;
        end

        a = 8'hFE;
        b = 8'h01;
        expected_sum = 8'hFF;
        #1 if (sum !== expected_sum) begin
            $display("Wrong result: a: %0h, b: %0h, output: %0h, golden: %0h",
                     a, b, sum, expected_sum);
            error_count++;
        end

        a = 8'hFF;
        b = 8'h01;
        expected_sum = 8'hFF;
        #1 if (sum !== expected_sum) begin
            $display("Wrong result: a: %0h, b: %0h, output: %0h, golden: %0h",
                     a, b, sum, expected_sum);
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
