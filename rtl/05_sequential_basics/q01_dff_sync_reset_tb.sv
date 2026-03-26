module tb;
    localparam int WIDTH = 8;

    logic             clk;
    logic             rst;
    logic [WIDTH-1:0] d;
    logic [WIDTH-1:0] q;

    logic [WIDTH-1:0] expected;

    // init
    dff_sync_reset #(.WIDTH(WIDTH)) dut_dff (
        .clk(clk),
        .rst(rst),
        .d(d),
        .q(q)
    );

    // clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end  

    initial begin
        d = '0;
        rst = 1'b1;
        repeat(2) @(posedge clk);
        rst = 1'b0;
        d = $urandom_range(8'hFF, 8'h00);
        @(posedge clk);
        if (q != d) begin 
            $display("FAIL");
        end
        else begin
            $display("PASS");
        end
        $finish;
    end

endmodule