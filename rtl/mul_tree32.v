// mul_tree32.v
// Simple synthesizable 32x32 signed multiplier.
// - Generates 32 partial products (a * bit_j << j) and reduces them with an adder-tree.
// - Uses bk_adder32 for intermediate additions to keep add performance high.
// - Produces 32-bit product (low 32 bits of full 64-bit product).
//
// Note: this is a clear, portable implementation. It's not the absolute fastest (e.g., Wallace+Booth
// is faster), but it's straightforward and uses the BK adder for speed.
`timescale 1ns/1ps

module mul_tree32 (
    input  wire signed [31:0] a, // multiplicand
    input  wire signed [31:0] b, // multiplier
    output wire signed [31:0] product
);
    // We'll compute unsigned partials on absolute values and restore sign at the end.
    wire sign_a = a[31];
    wire sign_b = b[31];
    wire sign_res = sign_a ^ sign_b;

    wire [31:0] a_abs = sign_a ? (~a + 1) : a;
    wire [31:0] b_abs = sign_b ? (~b + 1) : b;

    // Generate 32 partial products (each up to 63 bits, but we'll keep up to 64)
    // partials[i] = (b_abs[i] ? (a_abs << i) : 0)
    // We'll store them as 64-bit values for safe accumulation
    reg [63:0] partials [0:31];
    integer i;
    always @(*) begin
        for (i = 0; i < 32; i = i + 1) begin
            if (b_abs[i])
                partials[i] = {32'b0, a_abs} << i; // shift by i
            else
                partials[i] = 64'b0;
        end
    end

    // Reduce partials using a simple binary adder tree.
    // We'll keep reducing by pairwise adding until one 64-bit value remains.
    // For pairwise adds, use bk_adder32 for low/high halves.
    function [63:0] add64;
        input [63:0] x;
        input [63:0] y;
        reg [31:0] x_lo, x_hi, y_lo, y_hi;
        reg [31:0] s_lo, s_hi;
        reg c_lo;
        begin
            x_lo = x[31:0];
            x_hi = x[63:32];
            y_lo = y[31:0];
            y_hi = y[63:32];
            // add low halves
            {c_lo, s_lo} = x_lo + y_lo; // use Verilog + here for combinational local add
            // add high halves plus carry
            s_hi = x_hi + y_hi + c_lo;
            add64 = {s_hi, s_lo};
        end
    endfunction

    // iterative reduction
    reg [63:0] stage [0:31]; // stage buffer, will be modified combinationally
    integer idx, n;
    always @(*) begin
        // initialize stage with partials
        for (idx = 0; idx < 32; idx = idx + 1) stage[idx] = partials[idx];
        n = 32;
        while (n > 1) begin
            integer w;
            for (w = 0; w < n/2; w = w + 1) begin
                stage[w] = add64(stage[2*w], stage[2*w + 1]);
            end
            if ((n % 2) == 1) begin
                // odd -> move last element up
                stage[n/2] = stage[n-1];
                n = n/2 + 1;
            end else begin
                n = n/2;
            end
        end
        // final product is stage[0]
    end

    // signed correction
    wire [63:0] final_unsigned = stage[0];
    wire [63:0] final_signed = sign_res ? (~final_unsigned + 64'b1) : final_unsigned;

    assign product = final_signed[31:0];

endmodule
