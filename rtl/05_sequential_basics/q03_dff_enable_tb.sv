module tb;

    localparam int WIDTH = 8;

    logic             clk;
    logic             en;
    logic [WIDTH-1:0] d;
    logic [WIDTH-1:0] q;
    int               error_count = 0;

    dff_enable #(
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .en(en),
        .d(d),
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
        en = 1'b1;
        d  = 8'h12;

        @(posedge clk) #1 check_q(8'h12);

        en = 1'b0;
        d  = 8'h34;
        @(posedge clk) #1 check_q(8'h12);

        en = 1'b1;
        d  = 8'hA5;
        @(posedge clk) #1 check_q(8'hA5);

        en = 1'b0;
        d  = 8'h5A;
        @(posedge clk) #1 check_q(8'hA5);

        if (error_count == 0) begin
            $display("PASS");
        end

        $finish;
    end

endmodule
