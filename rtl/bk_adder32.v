// bk_adder32.v
// Brent-Kung style 32-bit adder implemented with a generic prefix-tree.
// Parameterized width = 32 (default).
// Interface: a, b, cin -> sum, cout
`timescale 1ns/1ps

module bk_adder32 #(
    parameter WIDTH = 32,
    parameter LG = 5 // log2(32) = 5
)(
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire             cin,
    output reg  [WIDTH-1:0] sum,
    output reg              cout
);
    // Internal propagate/generate levels
    reg [WIDTH-1:0] p_level [0:LG];
    reg [WIDTH-1:0] g_level [0:LG];

    integer i, k;
    // initial propagate/generate
    always @(*) begin
        for (i = 0; i < WIDTH; i = i + 1) begin
            p_level[0][i] = a[i] ^ b[i];
            g_level[0][i] = a[i] & b[i];
        end

        // prefix computation
        for (k = 1; k <= LG; k = k + 1) begin
            for (i = 0; i < WIDTH; i = i + 1) begin
                if (i < (1 << (k-1))) begin
                    p_level[k][i] = p_level[k-1][i];
                    g_level[k][i] = g_level[k-1][i];
                end else begin
                    p_level[k][i] = p_level[k-1][i] & p_level[k-1][i - (1 << (k-1))];
                    g_level[k][i] = g_level[k-1][i] | (p_level[k-1][i] & g_level[k-1][i - (1 << (k-1))]);
                end
            end
        end

        // compute carries and sum
        // carry into bit 0 is cin
        // carry into bit i (i>=1) is: c[i] = g_LEVEL[LG][i-1] | (p_LEVEL[LG][i-1] & cin)
        for (i = 0; i < WIDTH; i = i + 1) begin
            if (i == 0) begin
                sum[i] = p_level[0][i] ^ cin;
            end else begin
                // compute carry_in for bit i
                // carry_in = g_level[LG][i-1] | (p_level[LG][i-1] & cin)
                sum[i] = p_level[0][i] ^ (g_level[LG][i-1] | (p_level[LG][i-1] & cin));
            end
        end
        // compute cout
        cout = g_level[LG][WIDTH-1] | (p_level[LG][WIDTH-1] & cin);
    end

endmodule
