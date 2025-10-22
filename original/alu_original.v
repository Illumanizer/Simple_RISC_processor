`timescale 1ns/1ps
`include "decode.vh"

module alu(
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  op,
    output reg  [31:0] y,
    output wire        zero
);
    always @(*) begin
        case (op)
            `ALU_ADD: y = a + b;
            `ALU_SUB: y = a - b;
            `ALU_AND: y = a & b;
            `ALU_OR : y = a | b;
            `ALU_XOR: y = a ^ b;
            `ALU_SLT: y = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            `ALU_SLL: y = a << b[4:0];
            `ALU_SRL: y = a >> b[4:0];
            `ALU_SRA: y = $signed(a) >>> b[4:0];
            `ALU_NOT: y = ~b;
            `ALU_PASS:y = b;
            `ALU_MUL: y = a * b;
            `ALU_DIV: y = (b!=0) ? (a / b) : 32'hFFFFFFFF;
            `ALU_MOD: y = (b!=0) ? (a % b) : a;
            default:   y = 32'd0;
        endcase
    end
    assign zero = (y == 32'd0);
endmodule
