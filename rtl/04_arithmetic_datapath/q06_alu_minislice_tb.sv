module tb;

    localparam int WIDTH = 8;

    logic [WIDTH-1:0] a;
    logic [WIDTH-1:0] b;
    logic [1:0]       op;
    logic [WIDTH-1:0] y;
    logic             carry_borrow;
    logic             is_zero;
    logic [WIDTH-1:0] expected_y;
    logic             expected_cb;
    logic             expected_zero;
    int error_count = 0;

    alu_minislice #(
        .WIDTH(WIDTH)
    ) dut_alu_minislice (
        .a(a),
        .b(b),
        .op(op),
        .y(y),
        .carry_borrow(carry_borrow),
        .is_zero(is_zero)
    );

    initial begin
        op = 2'd0;
        a = 8'hFF;
        b = 8'h01;
        expected_y = 8'h00;
        expected_cb = 1'b1;
        expected_zero = 1'b1;
        #1 if ({y, carry_borrow, is_zero} !== {expected_y, expected_cb, expected_zero}) begin
            $display("Wrong result: op=%0d a=%0h b=%0h output: y=%0h cb=%0b z=%0b golden: y=%0h cb=%0b z=%0b",
                     op, a, b, y, carry_borrow, is_zero, expected_y, expected_cb, expected_zero);
            error_count++;
        end

        op = 2'd1;
        a = 8'h03;
        b = 8'h05;
        expected_y = 8'hFE;
        expected_cb = 1'b1;
        expected_zero = 1'b0;
        #1 if ({y, carry_borrow, is_zero} !== {expected_y, expected_cb, expected_zero}) begin
            $display("Wrong result: op=%0d a=%0h b=%0h output: y=%0h cb=%0b z=%0b golden: y=%0h cb=%0b z=%0b",
                     op, a, b, y, carry_borrow, is_zero, expected_y, expected_cb, expected_zero);
            error_count++;
        end

        op = 2'd2;
        a = 8'h09;
        b = 8'h03;
        expected_y = 8'h03;
        expected_cb = 1'b0;
        expected_zero = 1'b0;
        #1 if ({y, carry_borrow, is_zero} !== {expected_y, expected_cb, expected_zero}) begin
            $display("Wrong result: op=%0d a=%0h b=%0h output: y=%0h cb=%0b z=%0b golden: y=%0h cb=%0b z=%0b",
                     op, a, b, y, carry_borrow, is_zero, expected_y, expected_cb, expected_zero);
            error_count++;
        end

        op = 2'd3;
        a = 8'h09;
        b = 8'h03;
        expected_y = 8'h09;
        expected_cb = 1'b0;
        expected_zero = 1'b0;
        #1 if ({y, carry_borrow, is_zero} !== {expected_y, expected_cb, expected_zero}) begin
            $display("Wrong result: op=%0d a=%0h b=%0h output: y=%0h cb=%0b z=%0b golden: y=%0h cb=%0b z=%0b",
                     op, a, b, y, carry_borrow, is_zero, expected_y, expected_cb, expected_zero);
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
