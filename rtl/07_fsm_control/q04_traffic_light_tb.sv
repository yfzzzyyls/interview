module tb;

    logic       clk;
    logic       rst;
    logic [1:0] light;
    int         error_count = 0;

    localparam GREEN_TICKS  = 5;
    localparam YELLOW_TICKS = 2;
    localparam RED_TICKS    = 5;

    traffic_light #(
        .GREEN_TICKS (GREEN_TICKS),
        .YELLOW_TICKS(YELLOW_TICKS),
        .RED_TICKS   (RED_TICKS)
    ) dut (
        .clk  (clk),
        .rst  (rst),
        .light(light)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_light(
        input logic [1:0] expected,
        input string      name
    );
        begin
            @(posedge clk) #1;
            if (light !== expected) begin
                error_count++;
                $display("[Mismatch] %s: light=%0b expected=%0b at time %0t",
                         name, light, expected, $time);
            end
        end
    endtask

    integer i;

    initial begin
        rst = 1'b1;
        @(posedge clk) #1;
        if (light !== 2'b00) begin
            error_count++;
            $display("[Mismatch] reset: light=%0b expected=00", light);
        end
        rst = 1'b0;

        // GREEN for GREEN_TICKS cycles
        for (i = 0; i < GREEN_TICKS - 1; i++) begin
            check_light(2'b00, "GREEN");
        end

        // YELLOW for YELLOW_TICKS cycles
        for (i = 0; i < YELLOW_TICKS; i++) begin
            check_light(2'b01, "YELLOW");
        end

        // RED for RED_TICKS cycles
        for (i = 0; i < RED_TICKS; i++) begin
            check_light(2'b10, "RED");
        end

        // Back to GREEN
        check_light(2'b00, "GREEN_2nd");

        if (error_count == 0)
            $display("PASS");

        $finish;
    end

endmodule
