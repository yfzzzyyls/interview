module tb;

    localparam int WIDTH = 4;

    logic             clk;
    logic             rst;
    logic [WIDTH-1:0] q;
    int               error_count = 0;

    johnson_counter #(
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .q(q)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_q(input logic [WIDTH-1:0] expected_q);
        if (q !== expected_q) begin
            error_count++;
            $display("[Mismatch] [Compute Q]: %0b, [Ref Q]: %0b", q, expected_q);
        end
    endtask

    initial begin
        rst = 1'b1;

        @(posedge clk) #1 check_q(4'b0000);

        rst = 1'b0;
        @(posedge clk) #1 check_q(4'b0001);
        @(posedge clk) #1 check_q(4'b0011);
        @(posedge clk) #1 check_q(4'b0111);
        @(posedge clk) #1 check_q(4'b1111);
        @(posedge clk) #1 check_q(4'b1110);
        @(posedge clk) #1 check_q(4'b1100);
        @(posedge clk) #1 check_q(4'b1000);
        @(posedge clk) #1 check_q(4'b0000);

        if (error_count == 0) begin
            $display("PASS");
        end

        $finish;
    end

endmodule
