`timescale 1ns / 1ps
// radix4_booth_mul32_fixed.v
// 32x32 radix-4 Booth multiplier (magnitude-based) with CSA reduction.
// - Operates on absolute magnitudes, restores sign at the end.
// - Produces lower 32 bits (signed) of the 64-bit product.

module mul_tree32 (
    input  wire signed [31:0] a,   // multiplicand
    input  wire signed [31:0] b,   // multiplier
    output wire signed [31:0] product // lower 32 bits (signed)
);

    // ------------------------
    // sign & magnitudes (operate on magnitudes)
    // ------------------------
    wire sign_a = a[31];
    wire sign_b = b[31];
    wire sign_res = sign_a ^ sign_b;

    wire [31:0] a_abs = sign_a ? (~a + 32'd1) : a;
    wire [31:0] b_abs = sign_b ? (~b + 32'd1) : b;

    // extend multiplier magnitude for 3-bit windows
    wire [32:0] b_ext = { b_abs, 1'b0 }; // [32:0]

    // ------------------------
    // Generate 16 partials (65-bit)
    // Each partial is generated from a_abs and may be negated (two's complement) if Booth digit is negative.
    // ------------------------
    wire [64:0] pp [0:15];
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : GEN_PARTIALS
            wire [2:0] bits = b_ext[2*i+2 -: 3]; // bits [2*i+2 : 2*i]
            // positive magnitude forms:
            wire [64:0] pos1 = {{33{1'b0}}, a_abs};           // +1 * A placed in low bits, sign-extended zeros
            wire [64:0] pos2 = {{32{1'b0}}, a_abs, 1'b0};     // +2 * A (shifted left 1)
            // Negation of pos forms (two's complement) computed with bitwise invert + 1
            wire [64:0] neg1 = (~pos1) + 65'd1;
            wire [64:0] neg2 = (~pos2) + 65'd1;

            // select based on booth bits
            wire [64:0] p;
            assign p = (bits == 3'b001 || bits == 3'b010) ? pos1 :
                       (bits == 3'b011) ? pos2 :
                       (bits == 3'b100) ? neg2 :
                       (bits == 3'b101 || bits == 3'b110) ? neg1 :
                       65'd0;

            assign pp[i] = p;
        end
    endgenerate

    // ------------------------
    // shift partials to their positions (left by 2*i)
    // ------------------------
    wire [64:0] pp_sh [0:15];
    generate
        for (i = 0; i < 16; i = i + 1) begin : GEN_SHIFT
            assign pp_sh[i] = pp[i] << (2*i); // preserve full 65-bit width
        end
    endgenerate

    // ------------------------
    // CSA reduction (simple staged 3:2 reduction)
    // Schedule reduces 16 -> 11 -> 8 -> 6 -> 4 -> 3 -> 2 (final pair F0,F1)
    // ------------------------

    // Level1: from 16 -> 11
    wire [64:0] L1 [0:10];
    generate
        for (i = 0; i < 5; i = i + 1) begin : L1_CSAS
            wire [64:0] A = pp_sh[3*i];
            wire [64:0] B = pp_sh[3*i + 1];
            wire [64:0] C = pp_sh[3*i + 2];
            wire [64:0] S = A ^ B ^ C;
            wire [64:0] Carr = ((A & B) | (B & C) | (A & C)) << 1;
            assign L1[2*i]     = S;
            assign L1[2*i + 1] = Carr;
        end
        assign L1[10] = pp_sh[15];
    endgenerate

    // Level2: 11 -> 8
    wire [64:0] L2 [0:7];
    generate
        for (i = 0; i < 3; i = i + 1) begin : L2_CSAS
            wire [64:0] A = L1[3*i];
            wire [64:0] B = L1[3*i + 1];
            wire [64:0] C = L1[3*i + 2];
            wire [64:0] S = A ^ B ^ C;
            wire [64:0] Carr = ((A & B) | (B & C) | (A & C)) << 1;
            assign L2[2*i]     = S;
            assign L2[2*i + 1] = Carr;
        end
        assign L2[6] = L1[9];
        assign L2[7] = L1[10];
    endgenerate

    // Level3: 8 -> 6
    wire [64:0] L3 [0:5];
    generate
        for (i = 0; i < 2; i = i + 1) begin : L3_CSAS
            wire [64:0] A = L2[3*i];
            wire [64:0] B = L2[3*i + 1];
            wire [64:0] C = L2[3*i + 2];
            wire [64:0] S = A ^ B ^ C;
            wire [64:0] Carr = ((A & B) | (B & C) | (A & C)) << 1;
            assign L3[2*i]     = S;
            assign L3[2*i + 1] = Carr;
        end
        assign L3[4] = L2[6];
        assign L3[5] = L2[7];
    endgenerate

    // Level4: 6 -> 4
    wire [64:0] L4 [0:3];
    generate
        for (i = 0; i < 2; i = i + 1) begin : L4_CSAS
            wire [64:0] A = L3[3*i];
            wire [64:0] B = L3[3*i + 1];
            wire [64:0] C = L3[3*i + 2];
            wire [64:0] S = A ^ B ^ C;
            wire [64:0] Carr = ((A & B) | (B & C) | (A & C)) << 1;
            assign L4[2*i]     = S;
            assign L4[2*i + 1] = Carr;
        end
    endgenerate

    // Level5: 4 -> 3
    wire [64:0] L5 [0:2];
    generate
        wire [64:0] S5 = L4[0] ^ L4[1] ^ L4[2];
        wire [64:0] C5 = ((L4[0] & L4[1]) | (L4[1] & L4[2]) | (L4[0] & L4[2])) << 1;
        assign L5[0] = S5;
        assign L5[1] = C5;
        assign L5[2] = L4[3];
    endgenerate

    // Level6: 3 -> 2 (final)
    wire [64:0] F0, F1;
    generate
        wire [64:0] S6 = L5[0] ^ L5[1] ^ L5[2];
        wire [64:0] C6 = ((L5[0] & L5[1]) | (L5[1] & L5[2]) | (L5[0] & L5[2])) << 1;
        assign F0 = S6;
        assign F1 = C6;
    endgenerate

    // ------------------------
    // Final CPA (use 66-bit addition to be safe)
    // ------------------------
    wire [65:0] final_sum66 = {1'b0, F0} + {1'b0, F1}; // 66-bit
    wire [64:0] final_sum65 = final_sum66[64:0];       // lower 65 bits

    // ------------------------
    // Sign restore: if sign_res then take two's complement of the 65-bit magnitude
    // ------------------------
    wire [64:0] final_unsigned = final_sum65;
    wire [64:0] final_signed_65 = sign_res ? ((~final_unsigned) + 65'd1) : final_unsigned;

    // output lower 32 bits as signed
    assign product = $signed(final_signed_65[31:0]);

endmodule
