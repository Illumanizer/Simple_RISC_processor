// rtl/div_radix4_unrolled_working.v
`timescale 1ns/1ps
// Corrected: combinational Radix-4 unrolled divider (2 bits per step, 16 stages)
// - Signed 32-bit dividend/divisor support
// - Divide-by-zero: quotient = 32'hFFFF_FFFF (sentinel), remainder = abs(dividend)
// - Fully combinational (one-cycle). Heavy logic.

module div_radix4_unrolled (
    input  wire signed [31:0] dividend,
    input  wire signed [31:0] divisor,
    output reg  signed [31:0] quotient,
    output reg  signed [31:0] remainder
);
    localparam W = 32;
    integer i;

    // unsigned magnitudes and sign
    reg [W-1:0] A; // abs(dividend)
    reg [W-1:0] B; // abs(divisor)
    reg         q_sign;

    // remainder workspace: treat as integer magnitude (LSB holds appended bits)
    reg [63:0] rem; 
    reg [31:0] q_stage;

    // 64-bit extended versions of scaled divisors
    reg [63:0] d1_ext, d2_ext, d3_ext;

    // helper to fetch two bits (MSB pair mapping)
    function [1:0] get_two_bits;
        input integer stage;
        begin
            // stage 0 => bits [1:0], ... stage 15 => bits [31:30]
            get_two_bits = A[(2*stage+1) -: 2];
        end
    endfunction

    always @(*) begin
        // defaults
        quotient  = 32'sd0;
        remainder = 32'sd0;
        A = 32'd0; B = 32'd0;
        q_sign = 1'b0;
        rem = 64'd0;
        q_stage = 32'd0;
        d1_ext = 64'd0; d2_ext = 64'd0; d3_ext = 64'd0;

        if (divisor == 32'sd0) begin
            quotient  = 32'hFFFF_FFFF;
            remainder = (dividend[31]) ? -dividend : dividend;
        end else begin
            // abs & sign
            A = dividend[31] ? (~dividend + 1) : dividend;
            B = divisor[31]  ? (~divisor + 1)  : divisor;
            q_sign = dividend[31] ^ divisor[31];

            // prepare extended constants for safe 64-bit compares/subtractions
            d1_ext = {32'd0, B};          // 1 * B (zero-extended to 64b)
            d2_ext = {32'd0, (B << 1)};   // 2 * B
            d3_ext = {32'd0, (B << 1) + B}; // 3 * B = 2B + B

            rem = 64'd0;
            q_stage = 32'd0;

            // process MSB pair first: i = 15 -> A[31:30], down to i = 0 -> A[1:0]
            for (i = 15; i >= 0; i = i - 1) begin
                // shift rem left by 2 and append next two bits at LSB
                rem = (rem << 2) | {62'd0, get_two_bits(i)}; // small zero-extend to match widths

                // choose max digit d in {3,2,1,0} so rem - d*B >= 0
                if (rem >= d3_ext) begin
                    rem = rem - d3_ext;
                    q_stage[2*i +: 2] = 2'b11;
                end else if (rem >= d2_ext) begin
                    rem = rem - d2_ext;
                    q_stage[2*i +: 2] = 2'b10;
                end else if (rem >= d1_ext) begin
                    rem = rem - d1_ext;
                    q_stage[2*i +: 2] = 2'b01;
                end else begin
                    q_stage[2*i +: 2] = 2'b00;
                end
            end

            // apply sign to quotient
            if (q_sign)
                quotient = -$signed(q_stage);
            else
                quotient = $signed(q_stage);

            // remainder magnitude is in rem (should be < B). Take lower 32 bits.
            if (dividend[31])
                remainder = -$signed(rem[31:0]);
            else
                remainder = $signed(rem[31:0]);

            // optional overflow handling (-2^31 / -1)
            if ((dividend == 32'sh8000_0000) && (divisor == -32'sd1)) begin
                quotient  = 32'sh7FFF_FFFF;
                remainder = 32'sd0;
            end
        end
    end
endmodule
