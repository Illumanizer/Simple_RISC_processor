`timescale 1ns/1ps
// mul_tree32.v
// 32x32 signed multiplier using partial-product tree with bk_adder32
// - Generates 32 partial 64-bit partials (a_abs << j) when b_abs[j]==1
// - Reduces them in an adder tree using structural 64-bit adds implemented by bk_adder32
// - Produces lower 32 bits of 64-bit product (signed), and does sign correction
// - All 64-bit adds use two bk_adder32 instances (low half then high half with carry)


module mul_tree32 (
    input  wire signed [31:0] a, // multiplicand
    input  wire signed [31:0] b, // multiplier
    output wire signed [31:0] product
);
    // sign handling
    wire sign_a = a[31];
    wire sign_b = b[31];
    wire sign_res = sign_a ^ sign_b;

    wire [31:0] a_abs = sign_a ? (~a + 32'd1) : a;
    wire [31:0] b_abs = sign_b ? (~b + 32'd1) : b;

    // Level 0 partials: 32 x 64-bit
    wire [63:0] L0 [0:31];
    genvar gi;
    generate
        for (gi = 0; gi < 32; gi = gi + 1) begin : GEN_L0
            assign L0[gi] = b_abs[gi] ? ({32'd0, a_abs} << gi) : 64'd0;
        end
    endgenerate

    // L1: 16 sums = L0[0]+L0[1], L0[2]+L0[3], ...
    wire [63:0] L1 [0:15];
    generate
        for (gi = 0; gi < 16; gi = gi + 1) begin : GEN_L1
            wire [31:0] a_lo = L0[2*gi][31:0];
            wire [31:0] a_hi = L0[2*gi][63:32];
            wire [31:0] b_lo = L0[2*gi+1][31:0];
            wire [31:0] b_hi = L0[2*gi+1][63:32];

            wire [31:0] sum_lo;
            wire        carry_lo;
            wire [31:0] sum_hi;
            wire        carry_hi;

            bk_adder32 ADD_L1_LO (
                .a(a_lo),
                .b(b_lo),
                .cin(1'b0),
                .sum(sum_lo),
                .cout(carry_lo)
            );

            bk_adder32 ADD_L1_HI (
                .a(a_hi),
                .b(b_hi),
                .cin(carry_lo),
                .sum(sum_hi),
                .cout(carry_hi)
            );

            assign L1[gi] = {sum_hi, sum_lo};
        end
    endgenerate

    // L2: 8 sums from L1
    wire [63:0] L2 [0:7];
    generate
        for (gi = 0; gi < 8; gi = gi + 1) begin : GEN_L2
            wire [31:0] a_lo = L1[2*gi][31:0];
            wire [31:0] a_hi = L1[2*gi][63:32];
            wire [31:0] b_lo = L1[2*gi+1][31:0];
            wire [31:0] b_hi = L1[2*gi+1][63:32];

            wire [31:0] sum_lo;
            wire        carry_lo;
            wire [31:0] sum_hi;
            wire        carry_hi;

            bk_adder32 ADD_L2_LO (
                .a(a_lo),
                .b(b_lo),
                .cin(1'b0),
                .sum(sum_lo),
                .cout(carry_lo)
            );

            bk_adder32 ADD_L2_HI (
                .a(a_hi),
                .b(b_hi),
                .cin(carry_lo),
                .sum(sum_hi),
                .cout(carry_hi)
            );

            assign L2[gi] = {sum_hi, sum_lo};
        end
    endgenerate

    // L3: 4 sums from L2
    wire [63:0] L3 [0:3];
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : GEN_L3
            wire [31:0] a_lo = L2[2*gi][31:0];
            wire [31:0] a_hi = L2[2*gi][63:32];
            wire [31:0] b_lo = L2[2*gi+1][31:0];
            wire [31:0] b_hi = L2[2*gi+1][63:32];

            wire [31:0] sum_lo;
            wire        carry_lo;
            wire [31:0] sum_hi;
            wire        carry_hi;

            bk_adder32 ADD_L3_LO (
                .a(a_lo),
                .b(b_lo),
                .cin(1'b0),
                .sum(sum_lo),
                .cout(carry_lo)
            );

            bk_adder32 ADD_L3_HI (
                .a(a_hi),
                .b(b_hi),
                .cin(carry_lo),
                .sum(sum_hi),
                .cout(carry_hi)
            );

            assign L3[gi] = {sum_hi, sum_lo};
        end
    endgenerate

    // L4: 2 sums from L3
    wire [63:0] L4 [0:1];
    generate
        for (gi = 0; gi < 2; gi = gi + 1) begin : GEN_L4
            wire [31:0] a_lo = L3[2*gi][31:0];
            wire [31:0] a_hi = L3[2*gi][63:32];
            wire [31:0] b_lo = L3[2*gi+1][31:0];
            wire [31:0] b_hi = L3[2*gi+1][63:32];

            wire [31:0] sum_lo;
            wire        carry_lo;
            wire [31:0] sum_hi;
            wire        carry_hi;

            bk_adder32 ADD_L4_LO (
                .a(a_lo),
                .b(b_lo),
                .cin(1'b0),
                .sum(sum_lo),
                .cout(carry_lo)
            );

            bk_adder32 ADD_L4_HI (
                .a(a_hi),
                .b(b_hi),
                .cin(carry_lo),
                .sum(sum_hi),
                .cout(carry_hi)
            );

            assign L4[gi] = {sum_hi, sum_lo};
        end
    endgenerate

    // L5: final sum from L4 -> single 64-bit result
    wire [63:0] L5;
    generate
        begin : GEN_L5
            wire [31:0] a_lo = L4[0][31:0];
            wire [31:0] a_hi = L4[0][63:32];
            wire [31:0] b_lo = L4[1][31:0];
            wire [31:0] b_hi = L4[1][63:32];

            wire [31:0] sum_lo;
            wire        carry_lo;
            wire [31:0] sum_hi;
            wire        carry_hi;

            bk_adder32 ADD_L5_LO (
                .a(a_lo),
                .b(b_lo),
                .cin(1'b0),
                .sum(sum_lo),
                .cout(carry_lo)
            );

            bk_adder32 ADD_L5_HI (
                .a(a_hi),
                .b(b_hi),
                .cin(carry_lo),
                .sum(sum_hi),
                .cout(carry_hi)
            );

            assign L5 = {sum_hi, sum_lo};
        end
    endgenerate

    // signed correction: if sign_res then final_signed = ~L5 + 1
    wire [63:0] L5_inv;
    assign L5_inv = ~L5;

    wire [31:0] L5_inv_lo = L5_inv[31:0];
    wire [31:0] L5_inv_hi = L5_inv[63:32];

    wire [31:0] L5_neg_lo;
    wire        L5_neg_lo_c;

    bk_adder32 NEG_LO_ADDER (
        .a(L5_inv_lo),
        .b(32'd0),
        .cin(1'b1),
        .sum(L5_neg_lo),
        .cout(L5_neg_lo_c)
    );

    wire [31:0] L5_neg_hi;
    wire        L5_neg_hi_c;

    bk_adder32 NEG_HI_ADDER (
        .a(L5_inv_hi),
        .b(32'd0),
        .cin(L5_neg_lo_c),
        .sum(L5_neg_hi),
        .cout(L5_neg_hi_c)
    );

    wire [63:0] final_unsigned = L5;
    wire [63:0] final_signed   = sign_res ? {L5_neg_hi, L5_neg_lo} : final_unsigned;

    assign product = $signed(final_signed[31:0]);

endmodule
