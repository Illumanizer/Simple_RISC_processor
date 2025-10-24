`timescale 1ns/1ps
// div_nonrestoring32_bk_fixed.v
// Single-cycle, fully-unrolled non-restoring signed divider using bk_adder32
// Fixed: use stage_P_m[i] as the MSB ("shift_m") when deciding add vs sub.
// (All additions/subtractions are performed via bk_adder32 instances.)

module div_nonrestoring32_bk (
    input  wire signed [31:0] dividend,
    input  wire signed [31:0] divisor,
    output wire signed [31:0] quotient,
    output wire signed [31:0] remainder
);

    // -----------------------------------------------------------
    // Basic signals
    // -----------------------------------------------------------
    wire div_zero = (divisor == 32'd0);

    // signs
    wire divd_neg = dividend[31];
    wire divs_neg = divisor[31];
    wire sign_q   = divd_neg ^ divs_neg; // quotient sign
    wire sign_r   = divd_neg;            // remainder follows dividend sign

    // ----------------------
    // compute absolute(dividend) -> ua
    // ua = (dividend < 0) ? (~dividend + 1) : dividend
    // Implement (~dividend + 1) with bk_adder32: a = ~dividend, b = 0, cin = 1
    // ----------------------
    wire [31:0] dividend_inv = ~dividend;
    wire [31:0] ua_neg;
    wire ua_neg_cout;
    bk_adder32 UA_NEG_ADDER (
        .a(dividend_inv),
        .b(32'd0),
        .cin(1'b1),
        .sum(ua_neg),
        .cout(ua_neg_cout)
    );

    wire [31:0] ua = divd_neg ? ua_neg : dividend;

    // ----------------------
    // compute absolute(divisor) -> ub
    // ----------------------
    wire [31:0] divisor_inv = ~divisor;
    wire [31:0] ub_neg;
    wire ub_neg_cout;
    bk_adder32 UB_NEG_ADDER (
        .a(divisor_inv),
        .b(32'd0),
        .cin(1'b1),
        .sum(ub_neg),
        .cout(ub_neg_cout)
    );

    wire [31:0] ub = divs_neg ? ub_neg : divisor;

    // keep ub_inv = ~ub for subtract path (we will use it repeatedly)
    wire [31:0] ub_inv = ~ub;

    // -----------------------------------------------------------
    // Unrolled non-restoring main pipeline (32 stages)
    // Stage 0: P = 0
    // For stage i (0..31):
    //   shift:  P_shift_lo = { P_lo[i][30:0], ua[31-i] }
    //           P_shift_m  = stage_P_m[i]    (the top bit of the 33-bit P)
    //   if P_shift_m == 0:  T = P_shift - ub    (use bk_adder with b = ~ub, cin=1)
    //   else:               T = P_shift + ub    (use bk_adder with b = ub,  cin=0)
    //   next_P_m = T[32]   (computed via top-bit logic from carry)
    //   next_P_lo = T[31:0]
    // qbit[31-i] = (next_P_m == 0) ? 1 : 0
    // After loop: if final P_m == 1 then do correction: P = P + ub once (correction)
    // -----------------------------------------------------------

    // stage signals arrays
    wire [31:0] stage_P_lo [0:32];
    wire        stage_P_m  [0:32];

    // initial values
    assign stage_P_lo[0] = 32'd0;
    assign stage_P_m[0]  = 1'b0;

    // quotient bits (collected per stage)
    wire [31:0] qbits;

    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : STAGE_LOOP
            // bring next ua bit (MSB first)
            wire shift_in_bit = ua[31 - i];

            // shift: new_shift_lo = { stage_P_lo[i][30:0], shift_in_bit }
            wire [31:0] shift_lo;
            assign shift_lo = { stage_P_lo[i][30:0], shift_in_bit };

            // IMPORTANT FIX: use stage_P_m[i] (the top bit of the 33-bit partial remainder)
            wire shift_m = stage_P_m[i]; // <-- FIXED: was stage_P_lo[i][31] (wrong)

            // instantiate adders: add-case (shift_lo + ub), sub-case (shift_lo + ~ub + 1)
            wire [31:0] sum_add;
            wire        cout_add;
            bk_adder32 ADDER_ADD (
                .a(shift_lo),
                .b(ub),
                .cin(1'b0),
                .sum(sum_add),
                .cout(cout_add)
            );

            wire [31:0] sum_sub;
            wire        cout_sub;
            bk_adder32 ADDER_SUB (
                .a(shift_lo),
                .b(ub_inv),
                .cin(1'b1),
                .sum(sum_sub),
                .cout(cout_sub)
            );

            // compute next MSB based on carry_out and shift_m
            wire next_msb_add = shift_m ^ cout_add;
            wire next_msb_sub = ~(shift_m ^ cout_sub);

            wire next_msb = shift_m ? next_msb_add : next_msb_sub;
            wire [31:0] next_lo = shift_m ? sum_add : sum_sub;

            assign stage_P_m[i+1] = next_msb;
            assign stage_P_lo[i+1] = next_lo;

            // qbit: bit (31 - i) = ~next_msb
            assign qbits[31 - i] = ~next_msb;
        end
    endgenerate

    // After 32 stages, final P = stage_P (index 32)
    wire final_P_m = stage_P_m[32];
    wire [31:0] final_P_lo = stage_P_lo[32];

    // Correction if final P negative: P = P + ub
    wire [31:0] corr_sum_lo;
    wire        corr_cout;
    bk_adder32 CORR_ADDER (
        .a(final_P_lo),
        .b(ub),
        .cin(1'b0),
        .sum(corr_sum_lo),
        .cout(corr_cout)
    );

    // corrected remainder magnitude
    wire [31:0] rem_mag = final_P_m ? corr_sum_lo : final_P_lo;

    // unsigned quotient qtmp
    wire [31:0] qtmp = qbits;

    // compute two's complement of qtmp if sign_q
    wire [31:0] qtmp_inv = ~qtmp;
    wire [31:0] qtmp_neg;
    wire qtmp_neg_cout;
    bk_adder32 Q_NEG_ADDER (
        .a(qtmp_inv),
        .b(32'd0),
        .cin(1'b1),
        .sum(qtmp_neg),
        .cout(qtmp_neg_cout)
    );

    wire [31:0] quot_mag = sign_q ? qtmp_neg : qtmp;

    // remainder sign
    wire [31:0] rem_inv = ~rem_mag;
    wire [31:0] rem_neg;
    wire rem_neg_cout;
    bk_adder32 R_NEG_ADDER (
        .a(rem_inv),
        .b(32'd0),
        .cin(1'b1),
        .sum(rem_neg),
        .cout(rem_neg_cout)
    );

    wire [31:0] rem_final = sign_r ? rem_neg : rem_mag;

    // divisor==0 semantics: quotient = 0xFFFFFFFF, remainder = ua
    wire [31:0] quotient_out = div_zero ? 32'hFFFF_FFFF : quot_mag;
    wire [31:0] remainder_out = div_zero ? ua : rem_final;

    assign quotient  = $signed(quotient_out);
    assign remainder = $signed(remainder_out);

endmodule
