module tb;

    parameter DATA_WIDTH = 8;
    parameter DEPTH      = 8;

    logic                  clk;
    logic                  rst;
    logic                  wr_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic                  rd_en;
    logic [DATA_WIDTH-1:0] rd_data;
    logic                  full;
    logic                  empty;
    int                    error_count = 0;

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH     (DEPTH)
    ) dut (
        .clk    (clk),
        .rst    (rst),
        .wr_en  (wr_en),
        .rd_en  (rd_en),
        .wr_data(wr_data),
        .rd_data(rd_data),
        .full   (full),
        .empty  (empty)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic write_fifo(input logic [DATA_WIDTH-1:0] data);
        begin
            wr_en   = 1'b1;
            wr_data = data;
            @(posedge clk) #1;
            wr_en = 1'b0;
        end
    endtask

    task automatic read_fifo(input logic [DATA_WIDTH-1:0] expected);
        begin
            rd_en = 1'b1;
            @(posedge clk) #1;
            if (rd_data !== expected) begin
                error_count++;
                $display("[Mismatch] rd_data=%0h expected=%0h at time %0t",
                         rd_data, expected, $time);
            end
            rd_en = 1'b0;
        end
    endtask

    integer i;

    initial begin
        rst     = 1'b1;
        wr_en   = 1'b0;
        rd_en   = 1'b0;
        wr_data = '0;

        @(posedge clk) #1;
        if (empty !== 1'b1) begin
            error_count++;
            $display("[Mismatch] empty=%0b expected=1 after reset", empty);
        end
        if (full !== 1'b0) begin
            error_count++;
            $display("[Mismatch] full=%0b expected=0 after reset", full);
        end
        rst = 1'b0;

        // Test 1: Write 8 entries (fill the FIFO)
        for (i = 0; i < DEPTH; i++) begin
            write_fifo(i + 1);
        end
        // Check full
        @(posedge clk) #1;
        if (full !== 1'b1) begin
            error_count++;
            $display("[Mismatch] full=%0b expected=1 after filling", full);
        end
        if (empty !== 1'b0) begin
            error_count++;
            $display("[Mismatch] empty=%0b expected=0 after filling", empty);
        end

        // Test 2: Read all 8 entries in FIFO order
        for (i = 0; i < DEPTH; i++) begin
            read_fifo(i + 1);
        end
        // Check empty
        @(posedge clk) #1;
        if (empty !== 1'b1) begin
            error_count++;
            $display("[Mismatch] empty=%0b expected=1 after draining", empty);
        end
        if (full !== 1'b0) begin
            error_count++;
            $display("[Mismatch] full=%0b expected=0 after draining", full);
        end

        // Test 3: Interleaved write and read
        write_fifo(8'hAA);
        write_fifo(8'hBB);
        read_fifo(8'hAA);
        write_fifo(8'hCC);
        read_fifo(8'hBB);
        read_fifo(8'hCC);

        @(posedge clk) #1;
        if (empty !== 1'b1) begin
            error_count++;
            $display("[Mismatch] empty=%0b expected=1 after interleaved", empty);
        end

        if (error_count == 0)
            $display("PASS");

        $finish;
    end

endmodule
