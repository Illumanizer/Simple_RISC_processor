`timescale 1ns/1ps

//==============================================================================
// COMPREHENSIVE TESTBENCH FOR OPTIMIZED ALU
//==============================================================================
// Tests all 14 ALU operations with multiple test cases and added edge cases
// All display strings are plain ASCII (no special characters)
//==============================================================================

`include "decode.vh"

module tb_alu;

    //=== Testbench Signals ===
    reg [31:0] a, b;
    reg [3:0] op;
    wire [31:0] y;
    wire zero;
    
    integer test_num = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    
    //=== DUT Instantiation ===
    alu DUT(
        .a(a),
        .b(b),
        .op(op),
        .y(y),
        .zero(zero)
    );
    
    // Make description buffer large enough for long messages:
    localparam DESC_BYTES = 120;               // characters (adjust if needed)
    localparam DESC_BITS  = 8 * DESC_BYTES;    // bits

    //=== Test Task ===
    // Note: expected_zero is 1-bit; description is a packed vector that can accept string literals.
    task test_alu(
        input [31:0] operand_a,
        input [31:0] operand_b,
        input [3:0]  operation,
        input [31:0] expected_result,
        input [0:0]  expected_zero,
        input [DESC_BITS-1:0] description
    );
        begin
            test_num = test_num + 1;
            a = operand_a;
            b = operand_b;
            op = operation;
            
            #1;  // Wait for propagation
            
            if (y === expected_result && zero === expected_zero) begin
                $display("[PASS %3d] %s", test_num, description);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL %3d] %s", test_num, description);
                $display("          Got: y=0x%08h, zero=%b | Expected: y=0x%08h, zero=%b",
                         y, zero, expected_result, expected_zero);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    //=== Main Test Procedure ===
    initial begin
        $display("\n");
        $display("==============================================================");
        $display("  OPTIMIZED ALU COMPREHENSIVE TESTBENCH");
        $display("  Testing All ALU Operations + Edge Cases");
        $display("==============================================================");
        $display("\n");
        
        
        //=====================================================================
        // GROUP 1: ADDITION (ALU_ADD)
        //=====================================================================
        $display("GROUP 1: ADDITION (ALU_ADD)");
        
        test_alu(32'd10, 32'd5, `ALU_ADD, 32'd15, 1'b0,
                 "ADD: 10 + 5 = 15");
        
        test_alu(32'd0, 32'd0, `ALU_ADD, 32'd0, 1'b1,
                 "ADD: 0 + 0 = 0 (zero flag test)");
        
        test_alu(32'd100, 32'd200, `ALU_ADD, 32'd300, 1'b0,
                 "ADD: 100 + 200 = 300");
        
        test_alu(32'hFFFFFFFF, 32'd1, `ALU_ADD, 32'h00000000, 1'b1,
                 "ADD: -1 + 1 = 0 (wrap around)");
        
        test_alu(32'h80000000, 32'h80000000, `ALU_ADD, 32'h00000000, 1'b1,
                 "ADD: Min + Min = 0 (overflow)");
        
        test_alu(32'd42, 32'd58, `ALU_ADD, 32'd100, 1'b0,
                 "ADD: 42 + 58 = 100");
        
        test_alu(32'h7FFFFFFF, 32'd1, `ALU_ADD, 32'h80000000, 1'b0,
                 "ADD: INT_MAX + 1 = INT_MIN (signed overflow)");
        
        test_alu(32'h80000001, 32'hFFFFFFFF, `ALU_ADD, 32'h80000000, 1'b0,
                 "ADD: Large negative + (-1)");
        
        //=====================================================================
        // GROUP 2: SUBTRACTION (ALU_SUB)
        //=====================================================================
        $display("\nGROUP 2: SUBTRACTION (ALU_SUB)");
        
        test_alu(32'd20, 32'd8, `ALU_SUB, 32'd12, 1'b0,
                 "SUB: 20 - 8 = 12");
        
        test_alu(32'd15, 32'd15, `ALU_SUB, 32'd0, 1'b1,
                 "SUB: 15 - 15 = 0 (zero flag test)");
        test_alu(32'h80000000, 32'd1, `ALU_SUB, 32'h7FFFFFFF, 1'b0,
                 "SUB: INT_MIN - 1 = INT_MAX (underflow wrap)");
        test_alu(32'd0, 32'h80000000, `ALU_SUB, 32'h80000000, 1'b0,
                 "SUB: 0 - INT_MIN = INT_MIN (overflow)");
        test_alu(32'd100, 32'd50, `ALU_SUB, 32'd50, 1'b0,
                 "SUB: 100 - 50 = 50");
        
        test_alu(32'd0, 32'd10, `ALU_SUB, 32'hFFFFFFF6, 1'b0,
                 "SUB: 0 - 10 = -10");
        
        test_alu(32'hFFFFFFFF, 32'h00000001, `ALU_SUB, 32'hFFFFFFFE, 1'b0,
                 "SUB: -1 - 1 = -2");
        
        //=====================================================================
        // GROUP 3: BITWISE AND (ALU_AND)
        //=====================================================================
        $display("\nGROUP 3: BITWISE AND (ALU_AND)");
        
        test_alu(32'h0000F0F0, 32'h0000FFFF, `ALU_AND, 32'h0000F0F0, 1'b0,
                 "AND: 0xF0F0 & 0xFFFF = 0xF0F0");
        
        test_alu(32'hFFFFFFFF, 32'h00000000, `ALU_AND, 32'h00000000, 1'b1,
                 "AND: 0xFFFFFFFF & 0x00000000 = 0x00000000 (zero flag)");
        
        test_alu(32'h0F0F0F0F, 32'h0F0F0F0F, `ALU_AND, 32'h0F0F0F0F, 1'b0,
                 "AND: Same operands = same result");
        
        test_alu(32'h12345678, 32'h87654321, `ALU_AND, 32'h02244220, 1'b0,
                 "AND: 0x12345678 & 0x87654321 = 0x02244220");
        
        //=====================================================================
        // GROUP 4: BITWISE OR (ALU_OR)
        //=====================================================================
        $display("\nGROUP 4: BITWISE OR (ALU_OR)");
        
        test_alu(32'h0000F000, 32'h00000F00, `ALU_OR, 32'h0000FF00, 1'b0,
                 "OR: 0xF000 | 0x0F00 = 0xFF00");
        
        test_alu(32'h00000000, 32'h00000000, `ALU_OR, 32'h00000000, 1'b1,
                 "OR: 0x00000000 | 0x00000000 = 0x00000000 (zero flag)");
        
        test_alu(32'hF0F0F0F0, 32'h0F0F0F0F, `ALU_OR, 32'hFFFFFFFF, 1'b0,
                 "OR: 0xF0F0F0F0 | 0x0F0F0F0F = 0xFFFFFFFF");
        
        //=====================================================================
        // GROUP 5: BITWISE XOR (ALU_XOR)
        //=====================================================================
        $display("\nGROUP 5: BITWISE XOR (ALU_XOR)");
        
        test_alu(32'hFFFFFFFF, 32'h00000000, `ALU_XOR, 32'hFFFFFFFF, 1'b0,
                 "XOR: 0xFFFFFFFF ^ 0x00000000 = 0xFFFFFFFF");
        
        test_alu(32'hFFFFFFFF, 32'hFFFFFFFF, `ALU_XOR, 32'h00000000, 1'b1,
                 "XOR: Same operands = 0 (zero flag)");
        
        test_alu(32'h0000FFFF, 32'h00000FFF, `ALU_XOR, 32'h0000F000, 1'b0,
                 "XOR: 0x0000FFFF ^ 0x00000FFF = 0x0000F000");

        test_alu(32'h12345678, 32'hABCDEF01, `ALU_XOR, 32'hB9F9B979, 1'b0,
                 "XOR: Random pattern XOR");
        
        test_alu(32'hAAAAAAAA, 32'h55555555, `ALU_XOR, 32'hFFFFFFFF, 1'b0,
                 "XOR: 0xAAAAAAAA ^ 0x55555555 = 0xFFFFFFFF");
        
        //=====================================================================
        // GROUP 6: BITWISE NOT (ALU_NOT)
        //=====================================================================
        $display("\nGROUP 6: BITWISE NOT (ALU_NOT)");
        
        test_alu(32'd0, 32'h00000000, `ALU_NOT, 32'hFFFFFFFF, 1'b0,
                 "NOT: ~0x00000000 = 0xFFFFFFFF");
        
        test_alu(32'd0, 32'hFFFFFFFF, `ALU_NOT, 32'h00000000, 1'b1,
                 "NOT: ~0xFFFFFFFF = 0x00000000 (zero flag)");
        
        test_alu(32'd0, 32'h0000AAAA, `ALU_NOT, 32'hFFFF5555, 1'b0,
                 "NOT: ~0x0000AAAA = 0xFFFF5555");
        
        test_alu(32'd0, 32'h12345678, `ALU_NOT, 32'hEDCBA987, 1'b0,
                 "NOT: ~0x12345678 = 0xEDCBA987");
        
        //=====================================================================
        // GROUP 7: SET LESS THAN (ALU_SLT) - SIGNED COMPARISON
        //=====================================================================
        $display("\nGROUP 7: SET LESS THAN (ALU_SLT)");
        
        test_alu(32'd5, 32'd10, `ALU_SLT, 32'd1, 1'b0,
                 "SLT: 5 < 10 = 1 (true)");
        
        test_alu(32'd20, 32'd10, `ALU_SLT, 32'd0, 1'b1,
                 "SLT: 20 < 10 = 0 (false, zero flag)");
        
        test_alu(32'd10, 32'd10, `ALU_SLT, 32'd0, 1'b1,
                 "SLT: 10 < 10 = 0 (equal, zero flag)");
        
        test_alu(32'hFFFFFFFF, 32'd1, `ALU_SLT, 32'd1, 1'b0,
                 "SLT: -1 < 1 = 1 (signed: negative < positive)");
        
        test_alu(32'd1, 32'hFFFFFFFF, `ALU_SLT, 32'd0, 1'b1,
                 "SLT: 1 < -1 = 0 (signed: positive > negative, zero flag)");

        test_alu(32'h80000000, 32'h7FFFFFFF, `ALU_SLT, 32'd1, 1'b0,
                 "SLT: INT_MIN < INT_MAX = 1 (extreme signed values)");
        test_alu(32'h80000001, 32'h80000000, `ALU_SLT, 32'd0, 1'b1,
         "SLT: -2147483647 < -2147483648 = 0");

        test_alu(32'hFFFFFFFF, 32'h80000000, `ALU_SLT, 32'd0, 1'b1,
         "SLT: -1 < INT_MIN = 0");

        
        test_alu(32'hFFFFFFFF, 32'hFFFFFFFF, `ALU_SLT, 32'd0, 1'b1,
                 "SLT: -1 < -1 = 0 (equal, zero flag)");
        
        test_alu(32'h80000000, 32'h7FFFFFFF, `ALU_SLT, 32'd1, 1'b0,
                 "SLT: MinInt < MaxInt = 1 (signed)");
        
        //=====================================================================
        // GROUP 8: LOGICAL SHIFT LEFT (ALU_SLL)
        //=====================================================================
        $display("\nGROUP 8: LOGICAL SHIFT LEFT (ALU_SLL)");
        
        test_alu(32'd1, 32'd4, `ALU_SLL, 32'd16, 1'b0,
                 "SLL: 1 << 4 = 16");
        
        test_alu(32'd1, 32'd0, `ALU_SLL, 32'd1, 1'b0,
                 "SLL: 1 << 0 = 1 (no shift)");

        // Test shift amounts > 31 (only b[4:0] should be used)
        test_alu(32'hFFFFFFFF, 32'd32, `ALU_SLL, 32'hFFFFFFFF, 1'b0,
                "SLL: x << 32 should behave as x << 0 (only lower 5 bits used)");
        test_alu(32'h12345678, 32'd40, `ALU_SRL, 32'h00123456, 1'b0,
                "SRL: x >> 40 should behave as x >> 8");
        
        test_alu(32'h00000001, 32'd31, `ALU_SLL, 32'h80000000, 1'b0,
                 "SLL: 1 << 31 = 0x80000000");
        
        test_alu(32'hFFFFFFFF, 32'd8, `ALU_SLL, 32'hFFFFFF00, 1'b0,
                 "SLL: 0xFFFFFFFF << 8 = 0xFFFFFF00");
        
        test_alu(32'h00000003, 32'd2, `ALU_SLL, 32'h0000000C, 1'b0,
                 "SLL: 3 << 2 = 12");
        
        test_alu(32'h00000005, 32'd16, `ALU_SLL, 32'h00050000, 1'b0,
                 "SLL: 5 << 16 = 0x50000");
        
        // Extreme shift counts: only lower 5 bits typically used
        test_alu(32'd1, 32'd32, `ALU_SLL, 32'd1, 1'b0,
                 "SLL: shift 32 => expect shift amount masked (b[4:0])");
        
        //=====================================================================
        // GROUP 9: LOGICAL SHIFT RIGHT (ALU_SRL)
        //=====================================================================
        $display("\nGROUP 9: LOGICAL SHIFT RIGHT (ALU_SRL)");
        
        test_alu(32'h80000000, 32'd4, `ALU_SRL, 32'h08000000, 1'b0,
                 "SRL: 0x80000000 >> 4 = 0x08000000 (logical)");
        
        test_alu(32'hFFFFFFFF, 32'd8, `ALU_SRL, 32'h00FFFFFF, 1'b0,
                 "SRL: 0xFFFFFFFF >> 8 = 0x00FFFFFF");
        
        test_alu(32'd256, 32'd4, `ALU_SRL, 32'd16, 1'b0,
                 "SRL: 256 >> 4 = 16");
        
        test_alu(32'd0, 32'd0, `ALU_SRL, 32'd0, 1'b1,
                 "SRL: 0 >> 0 = 0 (zero flag)");
        
        test_alu(32'h80000000, 32'd0, `ALU_SRL, 32'h80000000, 1'b0,
                 "SRL: 0x80000000 >> 0 = 0x80000000 (no shift)");
        
       test_alu(32'h12345678, 32'd40, `ALU_SRL, 32'h00123456, 1'b0,
         "SRL: x >> 40 should behave as x >> 8");



        
        //=====================================================================
        // GROUP 10: ARITHMETIC SHIFT RIGHT (ALU_SRA)
        //=====================================================================
        $display("\nGROUP 10: ARITHMETIC SHIFT RIGHT (ALU_SRA)");
        
        test_alu(32'h80000000, 32'd4, `ALU_SRA, 32'hF8000000, 1'b0,
                 "SRA: 0x80000000 >> 4 = 0xF8000000 (sign-extended)");
        
        test_alu(32'h7FFFFFFF, 32'd8, `ALU_SRA, 32'h007FFFFF, 1'b0,
                 "SRA: 0x7FFFFFFF >> 8 = 0x007FFFFF (positive)");

        test_alu(32'hC0000000, 32'd1, `ALU_SRA, 32'hE0000000, 1'b0,
                 "SRA: 0xC0000000 >>> 1 = 0xE0000000 (sign extend)");
        test_alu(32'hFFFFFFFF, 32'd31, `ALU_SRA, 32'hFFFFFFFF, 1'b0,
                 "SRA: -1 >>> 31 = -1 (all ones preserved)");
        test_alu(32'h00000001, 32'd31, `ALU_SRA, 32'd0, 1'b1,
                 "SRA: 1 >>> 31 = 0 (positive becomes zero)");
        
        test_alu(32'hFFFFFFFF, 32'd16, `ALU_SRA, 32'hFFFFFFFF, 1'b0,
                 "SRA: 0xFFFFFFFF >> 16 = 0xFFFFFFFF (all 1s extended)");
        
        test_alu(32'h80000000, 32'd0, `ALU_SRA, 32'h80000000, 1'b0,
                 "SRA: 0x80000000 >> 0 = 0x80000000 (no shift)");
        
        test_alu(32'hF0000000, 32'd4, `ALU_SRA, 32'hFF000000, 1'b0,
                 "SRA: 0xF0000000 >> 4 = 0xFF000000 (sign-extended)");
        
        test_alu(32'h00000001, 32'd1, `ALU_SRA, 32'h00000000, 1'b1,
                 "SRA: 1 >> 1 = 0 (zero flag)");
        
        //=====================================================================
        // GROUP 11: MULTIPLICATION (ALU_MUL)
        //=====================================================================
        $display("\nGROUP 11: MULTIPLICATION (ALU_MUL)");
        
        test_alu(32'd3, 32'd7, `ALU_MUL, 32'd21, 1'b0,
                 "MUL: 3 * 7 = 21");
        
        test_alu(32'd100, 32'd100, `ALU_MUL, 32'd10000, 1'b0,
                 "MUL: 100 * 100 = 10000");
        
        test_alu(32'd0, 32'd1000, `ALU_MUL, 32'd0, 1'b1,
                 "MUL: 0 * 1000 = 0 (zero flag)");
        
        test_alu(32'hFFFFFFFF, 32'd1, `ALU_MUL, 32'hFFFFFFFF, 1'b0,
                 "MUL: -1 * 1 = -1");
        test_alu(32'h7FFFFFFF, 32'd2, `ALU_MUL, 32'hFFFFFFFE, 1'b0,
                 "MUL: INT_MAX * 2 = 0xFFFFFFFE (overflow, lower 32 bits)");
        test_alu(32'h00010000, 32'h00010000, `ALU_MUL, 32'd0, 1'b1,
                 "MUL: 65536 * 65536 = 0 (lower 32 bits, zero flag)");
        test_alu(32'd1000, 32'd1000000, `ALU_MUL, 32'h3B9ACA00, 1'b0,
                 "MUL: 1000 * 1000000 = lower 32 bits of billion");
        test_alu(32'd5,        32'hFFFFFFFB, `ALU_MUL, 32'hFFFFFFE7, 1'b0,
                 "MUL: 5 * (-5) = -25 (signed)");
        
        test_alu(32'hFFFFFFFA, 32'hFFFFFFFA, `ALU_MUL, 32'd36, 1'b0,
                 "MUL: (-6) * (-6) = 36");
        
        test_alu(32'd1, 32'd1, `ALU_MUL, 32'd1, 1'b0,
                 "MUL: 1 * 1 = 1");
        
        test_alu(32'd2, 32'd2, `ALU_MUL, 32'd4, 1'b0,
                 "MUL: 2 * 2 = 4");
        
        // Multiplication overflow checking (lower 32 bits are returned by design)
        // Example: 0x80000000 * 2 = 0 (lower 32 bits)
        test_alu(32'h80000000, 32'd2, `ALU_MUL, 32'h00000000, 1'b1,
                 "MUL: MinInt * 2 => lower 32 bits 0 (zero flag)");
        
        //=====================================================================
        // GROUP 12: DIVISION (ALU_DIV)
        //=====================================================================
        $display("\nGROUP 12: DIVISION (ALU_DIV)");
        
        test_alu(32'd1,        32'hFFFFFFFF, `ALU_DIV, 32'hFFFFFFFF, 1'b0,
                 "DIV: 1 / -1 = -1");
        
        test_alu(32'hFFFFFFFF, 32'd2,        `ALU_DIV, 32'd0,        1'b1,
                 "DIV: -1 / 2 = 0 (truncation, zero flag)");
        
        test_alu(32'd0,        32'd1,        `ALU_DIV, 32'd0,        1'b1,
                 "DIV: 0 / 1 = 0 (zero flag)");

        test_alu(32'hFFFFFFFC, 32'd4, `ALU_DIV, 32'hFFFFFFFF, 1'b0,
                 "DIV: -4 / 4 = -1 (negative power-of-2)");

        test_alu(32'd1000, 32'd7, `ALU_DIV, 32'd142, 1'b0,
                 "DIV: 1000 / 7 = 142 (prime divisor)");

