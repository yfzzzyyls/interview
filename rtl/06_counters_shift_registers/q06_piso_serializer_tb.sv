module tb;

    localparam int WIDTH = 8;

    logic             clk;
    logic             rst;
    logic             load;
    logic             shift_en;
    logic [WIDTH-1:0] parallel_in;
    logic             serial_out;
    logic             busy;
    int               error_count = 0;

    piso_serializer #(
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .load(load),
        .shift_en(shift_en),
        .parallel_in(parallel_in),
        .serial_out(serial_out),
        .busy(busy)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_outputs(
        input logic expected_serial_out,
        input logic expected_busy
    );
        begin
            if (serial_out !== expected_serial_out || busy !== expected_busy) begin
                error_count++;
                $display(
                    "[Mismatch] [Compute serial_out]: %0b, [Ref serial_out]: %0b, [Compute busy]: %0b, [Ref busy]: %0b",
                    serial_out, expected_serial_out, busy, expected_busy
                );
            end
        end
    endtask

    initial begin
        rst         = 1'b1;
        load        = 1'b0;
        shift_en    = 1'b0;
        parallel_in = '0;

        @(posedge clk) #1 check_outputs(1'b0, 1'b0);

        rst         = 1'b0;
        load        = 1'b1;
        parallel_in = 8'hA6; // LSB-first sequence: 0,1,1,0,0,1,0,1
        @(posedge clk) #1 check_outputs(1'b0, 1'b1);

        load     = 1'b0;
        shift_en = 1'b0;
        @(posedge clk) #1 check_outputs(1'b0, 1'b1);

        shift_en = 1'b1;
        @(posedge clk) #1 check_outputs(1'b1, 1'b1);
        @(posedge clk) #1 check_outputs(1'b1, 1'b1);
        @(posedge clk) #1 check_outputs(1'b0, 1'b1);
        @(posedge clk) #1 check_outputs(1'b0, 1'b1);
        @(posedge clk) #1 check_outputs(1'b1, 1'b1);
        @(posedge clk) #1 check_outputs(1'b0, 1'b1);
        @(posedge clk) #1 check_outputs(1'b1, 1'b1);
        @(posedge clk) #1 check_outputs(1'b0, 1'b0);

        if (error_count == 0) begin
            $display("PASS");
        end

        $finish;
    end

endmodule
