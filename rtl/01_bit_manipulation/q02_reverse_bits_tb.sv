module tb;

    // define interface
    logic [7:0] dut_in;
    logic [7:0] dut_out;

    logic [7:0] expected;

    int error_count = 0;

    reverse_bits dut_reverse_bits(
        .in(dut_in),
        .out(dut_out)
    );

    initial begin
        dut_in = $urandom();
        for (int i = 0; i< 8; i++) begin
            expected[i] = dut_in[7 - i];
        end
        #1
        if (expected != dut_out) begin
            error_count++;
        end

        if(error_count==0) begin
            $display("PASS");
        end
        else begin
            $display("FAIL");
        end
        $finish;

    end


endmodule