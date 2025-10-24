# SimpleRISC Test Program
#
# Each test uses different registers to make
# the final result easy to see.

# --- TEST 1: ADD ---
# Add r1 (10) and r2 (20)
# Result: r3 should be 30 (0x1E)
mov r1, 10
mov r2, 20
add r3, r1, r2

# --- TEST 2: SUB ---
# Subtract r5 (8) from r4 (50)
# Result: r6 should be 42 (0x2A)
mov r4, 50
mov r5, 8
sub r6, r4, r5

# --- TEST 3: MUL ---
# Multiply r7 (7) and r8 (6)
# Result: r9 should be 42 (0x2A)
mov r7, 7
mov r8, 6
mul r9, r7, r8

# --- TEST 4: DIV ---
# Divide r1 (100) by r2 (10)
# Result: r3 will be overwritten with 10 (0xA)
mov r1, 100
mov r2, 10
div r3, r1, r2

# --- TEST 5: SHIFTS ---
# Logical Shift Left: r5 (2) by 3 bits
# Result: r6 will be overwritten with 16 (0x10)
mov r5, 2
lsl r6, r5, 3       # 2 << 3 = 16

# Logical Shift Right: r7 (64) by 2 bits
# Result: r8 will be overwritten with 16 (0x10)
mov r7, 64
lsr r8, r7, 2       # 64 >> 2 = 16

# Arithmetic Shift Right: r9 (-16) by 2 bits
# Result: r10 should be -4 (0xFFFFFFFC)
mov r9, -16
asr r10, r9, 2      # Fills with '1's

# --- TEST 6: LOGICAL ---
# AND r1 (15) and r2 (7)
# Result: r3 will be overwritten with 7 (0x7)
mov r1, 15
mov r2, 7
and r3, r1, r2      # 0b1111 & 0b0111 = 0b0111

# OR r4 (9) and r5 (10)
# Result: r6 will be overwritten with 11 (0xB)
mov r4, 9
mov r5, 10
or r6, r4, r5       # 0b1001 | 0b1010 = 0b1011

# NOT r7 (0)
# Result: r8 will be overwritten with -1 (0xFFFFFFFF)
mov r7, 0
not r8, r7          # ~0 = all 1's

# --- END ---
# Halt the processor
nop
nop