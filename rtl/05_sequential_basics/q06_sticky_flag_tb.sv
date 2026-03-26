module tb;

    logic clk;
    logic rst;
    logic clr;
    logic event_i;
    logic flag;
    int   error_count = 0;

    sticky_flag dut (
        .clk(clk),
        .rst(rst),
        .clr(clr),
        .event_i(event_i),
        .flag(flag)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_flag(input logic expected_flag);
        if (flag !== expected_flag) begin
            error_count++;
            $display("[Mismatch] [Compute flag]: %0b, [Ref flag]: %0b", flag, expected_flag);
        end
    endtask

    initial begin
        rst     = 1'b1;
        clr     = 1'b0;
        event_i = 1'b0;

        @(posedge clk) #1 check_flag(1'b0);

        rst = 1'b0;

        event_i = 1'b1;
        @(posedge clk) #1 check_flag(1'b1);

        event_i = 1'b0;
        @(posedge clk) #1 check_flag(1'b1);

        clr = 1'b1;
        @(posedge clk) #1 check_flag(1'b0);

        clr     = 1'b1;
        event_i = 1'b1;
        @(posedge clk) #1 check_flag(1'b0);

        clr     = 1'b0;
        event_i = 1'b1;
        @(posedge clk) #1 check_flag(1'b1);

        if (error_count == 0) begin
            $display("PASS");
        end

        $finish;
    end

endmodule
