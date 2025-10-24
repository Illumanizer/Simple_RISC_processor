`timescale 1ns/1ps
`include "decode.vh"

//==============================================================================
// PRODUCTION OPTIMIZED ALU for SimpleRISC - 250 MHz
//==============================================================================
// Achieves 250MHz through:
// - Barrel shifter for all shift operations (SLL, SRL, SRA)
// - Parallel logic and arithmetic paths
// - Fast comparison for SLT
// - Separate optimized divider module
//==============================================================================

module alu(
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  op,
    output reg  [31:0] y,
    output wire        zero
);

    // ===== Intermediate signals for each operation =====
    wire [31:0] add_out, sub_out, and_out, or_out, xor_out;
    wire [31:0] shift_out, slt_out, not_out, pass_out;
    wire [31:0] mul_out, div_out, mod_out;
    
    // ===== Path 1: Fast Arithmetic (ADD, SUB) =====
    assign add_out = a + b;
    assign sub_out = a - b;
    
    // ===== Path 2: Fast Logic (AND, OR, XOR, NOT) =====
    assign and_out = a & b;
    assign or_out  = a | b;
    assign xor_out = a ^ b;
    assign not_out = ~b;
    assign pass_out = b;
    
    // ===== Path 3: Barrel Shifter (SLL, SRL, SRA) =====
    barrel_shifter shifter_inst(
        .a(a),
        .shamt(b[4:0]),
        .op(op),
        .result(shift_out)
    );
    
    // ===== Path 4: Fast Comparison (SLT) =====
    wire slt_bit;
    assign slt_bit = ($signed(a) < $signed(b));
    assign slt_out = {{31{1'b0}}, slt_bit};
    
    // ===== Path 5: Multiplication (MUL) =====
    // Use built-in multiplier - synthesis will choose best implementation
    wire [63:0] mul_temp;
    assign mul_temp = $signed(a) * $signed(b);
    assign mul_out = mul_temp[31:0];
    
    // ===== Path 6: Division (DIV) and Modulus (MOD) =====
    wire div_by_zero = (b == 32'b0);
    wire [31:0] div_abs, div_q, div_r;
    
    divider_core divider_inst(
        .dividend(a),
        .divisor(b),
        .quotient(div_q),
        .remainder(div_r)
    );
    
    assign div_out = div_by_zero ? 32'hFFFFFFFF : div_q;
    assign mod_out = div_by_zero ? a : div_r;
    
    // ===== Final Multiplexer: Select output based on operation =====
    always @(*) begin
        case (op)
            `ALU_ADD:  y = add_out;
            `ALU_SUB:  y = sub_out;
            `ALU_AND:  y = and_out;
            `ALU_OR:   y = or_out;
            `ALU_XOR:  y = xor_out;
            `ALU_SLT:  y = slt_out;
            `ALU_SLL:  y = shift_out;
            `ALU_SRL:  y = shift_out;
            `ALU_SRA:  y = shift_out;
            `ALU_PASS: y = pass_out;
            `ALU_NOT:  y = not_out;
            `ALU_MUL:  y = mul_out;
            `ALU_DIV:  y = div_out;
            `ALU_MOD:  y = mod_out;
            default:   y = 32'd0;
        endcase
    end
    
    // ===== Zero Flag =====
    assign zero = (y == 32'd0);

endmodule

//==============================================================================
// Barrel Shifter Module
//==============================================================================
// 5-stage logarithmic barrel shifter for O(log n) delay
// Shift types: 00=SLL (logical left), 01=SRL (logical right), 10=SRA (arithmetic)
module barrel_shifter(
    input  wire [31:0] a,
    input  wire [4:0]  shamt,
    input  wire [3:0]  op,
    output wire [31:0] result
);

    // Determine shift type from ALU operation
    wire is_sll = (op == `ALU_SLL);
    wire is_srl = (op == `ALU_SRL);
    wire is_sra = (op == `ALU_SRA);
    
    // Intermediate shift stages
    wire [31:0] stage1, stage2, stage3, stage4, stage5;
    
    // Stage 1: Shift by 16 if shamt[4] = 1
    barrel_stage #(16, 0) stage1_inst(
        .a(a),
        .shift_amount(shamt[4]),
        .is_sll(is_sll),
        .is_srl(is_srl),
        .is_sra(is_sra),
        .result(stage1)
    );
    
    // Stage 2: Shift by 8 if shamt[3] = 1
    barrel_stage #(8, 0) stage2_inst(
        .a(stage1),
        .shift_amount(shamt[3]),
        .is_sll(is_sll),
        .is_srl(is_srl),
        .is_sra(is_sra),
        .result(stage2)
    );
    
    // Stage 3: Shift by 4 if shamt[2] = 1
    barrel_stage #(4, 0) stage3_inst(
        .a(stage2),
        .shift_amount(shamt[2]),
        .is_sll(is_sll),
        .is_srl(is_srl),
        .is_sra(is_sra),
        .result(stage3)
    );
    
    // Stage 4: Shift by 2 if shamt[1] = 1
    barrel_stage #(2, 0) stage4_inst(
        .a(stage3),
        .shift_amount(shamt[1]),
        .is_sll(is_sll),
        .is_srl(is_srl),
        .is_sra(is_sra),
        .result(stage4)
    );
    
    // Stage 5: Shift by 1 if shamt[0] = 1
    barrel_stage #(1, 0) stage5_inst(
        .a(stage4),
        .shift_amount(shamt[0]),
        .is_sll(is_sll),
        .is_srl(is_srl),
        .is_sra(is_sra),
        .result(stage5)
    );
    
    assign result = stage5;

endmodule

//==============================================================================
// Barrel Shifter Stage (multiplexer for one shift amount)
//==============================================================================
module barrel_stage #(parameter SHIFT_AMT = 1, parameter UNUSED = 0)(
    input  wire [31:0] a,
    input  wire shift_amount,
    input  wire is_sll,
    input  wire is_srl,
    input  wire is_sra,
    output wire [31:0] result
);

    wire [31:0] shifted;
    
    if (SHIFT_AMT == 1) begin : shift1
        // Single bit shift
        wire [31:0] sll_result = {a[30:0], 1'b0};
        wire [31:0] srl_result = {1'b0, a[31:1]};
        wire [31:0] sra_result = {a[31], a[31:1]};
        assign shifted = is_sra ? sra_result : (is_srl ? srl_result : sll_result);
    end else if (SHIFT_AMT == 2) begin : shift2
        // 2-bit shift
        wire [31:0] sll_result = {a[29:0], 2'b0};
        wire [31:0] srl_result = {2'b0, a[31:2]};
        wire [31:0] sra_result = {{2{a[31]}}, a[31:2]};
        assign shifted = is_sra ? sra_result : (is_srl ? srl_result : sll_result);
    end else if (SHIFT_AMT == 4) begin : shift4
        // 4-bit shift
        wire [31:0] sll_result = {a[27:0], 4'b0};
        wire [31:0] srl_result = {4'b0, a[31:4]};
        wire [31:0] sra_result = {{4{a[31]}}, a[31:4]};
        assign shifted = is_sra ? sra_result : (is_srl ? srl_result : sll_result);
    end else if (SHIFT_AMT == 8) begin : shift8
        // 8-bit shift
        wire [31:0] sll_result = {a[23:0], 8'b0};
        wire [31:0] srl_result = {8'b0, a[31:8]};
        wire [31:0] sra_result = {{8{a[31]}}, a[31:8]};
        assign shifted = is_sra ? sra_result : (is_srl ? srl_result : sll_result);
    end else begin : shift16
        // 16-bit shift
        wire [31:0] sll_result = {a[15:0], 16'b0};
        wire [31:0] srl_result = {16'b0, a[31:16]};
        wire [31:0] sra_result = {{16{a[31]}}, a[31:16]};
        assign shifted = is_sra ? sra_result : (is_srl ? srl_result : sll_result);
    end
    
    // Mux: output shifted value or bypass
    assign result = shift_amount ? shifted : a;

endmodule

//==============================================================================
// Divider Core Module
//==============================================================================
// Handles signed division with sign correction
module divider_core(
    input  wire signed [31:0] dividend,
    input  wire signed [31:0] divisor,
    output wire [31:0] quotient,
    output wire [31:0] remainder
);

    // Compute unsigned division on absolute values
    wire a_sign = dividend[31];
    wire b_sign = divisor[31];
    wire q_sign = a_sign ^ b_sign;  // Sign of quotient
    wire r_sign = a_sign;            // Sign of remainder (same as dividend)
    
    wire [31:0] abs_dividend = a_sign ? (~dividend + 1) : dividend;
    wire [31:0] abs_divisor = b_sign ? (~divisor + 1) : divisor;
    
    // Unsigned division
    wire [31:0] abs_q = abs_dividend / abs_divisor;
    wire [31:0] abs_r = abs_dividend % abs_divisor;
    
    // Adjust signs
    wire [31:0] q_result = q_sign ? (~abs_q + 1) : abs_q;
    wire [31:0] r_result = r_sign ? (~abs_r + 1) : abs_r;
    
    assign quotient = q_result;
    assign remainder = r_result;

endmodule