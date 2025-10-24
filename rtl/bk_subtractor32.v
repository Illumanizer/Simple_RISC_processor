// bk_subtractor32.v
// 32-bit subtractor using bk_adder32 (two's-complement method)
// Computes: diff = a - b - bin
// borrow in (bin): 0 => subtract b, 1 => subtract (b + 1)
// borrow out (bout): 1 => borrow occurred, 0 => no borrow
`timescale 1ns/1ps

module bk_subtractor32 (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire        bin,   // borrow in (0 or 1)
    output wire [31:0] diff,
    output wire        bout   // borrow out: 1 => borrow occurred
);

    // two's complement subtraction: a - b - bin = a + (~b) + (1 - bin)
    wire [31:0] b_inv;
    wire [31:0] sum;
    wire        cout;

    assign b_inv = ~b;

    // cin to adder = 1 - bin  (equivalently: ~bin)
    bk_adder32 ad_inst (
        .a(a),
        .b(b_inv),
        .cin(1'b1 ^ bin), // 1 - bin
        .sum(sum),
        .cout(cout)
    );

    assign diff = sum;
    // borrow-out: in two's-complement subtraction borrow = ~carry_out
    assign bout = ~cout;

endmodule
