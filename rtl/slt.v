// slt32_methodB.v  (signed a < b ? 1 : 0)
`timescale 1ns/1ps
module slt32 (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire        slt
);
    // compute a - b just to get diff sign when signs equal
    wire [31:0] b_inv = ~b;
    wire [31:0] diff;
    wire        cout_diff;

    bk_adder32 SUB_ADDER (
        .a   (a),
        .b   (b_inv),
        .cin (1'b1),
        .sum (diff),
        .cout(cout_diff)
    );

    // if signs differ: a < b iff a is negative
    // else: a < b iff diff[31] == 1
    assign slt = (a[31] ^ b[31]) ? a[31] : diff[31];
endmodule
