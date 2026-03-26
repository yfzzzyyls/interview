module tb;

    localparam int WIDTH = 8;

    logic             clk;
    logic             rst;
    logic [WIDTH-1:0] count;
    int               error_count = 0;

    up_counter #(
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .count(count)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_count(input logic [WIDTH-1:0] expected_count);
        if (count !== expected_count) begin
            error_count++;
            $display("[Mismatch] [Compute count]: %0h, [Ref count]: %0h", count, expected_count);
        end
    endtask

    initial begin
        rst = 1'b1;

        @(posedge clk) #1 check_count('0);

        rst = 1'b0;
        @(posedge clk) #1 check_count(8'h01);
        @(posedge clk) #1 check_count(8'h02);
        @(posedge clk) #1 check_count(8'h03);

        rst = 1'b1;
        @(posedge clk) #1 check_count('0);

        rst = 1'b0;
        @(posedge clk) #1 check_count(8'h01);

        if (error_count == 0) begin
            $display("PASS");
        end

        $finish;
    end

endmodule
