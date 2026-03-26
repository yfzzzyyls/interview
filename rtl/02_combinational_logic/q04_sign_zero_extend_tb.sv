module tb;

    localparam int IN_WIDTH  = 8;
    localparam int OUT_WIDTH = 16;

    logic [IN_WIDTH-1:0]  in;
    logic                 sign_ext;
    logic [OUT_WIDTH-1:0] out;
    logic [OUT_WIDTH-1:0] expected;
    int error_count = 0;

    sign_zero_extend #(
        .IN_WIDTH(IN_WIDTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) dut_sign_zero_extend (
        .in(in),
        .sign_ext(sign_ext),
        .out(out)
    );

    initial begin
        in = 8'h80;
        sign_ext = 1'b1;
        expected = 16'hFF80;
        #1 if (out !== expected) begin
            $display("Wrong result: in: %0h, sign_ext: %0b, output: %0h, golden: %0h",
                     in, sign_ext, out, expected);
            error_count++;
        end

        in = 8'h80;
        sign_ext = 1'b0;
        expected = 16'h0080;
        #1 if (out !== expected) begin
            $display("Wrong result: in: %0h, sign_ext: %0b, output: %0h, golden: %0h",
                     in, sign_ext, out, expected);
            error_count++;
        end

        in = 8'h7F;
        sign_ext = 1'b1;
        expected = 16'h007F;
        #1 if (out !== expected) begin
            $display("Wrong result: in: %0h, sign_ext: %0b, output: %0h, golden: %0h",
                     in, sign_ext, out, expected);
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
