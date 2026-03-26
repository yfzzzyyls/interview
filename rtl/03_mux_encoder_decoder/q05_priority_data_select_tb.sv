module tb;

    localparam int WIDTH = 8;

    logic [3:0]       req;
    logic [WIDTH-1:0] d0;
    logic [WIDTH-1:0] d1;
    logic [WIDTH-1:0] d2;
    logic [WIDTH-1:0] d3;
    logic             valid;
    logic [WIDTH-1:0] out;
    logic             expected_valid;
    logic [WIDTH-1:0] expected_out;
    int error_count = 0;

    priority_data_select #(
        .WIDTH(WIDTH)
    ) dut_priority_data_select (
        .req(req),
        .d0(d0),
        .d1(d1),
        .d2(d2),
        .d3(d3),
        .valid(valid),
        .out(out)
    );

    initial begin
        d0 = 8'h11;
        d1 = 8'h22;
        d2 = 8'h44;
        d3 = 8'h88;

        req = 4'b0000;
        expected_valid = 1'b0;
        expected_out = '0;
        #1 if ({valid, out} !== {expected_valid, expected_out}) begin
            $display("Wrong result: req: %0b, output: valid=%0b out=%0h, golden: valid=%0b out=%0h",
                     req, valid, out, expected_valid, expected_out);
            error_count++;
        end

        req = 4'b0001;
        expected_valid = 1'b1;
        expected_out = d0;
        #1 if ({valid, out} !== {expected_valid, expected_out}) begin
            $display("Wrong result: req: %0b, output: valid=%0b out=%0h, golden: valid=%0b out=%0h",
                     req, valid, out, expected_valid, expected_out);
            error_count++;
        end

        req = 4'b0101;
        expected_valid = 1'b1;
        expected_out = d2;
        #1 if ({valid, out} !== {expected_valid, expected_out}) begin
            $display("Wrong result: req: %0b, output: valid=%0b out=%0h, golden: valid=%0b out=%0h",
                     req, valid, out, expected_valid, expected_out);
            error_count++;
        end

        req = 4'b1010;
        expected_valid = 1'b1;
        expected_out = d3;
        #1 if ({valid, out} !== {expected_valid, expected_out}) begin
            $display("Wrong result: req: %0b, output: valid=%0b out=%0h, golden: valid=%0b out=%0h",
                     req, valid, out, expected_valid, expected_out);
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
