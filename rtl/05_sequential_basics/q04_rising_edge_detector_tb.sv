module tb;

    logic clk;
    logic rst;
    logic sig;
    logic pulse;
    int   error_count = 0;

    rising_edge_detector dut (
        .clk(clk),
        .rst(rst),
        .sig(sig),
        .pulse(pulse)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_pulse(input logic expected_pulse);
        if (pulse !== expected_pulse) begin
            error_count++;
            $display("[Mismatch] [Compute pulse]: %0b, [Ref pulse]: %0b", pulse, expected_pulse);
        end
    endtask

    initial begin
        rst = 1'b1;
        sig = 1'b0;

        @(posedge clk) #1 check_pulse(1'b0);

        rst = 1'b0;

        sig = 1'b0;
        @(posedge clk) #1 check_pulse(1'b0);

        sig = 1'b1;
        @(posedge clk) #1 check_pulse(1'b1);

        sig = 1'b1;
        @(posedge clk) #1 check_pulse(1'b0);

        sig = 1'b0;
        @(posedge clk) #1 check_pulse(1'b0);

        sig = 1'b1;
        @(posedge clk) #1 check_pulse(1'b1);

        if (error_count == 0) begin
            $display("PASS");
        end

        $finish;
    end

endmodule
