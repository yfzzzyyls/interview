module tb;

    localparam int WIDTH = 8;

    logic             clk;
    logic             rst;
    logic             serial_in;
    logic [WIDTH-1:0] q;
    int               error_count = 0;

    shift_register #(
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .serial_in(serial_in),
        .q(q)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_q(input logic [WIDTH-1:0] expected_q);
        if (q !== expected_q) begin
            error_count++;
            $display("[Mismatch] [Compute Q]: %0h, [Ref Q]: %0h", q, expected_q);
        end
    endtask

    initial begin
        rst       = 1'b1;
        serial_in = 1'b0;

        @(posedge clk) #1 check_q('0);

        rst       = 1'b0;
        serial_in = 1'b1;
        @(posedge clk) #1 check_q(8'h01);

        serial_in = 1'b0;
        @(posedge clk) #1 check_q(8'h02);

        serial_in = 1'b1;
        @(posedge clk) #1 check_q(8'h05);

        serial_in = 1'b1;
        @(posedge clk) #1 check_q(8'h0B);

        rst = 1'b1;
        @(posedge clk) #1 check_q('0);

        if (error_count == 0) begin
            $display("PASS");
        end

        $finish;
    end

endmodule
