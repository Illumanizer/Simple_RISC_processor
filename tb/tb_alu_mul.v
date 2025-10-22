`timescale 1ns/1ps
`include "decode.vh"

module test_mul;
    reg [31:0] a, b;
    wire [31:0] y;
    wire zero;
    reg [3:0] op;
    integer e = 0;

    alu DUT (.a(a), .b(b), .op(op), .y(y), .zero(zero));

    initial begin
        $display("---- Testing MUL ----");
        op = `ALU_MUL;

        a = 32'd3; b = 32'd4; #1;
        if (y !== 32'd12) begin $display("FAIL: 3*4 => %h", y); e++; end

        a = -32'sd3; b = 32'sd4; #1;
        if (y !== -32'sd12) begin $display("FAIL: -3*4 => %h", y); e++; end

        a = 32'd10000; b = 32'd3000; #1;
        if (y !== 32'd30000000) begin $display("FAIL: 10000*3000 => %h", y); e++; end

        if (e == 0) $display("PASS: MUL tests passed");
        else $display("FAIL: %0d MUL tests failed", e);
        $finish;
    end
endmodule
