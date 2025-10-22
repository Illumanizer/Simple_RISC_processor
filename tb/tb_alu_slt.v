`timescale 1ns/1ps
`include "decode.vh"

module test_slt;
    reg [31:0] a, b;
    wire [31:0] y;
    wire zero;
    reg [3:0] op;
    integer e = 0;

    alu DUT (.a(a), .b(b), .op(op), .y(y), .zero(zero));

    initial begin
        $display("---- Testing SLT ----");
        op = `ALU_SLT;

        a = 32'd5; b = 32'd10; #1;
        if (y !== 32'd1) begin $display("FAIL: 5<10 => %h", y); e++; end

        a = 32'd10; b = 32'd5; #1;
        if (y !== 32'd0) begin $display("FAIL: 10<5 => %h", y); e++; end

        a = -32'sd1; b = 32'sd1; #1;
        if (y !== 32'd1) begin $display("FAIL: -1<1 => %h", y); e++; end

        if (e == 0) $display("PASS: SLT tests passed");
        else $display("FAIL: %0d SLT tests failed", e);
        $finish;
    end
endmodule
