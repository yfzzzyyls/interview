module tb;

    localparam int WIDTH = 8;

    logic             clk;
    logic             rst;
    logic             load;
    logic             shift_en;
    logic             serial_in;
    logic [WIDTH-1:0] parallel_in;
    logic [WIDTH-1:0] q;
    int               error_count = 0;

    loadable_shift_register #(
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .load(load),
        .shift_en(shift_en),
        .serial_in(serial_in),
        .parallel_in(parallel_in),
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
        rst         = 1'b1;
        load        = 1'b0;
        shift_en    = 1'b0;
        serial_in   = 1'b0;
        parallel_in = '0;

        @(posedge clk) #1 check_q('0);

        rst         = 1'b0;
        load        = 1'b1;
        parallel_in = 8'hA5;
        @(posedge clk) #1 check_q(8'hA5);

        load      = 1'b0;
        shift_en  = 1'b1;
        serial_in = 1'b1;
        @(posedge clk) #1 check_q(8'h4B);

        serial_in = 1'b0;
        @(posedge clk) #1 check_q(8'h96);

        shift_en = 1'b0;
        @(posedge clk) #1 check_q(8'h96);

        load        = 1'b1;
        parallel_in = 8'h3C;
        @(posedge clk) #1 check_q(8'h3C);

        rst = 1'b1;
        @(posedge clk) #1 check_q('0);

        if (error_count == 0) begin
            $display("PASS");
        end

        $finish;
    end

endmodule