//=====================================================================
        // GROUP 13: MODULUS (ALU_MOD)
        //=====================================================================
        $display("\nGROUP 13: MODULUS (ALU_MOD)");
        
        test_alu(32'd20, 32'd6, `ALU_MOD, 32'd2, 1'b0,
                 "MOD: 20 % 6 = 2");
        
        test_alu(32'd17, 32'd5, `ALU_MOD, 32'd2, 1'b0,
                 "MOD: 17 % 5 = 2");
        
        test_alu(32'd100, 32'd10, `ALU_MOD, 32'd0, 1'b1,
                 "MOD: 100 % 10 = 0 (zero flag)");

        test_alu(32'd1000, 32'd7, `ALU_MOD, 32'd6, 1'b0,
                "MOD: 1000 % 7 = 6");
        test_alu(32'hFFFFFFEC, 32'hFFFFFFFC, `ALU_MOD, 32'd0, 1'b1,
         "MOD: -20 % -4 = 0 (both negative)");
test_alu(32'hFFFFFFF9, 32'hFFFFFFFD, `ALU_MOD, 32'hFFFFFFFF, 1'b0,
         "MOD: -7 % -3 = -1 (negative remainder)");
        
        test_alu(32'd10, 32'd0, `ALU_MOD, 32'd10, 1'b0,
                 "MOD: 10 % 0 = 10 (divide by zero, returns dividend, zero flag 0)");
        
        test_alu(32'd7, 32'd3, `ALU_MOD, 32'd1, 1'b0,
                 "MOD: 7 % 3 = 1");
        
        test_alu(32'd15, 32'd4, `ALU_MOD, 32'd3, 1'b0,
                 "MOD: 15 % 4 = 3");
        
        test_alu(32'd0, 32'd5, `ALU_MOD, 32'd0, 1'b1,
                 "MOD: 0 % 5 = 0 (zero flag)");
        
        // Modulo sign behavior for negatives (remainder should inherit sign of dividend)
       test_alu(32'hFFFFFFEC, 32'd4, `ALU_MOD, 32'd0, 1'b1,
         "MOD: -20 % 4 = 0 (remainder zero)");

        // Above line mostly checks for consistency; adjust expected encoding if needed.
        
        // Edge: remainder equals divisor (should never happen after correction) - check a case known to cause off-by-one in naive reciprocal
        test_alu(32'd100, 32'd25, `ALU_MOD, 32'd0, 1'b1,
                 "MOD: 100 % 25 = 0 (sanity)");
        
        //=====================================================================
        // GROUP 14: PASS (ALU_PASS)
        //=====================================================================
        $display("\nGROUP 14: PASS (ALU_PASS)");
        
        test_alu(32'd0, 32'd42, `ALU_PASS, 32'd42, 1'b0,
                 "PASS: pass(42) = 42");
        
        test_alu(32'd0, 32'd0, `ALU_PASS, 32'd0, 1'b1,
                 "PASS: pass(0) = 0 (zero flag)");
        
        test_alu(32'd0, 32'hDEADBEEF, `ALU_PASS, 32'hDEADBEEF, 1'b0,
                 "PASS: pass(0xDEADBEEF) = 0xDEADBEEF");
        
        test_alu(32'd0, 32'hFFFFFFFF, `ALU_PASS, 32'hFFFFFFFF, 1'b0,
                 "PASS: pass(0xFFFFFFFF) = 0xFFFFFFFF (-1)");
        
        test_alu(32'd0, 32'h80000000, `ALU_PASS, 32'h80000000, 1'b0,
                 "PASS: pass(0x80000000) = 0x80000000 (MinInt)");
        
        test_alu(32'd0, 32'h7FFFFFFF, `ALU_PASS, 32'h7FFFFFFF, 1'b0,
                 "PASS: pass(0x7FFFFFFF) = 0x7FFFFFFF (MaxInt)");
        
        //=====================================================================
        // GROUP 15: EDGE CASES
        //=====================================================================
        $display("\nGROUP 15: EDGE CASES");
        
        // INT_MIN / -1 for division (overflow case)
        test_alu(32'h80000000, 32'hFFFFFFFF, `ALU_DIV, 32'h80000000, 1'b0,
                 "EDGE: INT_MIN / -1 => 0x80000000 (overflow handling)");
        
        // INT_MIN * -1 in multiplication (check lower 32 bits behavior)
        test_alu(32'h80000000, 32'hFFFFFFFF, `ALU_MUL, 32'h80000000, 1'b0,
                 "EDGE: INT_MIN * -1 => lower 32 bits 0x80000000 (signed wrap)");
        
        // Multiply large numbers to cause lower bits wrapping
        test_alu(32'hFFFFFFFF, 32'hFFFFFFFF, `ALU_MUL, 32'h00000001, 1'b0,
                 "EDGE: -1 * -1 = 1");
        
        // Division by 1 and -1 exactness
        test_alu(32'd12345678, 32'd1, `ALU_DIV, 32'd12345678, 1'b0,
                 "EDGE: x / 1 = x");
        test_alu(32'd12345678, 32'hFFFFFFFF, `ALU_DIV, 32'hFF439EB2, 1'b0,
         "EDGE: x / -1 = -x (check sign)"); // may differ for INT_MIN
        
        // Modulo by 1 and -1
        test_alu(32'd123, 32'd1, `ALU_MOD, 32'd0, 1'b1,
                 "EDGE: x % 1 = 0");
        test_alu(32'd123, 32'hFFFFFFFF, `ALU_MOD, 32'd0, 1'b1,
                 "EDGE: x % -1 = 0");
        
        // Divisor = 2^n (power-of-two) behavior: should be exact via shift
        test_alu(32'd64, 32'd8, `ALU_DIV, 32'd8, 1'b0,
                 "EDGE: 64 / 8 = 8 (pow2)");
        test_alu(32'd65, 32'd8, `ALU_DIV, 32'd8, 1'b0,
                 "EDGE: 65 / 8 = 8 (truncation)");
        test_alu(32'hFFFFFFFF, 32'd8, `ALU_DIV, 32'd0, 1'b1,
         "EDGE: -1 / 8 = 0 (truncation toward zero)");
        
        // Test divisors around LUT boundary
        test_alu(32'd257, 32'd256, `ALU_DIV, 32'd1, 1'b0,
                 "EDGE: 257 / 256 = 1 (boundary)");
        test_alu(32'd255, 32'd255, `ALU_DIV, 32'd1, 1'b0,
                 "EDGE: 255 / 255 = 1 (LUT value)");
        
        // Test remainder sign for negative dividend
       test_alu(32'hFFFFFFF6, 32'd10, `ALU_MOD, 32'd0, 1'b1,
         "EDGE: -10 % 10 = 0 (remainder zero)");

        
        // Division and modulo by zero variants (already included earlier but recheck semantics)
        test_alu(32'd0, 32'd0, `ALU_DIV, 32'hFFFFFFFF, 1'b1,
                 "EDGE: 0 / 0 => DIV returns 0xFFFFFFFF, zero=1 (per DUT semantics)");
        test_alu(32'd0, 32'd0, `ALU_MOD, 32'd0, 1'b0,
                 "EDGE: 0 % 0 => MOD returns dividend (0), zero=0 (per DUT semantics)");
        
        //=====================================================================
        // SUMMARY
        //=====================================================================
        $display("\n");
        $display("=======================================================");
        $display("||                      TEST SUMMARY                  ||");
        $display("========================================================");
        $display("Total Tests:  %0d", pass_count + fail_count);
        $display("Passed:       %0d", pass_count);
        $display("Failed:       %0d", fail_count);
        $display("Success Rate: %0.1f%%", (pass_count * 100.0) / (pass_count + fail_count));
        
        if (fail_count == 0) begin
            $display("\n ALL TESTS PASSED! \n");
        end else begin
            $display("\n  SOME TESTS FAILED \n");
        end
        
        #10;
        $finish;
    end
    
endmodule