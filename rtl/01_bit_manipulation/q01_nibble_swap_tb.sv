module tb;
    // define interface
    logic [7:0] in;
    logic [7:0] out;

    // testbench vars
    logic [7:0] expected;

    int errors = 0;

    // instantiate module
    nibble_swap dut_nibble_swap (
        .in(in),
        .out(out)
    );

    initial begin 
        in = 8'hA3;
        #10;
        if(out!=8'h3A) begin 
            $display("Wrong result: output: %0d, golden: %0d ", out, 8'h3A);
            errors++;
        end
        
        in = $urandom_range(8'hFF, 8'h00);
        expected = {in[3:0], in[7:4]};
        #10
        if(out!=expected) begin 
            $display("Wrong result: output: %0d, golden: %0d ", out, expected);
            errors++;
        end

        if(errors==0) begin
            $display("PASS");
        end
        else begin
            $display("FAIL");
        end
        $finish;
    end

endmodule