#!/usr/bin/env python3

import sys
import re

OPCODES = {
    'add': 0b00000, 'sub': 0b00001, 'mul': 0b00010, 'div': 0b00011,
    'mod': 0b00100, 'cmp': 0b00101, 'and': 0b00110, 'or': 0b00111,
    'not': 0b01000, 'mov': 0b01001, 'lsl': 0b01010, 'lsr': 0b01011,
    'asr': 0b01100, 'nop': 0b01101, 'ld': 0b01110, 'st': 0b01111,
    'beq': 0b10000, 'bgt': 0b10001, 'b': 0b10010, 'call': 0b10011,
    'ret': 0b10100,
}

def parse_reg(r):
    r = r.strip()
    if r.startswith('r'): return int(r[1:])
    if r == 'sp': return 14
    if r == 'ra': return 15
    raise ValueError(f"bad reg: {r}")

def parse_imm(s):
    s = s.strip()
    if s.startswith('0x'): return int(s, 16)
    val = int(s)
    if val < 0: val = (1 << 18) + val
    return val & 0x3FFFF

def assemble_line(line, labels, pc):
    if '#' in line: line = line[:line.index('#')]
    line = line.strip()
    if not line or line.endswith(':'): return None
    
    parts = re.split(r'[,\s]+', line)
    op_str = parts[0].lower()
    if op_str not in OPCODES: raise ValueError(f"unknown op: {op_str}")
    
    opcode = OPCODES[op_str]
    
    if op_str in ['nop', 'ret']:
        return opcode << 27
    
    # --- FIX 1: R-R vs R-I for main ALU ops ---
    if op_str in ['add','sub','mul','div','mod','and','or','lsl','lsr','asr']:
        rd = parse_reg(parts[1])
        rs1 = parse_reg(parts[2])
        if parts[3].startswith('r'):
            # R-R format
            i_bit = 0
            rs2 = parse_reg(parts[3])
            # [OP][I=0][RD][RS1][RS2][...unused...]
            return (opcode << 27) | (i_bit << 26) | (rd << 22) | (rs1 << 18) | (rs2 << 14)
        else:
            # R-I format
            i_bit = 1
            imm = parse_imm(parts[3])
            # [OP][I=1][RD][RS1][...IMM(18)...]
            return (opcode << 27) | (i_bit << 26) | (rd << 22) | (rs1 << 18) | (imm & 0x3FFFF)
    
    # --- FIX 2: R-R vs R-I for mov/not ---
    if op_str in ['mov', 'not']:
        rd = parse_reg(parts[1])
        if parts[2].startswith('r'):
            # R-R format
            i_bit = 0
            rs2 = parse_reg(parts[2])
            # [OP][I=0][RD][...unused...][RS2][...unused...]
            return (opcode << 27) | (i_bit << 26) | (rd << 22) | (rs2 << 14)
        else:
            # R-I format
            i_bit = 1
            imm = parse_imm(parts[2])
            # [OP][I=1][RD][...unused...][...IMM(18)...]
            return (opcode << 27) | (i_bit << 26) | (rd << 22) | (imm & 0x3FFFF)
    
    # --- FIX 3: R-R vs R-I for cmp ---
    if op_str == 'cmp':
        rs1 = parse_reg(parts[1])
        if parts[2].startswith('r'):
            # R-R format
            i_bit = 0
            rs2 = parse_reg(parts[2])
            # [OP][I=0][...unused...][RS1][RS2][...unused...]
            return (opcode << 27) | (i_bit << 26) | (rs1 << 18) | (rs2 << 14)
        else:
            # R-I format
            i_bit = 1
            imm = parse_imm(parts[2])
            # [OP][I=1][...unused...][RS1][...IMM(18)...]
            return (opcode << 27) | (i_bit << 26) | (rs1 << 18) | (imm & 0x3FFFF)
    
    if op_str in ['ld', 'st']:
        rd = parse_reg(parts[1])
        m = re.match(r'(-?\d+)\[r(\d+)\]', parts[2])
        if not m: raise ValueError(f"bad mem: {parts[2]}")
        imm = parse_imm(m.group(1))
        rs1 = int(m.group(2))
        return (opcode << 27) | (1 << 26) | (rd << 22) | (rs1 << 18) | (imm & 0x3FFFF)
    
    if op_str in ['beq','bgt','b','call']:
        if parts[1] in labels:
            offset = (labels[parts[1]] - pc) & 0x7FFFFFF
        else:
            offset = parse_imm(parts[1]) & 0x7FFFFFF
        return (opcode << 27) | offset
    
    raise ValueError(f"unhandled: {op_str}")

def assemble(asm_file, hex_file):
    with open(asm_file) as f:
        lines = f.readlines()
    
    # first pass: labels
    labels = {}
    pc = 0
    for line in lines:
        line = line.strip()
        if line.endswith(':'):
            labels[line[:-1]] = pc
        elif line and not line.startswith('#'):
            pc += 1
    
    # second pass: assemble
    instrs = []
    pc = 0
    for line in lines:
        if line.strip().endswith(':'): continue
        instr = assemble_line(line, labels, pc)
        if instr is not None:
            instrs.append(instr)
            pc += 1
    
    with open(hex_file, 'w') as f:
        for i in instrs:
            f.write(f"{i:08x}\n")
    
    print(f"assembled {len(instrs)} instructions -> {hex_file}")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("usage: python3 asm.py input.asm output.hex")
        sys.exit(1)
    assemble(sys.argv[1], sys.argv[2])
