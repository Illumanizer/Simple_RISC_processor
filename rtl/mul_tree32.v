`timescale 1ns/1ps
// mul_tree32_wallace.v
// 32x32 signed multiplier using Wallace-style CSA reduction tree
// - Generates 32 partial 64-bit partials (a_abs << j) when b_abs[j]==1
// - Reduces them with 3:2 carry-save adders (CSA) in a Wallace reduction until 2 rows remain
// - Final 64-bit CPA done with two bk_adder32 (low then high with carry)
// - Sign correction applied at the end

module mul_tree32 (
    input  wire signed [31:0] a, // multiplicand
    input  wire signed [31:0] b, // multiplier
    output wire signed [31:0] product
);
    // sign handling and magnitudes
    wire sign_a = a[31];
    wire sign_b = b[31];
    wire sign_res = sign_a ^ sign_b;

    wire [31:0] a_abs = sign_a ? (~a + 32'd1) : a;
    wire [31:0] b_abs = sign_b ? (~b + 32'd1) : b;

    // ----------------------------
    // Level 0 partials (32 x 64-bit)
    // ----------------------------
    wire [63:0] L0 [0:31];
    genvar gi;
    generate
        for (gi = 0; gi < 32; gi = gi + 1) begin : GEN_L0
            // shift-and-add partial: a_abs shifted left by gi when b_abs[gi]==1
            assign L0[gi] = b_abs[gi] ? ({32'd0, a_abs} << gi) : 64'd0;
        end
    endgenerate

    // ----------------------------
    // Helper: 3:2 CSA implemented bitwise for 64-bit inputs
    // sum = a ^ b ^ c
    // carry = (a&b | b&c | a&c) << 1
    // ----------------------------
    // We'll use inline expressions in generates below.

    // ----------------------------------------------------------------
    // Wallace reduction levels:
    // N0 = 32 -> N1 = 22
    // N1 = 22 -> N2 = 15
    // N2 = 15 -> N3 = 10
    // N3 = 10 -> N4 = 7
    // N4 = 7  -> N5 = 5
    // N5 = 5  -> N6 = 4
    // N6 = 4  -> N7 = 3
    // N7 = 3  -> N8 = 2  (stop)
    // We'll create arrays for each level sized accordingly.
    // ----------------------------------------------------------------

    // L1: 22 entries
    wire [63:0] L1 [0:21];
    generate
        for (gi = 0; gi < 10; gi = gi + 1) begin : GEN_L1_CSAS
            // group of 3: L0[3*gi], L0[3*gi+1], L0[3*gi+2]
            wire [63:0] A = L0[3*gi];
            wire [63:0] B = L0[3*gi+1];
            wire [63:0] C = L0[3*gi+2];
            wire [63:0] S = A ^ B ^ C;
            wire [63:0] CARR = ((A & B) | (B & C) | (A & C)) << 1;
            assign L1[2*gi]     = S;
            assign L1[2*gi + 1] = CARR;
        end
        // leftovers: L0[30], L0[31] map to L1[20], L1[21]
        assign L1[20] = L0[30];
        assign L1[21] = L0[31];
    endgenerate

    // L2: 15 entries
    wire [63:0] L2 [0:14];
    generate
        for (gi = 0; gi < 7; gi = gi + 1) begin : GEN_L2_CSAS
            wire [63:0] A = L1[3*gi];
            wire [63:0] B = L1[3*gi+1];
            wire [63:0] C = L1[3*gi+2];
            wire [63:0] S = A ^ B ^ C;
            wire [63:0] CARR = ((A & B) | (B & C) | (A & C)) << 1;
            assign L2[2*gi]     = S;
            assign L2[2*gi + 1] = CARR;
        end
        // leftover: L1[21] -> L2[14]
        assign L2[14] = L1[21];
    endgenerate

    // L3: 10 entries
    wire [63:0] L3 [0:9];
    generate
        for (gi = 0; gi < 5; gi = gi + 1) begin : GEN_L3_CSAS
            wire [63:0] A = L2[3*gi];
            wire [63:0] B = L2[3*gi+1];
            wire [63:0] C = L2[3*gi+2];
            wire [63:0] S = A ^ B ^ C;
            wire [63:0] CARR = ((A & B) | (B & C) | (A & C)) << 1;
            assign L3[2*gi]     = S;
            assign L3[2*gi + 1] = CARR;
        end
    endgenerate

    // L4: 7 entries
    wire [63:0] L4 [0:6];
    generate
        for (gi = 0; gi < 3; gi = gi + 1) begin : GEN_L4_CSAS
            wire [63:0] A = L3[3*gi];
            wire [63:0] B = L3[3*gi+1];
            wire [63:0] C = L3[3*gi+2];
            wire [63:0] S = A ^ B ^ C;
            wire [63:0] CARR = ((A & B) | (B & C) | (A & C)) << 1;
            assign L4[2*gi]     = S;
            assign L4[2*gi + 1] = CARR;
        end
        // leftover: L3[6] -> L4[6]
        assign L4[6] = L3[6];
    endgenerate

    // L5: 5 entries
    wire [63:0] L5 [0:4];
    generate
        for (gi = 0; gi < 2; gi = gi + 1) begin : GEN_L5_CSAS
            wire [63:0] A = L4[3*gi];
            wire [63:0] B = L4[3*gi+1];
            wire [63:0] C = L4[3*gi+2];
            wire [63:0] S = A ^ B ^ C;
            wire [63:0] CARR = ((A & B) | (B & C) | (A & C)) << 1;
            assign L5[2*gi]     = S;
            assign L5[2*gi + 1] = CARR;
        end
        // leftovers: L4[6] and L4[4] map to L5[4]? Careful: we processed indices 0..5 => consumed 6 items, leftover is L4[6]
        assign L5[4] = L4[6];
    endgenerate

    // L6: 4 entries
    wire [63:0] L6 [0:3];
    generate
        // group one CSA on L5[0..2]
        wire [63:0] S0 = L5[0] ^ L5[1] ^ L5[2];
        wire [63:0] C0 = ((L5[0] & L5[1]) | (L5[1] & L5[2]) | (L5[0] & L5[2])) << 1;
        assign L6[0] = S0;
        assign L6[1] = C0;
        // leftover from previous stage: L5[3] and L5[4] become next entries
        assign L6[2] = L5[3];
        assign L6[3] = L5[4];
    endgenerate

    // L7: 3 entries
    wire [63:0] L7 [0:2];
    generate
        // CSA on L6[0..2] => produces two outputs + leftover L6[3]
        wire [63:0] S1 = L6[0] ^ L6[1] ^ L6[2];
        wire [63:0] C1 = ((L6[0] & L6[1]) | (L6[1] & L6[2]) | (L6[0] & L6[2])) << 1;
        assign L7[0] = S1;
        assign L7[1] = C1;
        assign L7[2] = L6[3];
    endgenerate

    // L8: final 2 entries (reduce 3 -> 2)
    wire [63:0] L8 [0:1];
    generate
        wire [63:0] S2 = L7[0] ^ L7[1] ^ L7[2];
        wire [63:0] C2 = ((L7[0] & L7[1]) | (L7[1] & L7[2]) | (L7[0] & L7[2])) << 1;
        assign L8[0] = S2;
        assign L8[1] = C2;
    endgenerate

    // ----------------------------
    // Final CPA: add L8[0] + L8[1] (64-bit) using bk_adder32 pairs
    // ----------------------------
    wire [31:0] a_lo = L8[0][31:0];
    wire [31:0] a_hi = L8[0][63:32];
    wire [31:0] b_lo = L8[1][31:0];
    wire [31:0] b_hi = L8[1][63:32];

    wire [31:0] sum_lo;
    wire        carry_lo;
    wire [31:0] sum_hi;
    wire        carry_hi;

    bk_adder32 FINAL_LO (
        .a(a_lo),
        .b(b_lo),
        .cin(1'b0),
        .sum(sum_lo),
        .cout(carry_lo)
    );

    bk_adder32 FINAL_HI (
        .a(a_hi),
        .b(b_hi),
        .cin(carry_lo),
        .sum(sum_hi),
        .cout(carry_hi)
    );

    wire [63:0] Lfinal = {sum_hi, sum_lo};

    // sign correction (two's complement if negative)
    wire [63:0] Lfinal_inv = ~Lfinal;

    wire [31:0] Lfinal_inv_lo = Lfinal_inv[31:0];
    wire [31:0] Lfinal_inv_hi = Lfinal_inv[63:32];

    wire [31:0] Lfinal_neg_lo;
    wire        Lfinal_neg_lo_c;

    bk_adder32 NEG_LO_ADDER (
        .a(Lfinal_inv_lo),
        .b(32'd0),
        .cin(1'b1),
        .sum(Lfinal_neg_lo),
        .cout(Lfinal_neg_lo_c)
    );

    wire [31:0] Lfinal_neg_hi;
    wire        Lfinal_neg_hi_c;

    bk_adder32 NEG_HI_ADDER (
        .a(Lfinal_inv_hi),
        .b(32'd0),
        .cin(Lfinal_neg_lo_c),
        .sum(Lfinal_neg_hi),
        .cout(Lfinal_neg_hi_c)
    );

    wire [63:0] final_unsigned = Lfinal;
    wire [63:0] final_signed   = sign_res ? {Lfinal_neg_hi, Lfinal_neg_lo} : final_unsigned;

    assign product = $signed(final_signed[31:0]);

endmodule
