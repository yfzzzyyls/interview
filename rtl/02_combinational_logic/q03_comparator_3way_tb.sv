module tb;

    localparam int WIDTH = 8;

    logic [WIDTH-1:0] a;
    logic [WIDTH-1:0] b;
    logic             lt;
    logic             eq;
    logic             gt;
    logic             expected_lt;
    logic             expected_eq;
    logic             expected_gt;
    int error_count = 0;

    comparator_3way #(
        .WIDTH(WIDTH)
    ) dut_comparator_3way (
        .a(a),
        .b(b),
        .lt(lt),
        .eq(eq),
        .gt(gt)
    );

    initial begin
        a = 8'h10;
        b = 8'h20;
        expected_lt = 1'b1;
        expected_eq = 1'b0;
        expected_gt = 1'b0;
        #1 if ({lt, eq, gt} !== {expected_lt, expected_eq, expected_gt}) begin
            $display("Wrong result: a: %0h, b: %0h, output: %0b%0b%0b, golden: %0b%0b%0b",
                     a, b, lt, eq, gt, expected_lt, expected_eq, expected_gt);
            error_count++;
        end

        a = 8'h55;
        b = 8'h55;
        expected_lt = 1'b0;
        expected_eq = 1'b1;
        expected_gt = 1'b0;
        #1 if ({lt, eq, gt} !== {expected_lt, expected_eq, expected_gt}) begin
            $display("Wrong result: a: %0h, b: %0h, output: %0b%0b%0b, golden: %0b%0b%0b",
                     a, b, lt, eq, gt, expected_lt, expected_eq, expected_gt);
            error_count++;
        end

        a = 8'hF0;
        b = 8'h0F;
        expected_lt = 1'b0;
        expected_eq = 1'b0;
        expected_gt = 1'b1;
        #1 if ({lt, eq, gt} !== {expected_lt, expected_eq, expected_gt}) begin
            $display("Wrong result: a: %0h, b: %0h, output: %0b%0b%0b, golden: %0b%0b%0b",
                     a, b, lt, eq, gt, expected_lt, expected_eq, expected_gt);
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
