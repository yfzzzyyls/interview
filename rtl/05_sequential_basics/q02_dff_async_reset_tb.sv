module tb;

    localparam int WIDTH = 8;

    logic             clk;
    logic             rst_n;
    logic [WIDTH-1:0] d;
    logic [WIDTH-1:0] q;
    int               error_count = 0;
    logic pass;
    dff_async_reset #(
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .d(d),
        .q(q)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_q( input logic [WIDTH-1:0] expected_q, output logic pass);
        if(q != expected_q) begin 
            error_count++;
            pass = 1'b0;
            display(q, expected_q);
        end
        else begin 
            pass = 1'b1;
        end        
    endtask

    function void display( input logic [WIDTH-1:0] q, input logic [WIDTH-1:0] expected_q);
        $display("[Mismatch] [Compute Q]: %0d, [Ref Q]: %0d", q, expected_q);
    endfunction

    initial begin
        d     = '0;
        rst_n = 1'b0;

        #1;
        check_q('0, pass);

        rst_n = 1'b1;
        d     = 8'hA5;
        @(posedge clk);
        #1;
        check_q(8'hA5, pass);

        d = 8'h3C;
        @(posedge clk);
        #1;
        check_q(8'h3C, pass);

        d     = 8'hFF;
        rst_n = 1'b0;
        #1;
        check_q('0, pass);

        rst_n = 1'b1;
        d     = 8'h81;
        @(posedge clk);
        #1;
        check_q(8'h81, pass);

        if (error_count == 0) begin
            $display("PASS");
        end

        $finish;
    end

endmodule
