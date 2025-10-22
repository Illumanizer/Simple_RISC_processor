`timescale 1ns/1ps
`include "decode.vh"

module test_shift;
    reg [31:0] a, b;
    wire [31:0] y;
    wire zero;
    reg [3:0] op;
    integer err = 0;

    alu DUT (.a(a), .b(b), .op(op), .y(y), .zero(zero));

    initial begin
        $display("---- Testing Shift operations ----");

        // SLL
        op = `ALU_SLL;
        a = 32'd1; b = 32'h00000001; #1;
        if (y !== 32'h00000002) begin $display("FAIL: SLL => %h", y); err++; end

        // SRL
        op = `ALU_SRL;
        a = 32'd1; b = 32'h00000002; #1;
        if (y !== 32'h00000001) begin $display("FAIL: SRL => %h", y); err++; end

        // SRA
        op = `ALU_SRA;
        a = 32'd1; b = 32'h80000000; #1;
        if (y !== 32'hC0000000) begin $display("FAIL: SRA => %h", y); err++; end

        if (err == 0) $display("PASS: All Shift tests passed");
        else $display("FAIL: %0d Shift tests failed", err);
        $finish;
    end
endmodule
