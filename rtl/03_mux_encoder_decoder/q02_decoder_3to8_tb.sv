module tb;

    logic       en;
    logic [2:0] sel;
    logic [7:0] out;
    logic [7:0] expected;
    int error_count = 0;

    decoder_3to8 dut_decoder_3to8 (
        .en(en),
        .sel(sel),
        .out(out)
    );

    initial begin
        en = 1'b0;
        sel = 3'd5;
        expected = 8'b0000_0000;
        #1 if (out !== expected) begin
            $display("Wrong result: en: %0b, sel: %0d, output: %0b, golden: %0b",
                     en, sel, out, expected);
            error_count++;
        end

        en = 1'b1;
        sel = 3'd0;
        expected = 8'b0000_0001;
        #1 if (out !== expected) begin
            $display("Wrong result: en: %0b, sel: %0d, output: %0b, golden: %0b",
                     en, sel, out, expected);
            error_count++;
        end

        en = 1'b1;
        sel = 3'd3;
        expected = 8'b0000_1000;
        #1 if (out !== expected) begin
            $display("Wrong result: en: %0b, sel: %0d, output: %0b, golden: %0b",
                     en, sel, out, expected);
            error_count++;
        end

        en = 1'b1;
        sel = 3'd7;
        expected = 8'b1000_0000;
        #1 if (out !== expected) begin
            $display("Wrong result: en: %0b, sel: %0d, output: %0b, golden: %0b",
                     en, sel, out, expected);
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
