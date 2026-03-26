module tb;

    localparam int WIDTH = 8;

    logic [WIDTH-1:0] a;
    logic [WIDTH-1:0] b;
    logic             cin;
    logic [WIDTH-1:0] sum;
    logic             cout;
    logic [WIDTH-1:0] expected_sum;
    logic             expected_cout;
    int error_count = 0;

    adder_carry #(
        .WIDTH(WIDTH)
    ) dut_adder_carry (
        .a(a),
        .b(b),
        .cin(cin),
        .sum(sum),
        .cout(cout)
    );

    initial begin
        a = 8'h01;
        b = 8'h02;
        cin = 1'b0;
        expected_sum = 8'h03;
        expected_cout = 1'b0;
        #1 if ({cout, sum} !== {expected_cout, expected_sum}) begin
            $display("Wrong result: a: %0h, b: %0h, cin: %0b, output: cout=%0b sum=%0h, golden: cout=%0b sum=%0h",
                     a, b, cin, cout, sum, expected_cout, expected_sum);
            error_count++;
        end

        a = 8'hFF;
        b = 8'h01;
        cin = 1'b0;
        expected_sum = 8'h00;
        expected_cout = 1'b1;
        #1 if ({cout, sum} !== {expected_cout, expected_sum}) begin
            $display("Wrong result: a: %0h, b: %0h, cin: %0b, output: cout=%0b sum=%0h, golden: cout=%0b sum=%0h",
                     a, b, cin, cout, sum, expected_cout, expected_sum);
            error_count++;
        end

        a = 8'h0F;
        b = 8'h00;
        cin = 1'b1;
        expected_sum = 8'h10;
        expected_cout = 1'b0;
        #1 if ({cout, sum} !== {expected_cout, expected_sum}) begin
            $display("Wrong result: a: %0h, b: %0h, cin: %0b, output: cout=%0b sum=%0h, golden: cout=%0b sum=%0h",
                     a, b, cin, cout, sum, expected_cout, expected_sum);
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
