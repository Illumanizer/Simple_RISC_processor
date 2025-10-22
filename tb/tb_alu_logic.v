`timescale 1ns/1ps
`include "decode.vh"

module test_logic;
    reg [31:0] a, b;
    wire [31:0] y;
    wire zero;
    reg [3:0] op;
    integer e = 0;

    alu DUT (.a(a), .b(b), .op(op), .y(y), .zero(zero));

    initial begin
        $display("---- Testing Logic operations ----");
        
        // AND
        op = `ALU_AND;
        a = 32'hF0F0F0F0; b = 32'h0F0F0F0F; #1;
        if (y !== 32'h00000000) begin $display("FAIL: AND => %h", y); e++; end

        // OR
        op = `ALU_OR;
        a = 32'hF0F0F0F0; b = 32'h0F0F0F0F; #1;
        if (y !== 32'hFFFFFFFF) begin $display("FAIL: OR => %h", y); e++; end

        // XOR
        op = `ALU_XOR;
        a = 32'hAAAA5555; b = 32'hFFFF0000; #1;
        if (y !== 32'h5555_5555) begin $display("FAIL: XOR => %h", y); e++; end

        // NOT
        op = `ALU_NOT;
        a = 32'h00000000; b = 32'hFFFFFFFF; #1;
        if (y !== 32'h00000000) begin $display("FAIL: NOT => %h", y); e++; end

        if (e == 0) $display("PASS: All Logic tests passed");
        else $display("FAIL: %0d Logic tests failed", e);
        $finish;
    end
endmodule
