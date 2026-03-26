module tb;

    logic clk;
    logic rst;
    logic bit_in;
    logic detect;
    int   error_count = 0;

    seq_detect_101 dut (
        .clk(clk),
        .rst(rst),
        .bit_in(bit_in),
        .detect(detect)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic drive_and_check(
        input logic bit_val,
        input logic expected_detect
    );
        begin
            bit_in = bit_val;
            @(posedge clk) #1;
            if (detect !== expected_detect) begin
                error_count++;
                $display(
                    "[Mismatch] bit_in=%0b detect=%0b expected=%0b",
                    bit_val, detect, expected_detect
                );
            end
        end
    endtask

    initial begin
        rst    = 1'b1;
        bit_in = 1'b0;

        @(posedge clk) #1;
        if (detect !== 1'b0) begin
            error_count++;
            $display("[Mismatch] detect=%0b expected=0 during reset", detect);
        end

        rst = 1'b0;

        // Stream: 1 0 1 0 1 1 0 0 1
        // Detect: 0 0 1 0 1 0 0 0 0
        drive_and_check(1'b1, 1'b0);
        drive_and_check(1'b0, 1'b0);
        drive_and_check(1'b1, 1'b1);
        drive_and_check(1'b0, 1'b0);
        drive_and_check(1'b1, 1'b1);
        drive_and_check(1'b1, 1'b0);
        drive_and_check(1'b0, 1'b0);
        drive_and_check(1'b0, 1'b0);
        drive_and_check(1'b1, 1'b0);

        if (error_count == 0) begin
            $display("PASS");
        end

        $finish;
    end

endmodule
