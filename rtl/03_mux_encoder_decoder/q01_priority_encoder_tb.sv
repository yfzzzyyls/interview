module tb;

    logic [7:0] req;
    logic       valid;
    logic [2:0] idx;
    logic       expected_valid;
    logic [2:0] expected_idx;
    int error_count = 0;

    priority_encoder dut_priority_encoder (
        .req(req),
        .valid(valid),
        .idx(idx)
    );

    initial begin
        req = 8'b0000_0000;
        expected_valid = 1'b0;
        expected_idx = 3'd0;
        #1 if ({valid, idx} !== {expected_valid, expected_idx}) begin
            $display("Wrong result: req: %0b, output: valid=%0b idx=%0d, golden: valid=%0b idx=%0d",
                     req, valid, idx, expected_valid, expected_idx);
            error_count++;
        end

        req = 8'b0001_0100;
        expected_valid = 1'b1;
        expected_idx = 3'd4;
        #1 if ({valid, idx} !== {expected_valid, expected_idx}) begin
            $display("Wrong result: req: %0b, output: valid=%0b idx=%0d, golden: valid=%0b idx=%0d",
                     req, valid, idx, expected_valid, expected_idx);
            error_count++;
        end

        req = 8'b1001_0001;
        expected_valid = 1'b1;
        expected_idx = 3'd7;
        #1 if ({valid, idx} !== {expected_valid, expected_idx}) begin
            $display("Wrong result: req: %0b, output: valid=%0b idx=%0d, golden: valid=%0b idx=%0d",
                     req, valid, idx, expected_valid, expected_idx);
            error_count++;
        end

        req = 8'b0010_0000;
        expected_valid = 1'b1;
        expected_idx = 3'd5;
        #1 if ({valid, idx} !== {expected_valid, expected_idx}) begin
            $display("Wrong result: req: %0b, output: valid=%0b idx=%0d, golden: valid=%0b idx=%0d",
                     req, valid, idx, expected_valid, expected_idx);
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
