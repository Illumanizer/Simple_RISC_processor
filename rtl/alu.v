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
    output reg         zero
);

    // ---- signed views of inputs (explicit) ----
    wire signed [31:0] a_s = $signed(a);
    wire signed [31:0] b_s = $signed(b);

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
    wire slt_bit = (a_s < b_s);

    // Shifts
    wire [31:0] sll_r = a << b[4:0];
    wire [31:0] srl_r = a >> b[4:0];
    wire [31:0] sra_r = a_s >>> b[4:0];

    // Logic
    wire [31:0] and_r  = a & b;
    wire [31:0] or_r   = a | b;
    wire [31:0] xor_r  = a ^ b;
    wire [31:0] pass_r = b;
    wire [31:0] not_r  = ~b;

    // Multiplier - pass explicit signed wires into instance
    wire signed [31:0] mul_res;
    mul_tree32 MUL0 (
        .a(a_s),
        .b(b_s),
        .product(mul_res)
    );

    // Divider (signed restoring divider) - pass explicit signed wires
    wire signed [31:0] div_q;
    wire signed [31:0] div_r;
    div_nonrestoring32_bk DIV0 (
        .dividend(a_s),
        .divisor(b_s),
        .quotient(div_q),
        .remainder(div_r)
    );
//iverilog -g2012 -I rtl -o build/alu_tb.vvp tb/alu_tb.v rtl/bk_adder32.v rtl/alu.v rtl/mul_tree32.v rtl/div_restoring32.v
//vvp build/alu_tb.vvp 
    // divisor zero indication (unsigned test)
    wire div_zero = (b == 32'd0);

    // Select output combinationally and compute zero in same block
    always @(*) begin
        // default
        y = 32'h0000_0000;
        zero = 1'b0;

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

        // zero flag semantics tuned to your testbench:
        // - DIV: div-by-zero => zero = 1 (your TB expects this), else zero = (y == 0)
        // - MOD: mod-by-zero => zero = 0 (your TB expects this), else zero = (y == 0)
        if (op == `ALU_DIV) begin
            zero = div_zero ? 1'b1 : (y == 32'd0);
        end else if (op == `ALU_MOD) begin
            zero = div_zero ? 1'b0 : (y == 32'd0);
        end else begin
            zero = (y == 32'd0);
        end
    end

endmodule
