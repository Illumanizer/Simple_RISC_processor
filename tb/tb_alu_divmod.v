`timescale 1ns/1ps

module tb_alu_divmod;
    reg signed [31:0] dividend;
    reg signed [31:0] divisor;
    wire signed [31:0] quotient;
    wire signed [31:0] remainder;

    // instantiate your divider (combinational)
    div_nonrestoring32_bk DUT (
        .dividend(dividend),
        .divisor(divisor),
        .quotient(quotient),
        .remainder(remainder)
    );

    // builtin results
    wire signed [31:0] q_builtin;
    wire signed [31:0] r_builtin;
    assign q_builtin = (divisor == 0) ? 32'shFFFF_FFFF : (dividend / divisor);
    assign r_builtin = (divisor == 0) ? dividend : (dividend % divisor);

    initial begin
        

        // nicer delay to allow propagation
        dividend = 32'd10; divisor = 32'd2; #5;
        check();

        dividend = -32'sd10; divisor = 32'sd2; #5;
        check();

        dividend = 32'd10; divisor = 32'd3; #5;
        check();

        dividend = -32'sd10; divisor = 32'sd3; #5;
        check();

        // divide by zero
        dividend = 32'd10; divisor = 32'd0; #5;
        check();

        // tricky overflow
        dividend = -32'sd2147483648; divisor = -32'sd1; #5;
        check();

        $display("All tests done.");
        $finish;
    end

    task check;
        begin
            $display("dividend=%0d (%h) divisor=%0d (%h) -> DUT Q=%0d (%h) R=%0d (%h) | builtin Q=%0d (%h) R=%0d (%h)",
                     dividend, dividend, divisor, divisor,
                     quotient, quotient, remainder, remainder,
                     q_builtin, q_builtin, r_builtin, r_builtin);
            if (divisor != 0) begin
                if ((quotient !== q_builtin) || (remainder !== r_builtin)) begin
                    $display("!!!!!!!!!!!!!!MISMATCH at time %0t: DUT != builtin", $time);

                end
            end else begin
                $display("divisor==0: builtin uses sentinel; check DUT behavior manually.");
            end
        end
    endtask
endmodule
