module tb;

    logic [7:0] in;
    logic       valid;
    logic [2:0] code;
    logic       expected_valid;
    logic [2:0] expected_code;
    int error_count = 0;

    encoder_8to3 dut_encoder_8to3 (
        .in(in),
        .valid(valid),
        .code(code)
    );

    initial begin
        in = 8'b0000_0000;
        expected_valid = 1'b0;
        expected_code = 3'd0;
        #1 if ({valid, code} !== {expected_valid, expected_code}) begin
            $display("Wrong result: in: %0b, output: valid=%0b code=%0d, golden: valid=%0b code=%0d",
                     in, valid, code, expected_valid, expected_code);
            error_count++;
        end

        in = 8'b0000_0001;
        expected_valid = 1'b1;
        expected_code = 3'd0;
        #1 if ({valid, code} !== {expected_valid, expected_code}) begin
            $display("Wrong result: in: %0b, output: valid=%0b code=%0d, golden: valid=%0b code=%0d",
                     in, valid, code, expected_valid, expected_code);
            error_count++;
        end

        in = 8'b0001_0000;
        expected_valid = 1'b1;
        expected_code = 3'd4;
        #1 if ({valid, code} !== {expected_valid, expected_code}) begin
            $display("Wrong result: in: %0b, output: valid=%0b code=%0d, golden: valid=%0b code=%0d",
                     in, valid, code, expected_valid, expected_code);
            error_count++;
        end

        in = 8'b1000_0000;
        expected_valid = 1'b1;
        expected_code = 3'd7;
        #1 if ({valid, code} !== {expected_valid, expected_code}) begin
            $display("Wrong result: in: %0b, output: valid=%0b code=%0d, golden: valid=%0b code=%0d",
                     in, valid, code, expected_valid, expected_code);
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
