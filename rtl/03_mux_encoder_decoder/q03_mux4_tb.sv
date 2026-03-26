module tb;

    localparam int WIDTH = 8;

    logic [WIDTH-1:0] d0;
    logic [WIDTH-1:0] d1;
    logic [WIDTH-1:0] d2;
    logic [WIDTH-1:0] d3;
    logic [1:0]       sel;
    logic [WIDTH-1:0] out;
    logic [WIDTH-1:0] expected;
    int error_count = 0;

    mux4 #(
        .WIDTH(WIDTH)
    ) dut_mux4 (
        .d0(d0),
        .d1(d1),
        .d2(d2),
        .d3(d3),
        .sel(sel),
        .out(out)
    );

    initial begin
        d0 = 8'h11;
        d1 = 8'h22;
        d2 = 8'h44;
        d3 = 8'h88;

        sel = 2'd0;
        expected = d0;
        #1 if (out !== expected) begin
            $display("Wrong result: sel: %0d, output: %0h, golden: %0h", sel, out, expected);
            error_count++;
        end

        sel = 2'd1;
        expected = d1;
        #1 if (out !== expected) begin
            $display("Wrong result: sel: %0d, output: %0h, golden: %0h", sel, out, expected);
            error_count++;
        end

        sel = 2'd2;
        expected = d2;
        #1 if (out !== expected) begin
            $display("Wrong result: sel: %0d, output: %0h, golden: %0h", sel, out, expected);
            error_count++;
        end

        sel = 2'd3;
        expected = d3;
        #1 if (out !== expected) begin
            $display("Wrong result: sel: %0d, output: %0h, golden: %0h", sel, out, expected);
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
