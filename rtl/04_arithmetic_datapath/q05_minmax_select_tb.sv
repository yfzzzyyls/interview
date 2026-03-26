module tb;

    localparam int WIDTH = 8;

    logic [WIDTH-1:0] a;
    logic [WIDTH-1:0] b;
    logic [WIDTH-1:0] min_val;
    logic [WIDTH-1:0] max_val;
    logic [WIDTH-1:0] expected_min;
    logic [WIDTH-1:0] expected_max;
    int error_count = 0;

    minmax_select #(
        .WIDTH(WIDTH)
    ) dut_minmax_select (
        .a(a),
        .b(b),
        .min_val(min_val),
        .max_val(max_val)
    );

    initial begin
        a = 8'h09;
        b = 8'h03;
        expected_min = 8'h03;
        expected_max = 8'h09;
        #1 if ({min_val, max_val} !== {expected_min, expected_max}) begin
            $display("Wrong result: a: %0h, b: %0h, output: min=%0h max=%0h, golden: min=%0h max=%0h",
                     a, b, min_val, max_val, expected_min, expected_max);
            error_count++;
        end

        a = 8'h03;
        b = 8'h09;
        expected_min = 8'h03;
        expected_max = 8'h09;
        #1 if ({min_val, max_val} !== {expected_min, expected_max}) begin
            $display("Wrong result: a: %0h, b: %0h, output: min=%0h max=%0h, golden: min=%0h max=%0h",
                     a, b, min_val, max_val, expected_min, expected_max);
            error_count++;
        end

        a = 8'h55;
        b = 8'h55;
        expected_min = 8'h55;
        expected_max = 8'h55;
        #1 if ({min_val, max_val} !== {expected_min, expected_max}) begin
            $display("Wrong result: a: %0h, b: %0h, output: min=%0h max=%0h, golden: min=%0h max=%0h",
                     a, b, min_val, max_val, expected_min, expected_max);
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
