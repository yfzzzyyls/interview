module tb;

    localparam int WIDTH = 8;

    logic [WIDTH-1:0] a;
    logic [WIDTH-1:0] b;
    logic             bin;
    logic [WIDTH-1:0] diff;
    logic             bout;
    logic [WIDTH-1:0] expected_diff;
    logic             expected_bout;
    int error_count = 0;

    subtractor_borrow #(
        .WIDTH(WIDTH)
    ) dut_subtractor_borrow (
        .a(a),
        .b(b),
        .bin(bin),
        .diff(diff),
        .bout(bout)
    );

    initial begin
        a = 8'h05;
        b = 8'h02;
        bin = 1'b0;
        expected_diff = 8'h03;
        expected_bout = 1'b0;
        #1 if ({bout, diff} !== {expected_bout, expected_diff}) begin
            $display("Wrong result: a: %0h, b: %0h, bin: %0b, output: bout=%0b diff=%0h, golden: bout=%0b diff=%0h",
                     a, b, bin, bout, diff, expected_bout, expected_diff);
            error_count++;
        end

        a = 8'h00;
        b = 8'h01;
        bin = 1'b0;
        expected_diff = 8'hFF;
        expected_bout = 1'b1;
        #1 if ({bout, diff} !== {expected_bout, expected_diff}) begin
            $display("Wrong result: a: %0h, b: %0h, bin: %0b, output: bout=%0b diff=%0h, golden: bout=%0b diff=%0h",
                     a, b, bin, bout, diff, expected_bout, expected_diff);
            error_count++;
        end

        a = 8'h10;
        b = 8'h0F;
        bin = 1'b1;
        expected_diff = 8'h00;
        expected_bout = 1'b0;
        #1 if ({bout, diff} !== {expected_bout, expected_diff}) begin
            $display("Wrong result: a: %0h, b: %0h, bin: %0b, output: bout=%0b diff=%0h, golden: bout=%0b diff=%0h",
                     a, b, bin, bout, diff, expected_bout, expected_diff);
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
