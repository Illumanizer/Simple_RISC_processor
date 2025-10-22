// alu.v
// Top-level single-cycle ALU using bk_adder32, mul_tree32, div_restoring32.
// Uses ALU_* defines from decode.vh
`timescale 1ns/1ps

`include "decode.vh"

module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  op,
    output reg  [31:0] y,
    output wire        zero
);
    // Instantiate adder (for add/sub and used by multiplier internally)
    wire [31:0] sum_add;
    wire        cout_add;
    bk_adder32 #(.WIDTH(32), .LG(5)) ADDER (
        .a(a),
        .b(b),
        .cin(1'b0),
        .sum(sum_add),
        .cout(cout_add)
    );

    // Subtraction via add with two's complement
    wire [31:0] b_neg = ~b + 1;
    wire [31:0] sum_sub;
    wire        cout_sub;
    bk_adder32 #(.WIDTH(32), .LG(5)) SUB_ADDER (
        .a(a),
        .b(b_neg),
        .cin(1'b0),
        .sum(sum_sub),
        .cout(cout_sub)
    );

    // SLT (signed)
    wire slt_bit = ($signed(a) < $signed(b));

    // Shifts
    wire [31:0] sll_r = b << a[4:0];
    wire [31:0] srl_r = b >> a[4:0];
    wire [31:0] sra_r = $signed(b) >>> a[4:0];

    // Logic
    wire [31:0] and_r  = a & b;
    wire [31:0] or_r   = a | b;
    wire [31:0] xor_r  = a ^ b;
    wire [31:0] pass_r = b;
    wire [31:0] not_r  = ~b;

    // Multiplier
    wire signed [31:0] mul_res;
    mul_tree32 MUL0 (
        .a($signed(a)),
        .b($signed(b)),
        .product(mul_res)
    );

    // Divider
    wire signed [31:0] div_q;
    wire signed [31:0] div_r;
    div_radix4_unrolled DIV0 (
        .dividend($signed(a)),
        .divisor($signed(b)),
        .quotient(div_q),
        .remainder(div_r)
    );

    // Select output combinationally
    always @(*) begin
        case (op)
            `ALU_ADD: y = sum_add;
            `ALU_SUB: y = sum_sub;
            `ALU_AND: y = and_r;
            `ALU_OR : y = or_r;
            `ALU_XOR: y = xor_r;
            `ALU_SLT: y = {31'b0, slt_bit};
            `ALU_SLL: y = sll_r;
            `ALU_SRL: y = srl_r;
            `ALU_SRA: y = sra_r;
            `ALU_PASS: y = pass_r;
            `ALU_NOT:  y = not_r;
            `ALU_MUL:  y = mul_res;
            `ALU_DIV:  y = div_q;
            `ALU_MOD:  y = div_r;
            default:   y = 32'h0000_0000;
        endcase
    end

    assign zero = (y == 32'h0);

endmodule
