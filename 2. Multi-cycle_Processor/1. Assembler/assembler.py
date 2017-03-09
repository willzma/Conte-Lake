from pathlib import Path

import argparse
import sys

# Assembler global variables/resources (used in every section of code)
orig_address = 0 # Keep track of the orig address; for WORD vs BYTE
current_address = 0 # Keep track of current address; relative to .ORIG
names = {} # Define an empty dictionary to build .NAME's
labels = {} # Define an empty dictionary to build labels
program_statements = [] # Define an empty list to build actual program statements
output_statements = [] # Define an empty list to build the output MIF
registers = { # Register mapping names to register numbers
    "zero": 0, "r0": 0,
    "r1": 1, "a0": 1,
    "r2": 2, "a1": 2,
    "r3": 3, "a2": 3,
    "r4": 4, "a3": 4, "rv": 4,
    "r5": 5, "t0": 5,
    "r6": 6, "t1": 6,
    "r7": 7, "s0": 7,
    "r8": 8, "s1": 8,
    "r9": 9, "s2": 9,
    "r10": 10,
    "r11": 11,
    "r12": 12,
    "r13": 13, "fp": 13,
    "r14": 14, "sp": 14,
    "r15": 15, "ra": 15 }

opcodes = { # Map opcodes to their binary counterparts
    "beq": 0b001000, "blt": 0b001001, "ble": 0b001010, "bne": 0b001011,
    "br": 0b001000, "bgt": 0b001001, "bge": 0b001010,
    "jal": 0b001100, "ret": 0b001100, "call": 0b001100, "jmp": 0b001100,
    "lw": 0b010010, "sw": 0b011010,
    "addi": 0b100000, "andi": 0b100100, "ori": 0b100101, "xori": 0b100110,
    "subi": 0b100000 }

ext_opcodes = { # Map EXT opcodes to their binary counterparts
    "eq": 0b00000000001000, "lt": 0b00000000001001, "le": 0b00000000001010,
    "gt": 0b00000000001001, "ge": 0b00000000001010,
    "ne": 0b00000000001011, "add": 0b00000000100000, "and": 0b00000000100100,
    "or": 0b00000000100101, "xor": 0b00000000100110, "sub": 0b00000000101000,
    "nand": 0b00000000101100, "not": 0b00000000101100, "nor": 0b00000000101101,
    "nxor": 0b00000000101110, "rshf": 0b00000000110000, "lshf": 0b00000000110001 }

### Below code defines utility functions (used throughout)
def get_opcode(statement): # Only use this for pre-stripped, filtered statements
    opcode = ""
    for char in statement:
        if char == "\t" or char == " ": break
        else: opcode += char
    return opcode

def offset(literal): # Automatically checks immediates and whether they're HEX or DEC
    if "x" in literal: return int(literal, 16)
    else: return int(literal)

def pack_imm(opcode, imm, rs, rt): # Packing function for I-type instructions
    output = opcodes[opcode.lower()] << 26
    output |= (imm & 0xFFFF) << 8
    output |= rs << 4
    output |= rt
    return output

def pack_reg(opcode, rd, rs, rt): # Packing function for R-type instructions
    output = ext_opcodes[opcode.lower()] << 18
    output |= rd << 8
    output |= rs << 4
    output |= rt
    return output

### Below code defines assembler directive code
def orig(statement): # Directive to change the current memory location
    global orig_address
    global current_address
    if ";" in statement: # Remove any comments (not needed to assemble)
        statement = statement.partition(";")[0].strip()
    if ".ORG" in statement:
        orig_address = int(offset(statement.partition(".ORG")[2].strip()) / 4)
    else:
        orig_address = int(offset(statement.partition(".ORIG")[2].strip()) / 4)
    current_address = orig_address

def name(statement): # Directive to define some constant
    if ";" in statement: # Remove any comments (not needed to assemble)
        statement = statement.partition(";")[0].strip()
    tuple = statement.partition(".NAME")[2].strip().split("=")
    names[tuple[0].strip()] = offset(tuple[1].strip())

def word(statement): # Directive to define some memory variable
    hex_word = statement[1].partition(".WORD")[2].strip()
    if hex_word in labels: hex_word = int(labels[hex_word])
    elif hex_word in names: hex_word = int(names[hex_word])
    else: hex_word = offset(hex_word)
    output_statements.append([statement[0], hex_word, statement[1].strip()])

### EXT instructions and pseudoinstructions (ADD, AND, LT, LE, etc.)
def ext(statement):
    opcode = get_opcode(statement[1])
    params = statement[1].partition(opcode)[2].split(",")
    rd = registers[params[0].strip().lower()]
    rs = registers[params[1].strip().lower()]
    rt = registers[params[2].strip().lower()]
    output_statements.append([statement[0],
                            pack_reg(opcode, rd, rs, rt),
                            statement[1].strip()])

def ext_not(statement):
    opcode = get_opcode(statement[1])
    params = statement[1].partition(opcode)[2].split(",")
    rd = registers[params[0].strip().lower()]
    rs = registers[params[1].strip().lower()]
    output_statements.append([statement[0],
                            pack_reg(opcode, rd, rs, rs),
                            statement[1].strip()])

def ext_gtge(statement):
    opcode = get_opcode(statement[1])
    params = statement[1].partition(opcode)[2].split(",")
    rd = registers[params[0].strip().lower()]
    rs = registers[params[1].strip().lower()]
    rt = registers[params[2].strip().lower()]
    output_statements.append([statement[0],
                            pack_reg(opcode, rd, rt, rs),
                            statement[1].strip()])

### Branch instructions and pseudoinstructions (BEQ, BGE, BR, etc.)
def branch(statement):
    opcode = get_opcode(statement[1])
    params = statement[1].partition(opcode)[2].split(",")
    rs = registers[params[0].strip().lower()]
    rt = registers[params[1].strip().lower()]
    imm = params[2].strip()
    if imm in labels: imm = int(labels[imm]) - int(statement[0]) - 1
    elif imm in names: imm = int(names[imm]) - int(statement[0]) - 1
    else: imm = offset(imm)
    output_statements.append([statement[0],
                            pack_imm(opcode, imm, rs, rt),
                            statement[1].strip()])

def branch_br(statement):
    opcode = get_opcode(statement[1])
    imm = statement[1].partition("br")[2].strip()
    if imm in labels: imm = int(labels[imm]) - int(statement[0]) - 1
    elif imm in names: imm = int(names[imm]) - int(statement[0]) - 1
    else: imm = offset(imm)
    output = opcodes[opcode] << 26
    output |= (imm & 0xFFFF) << 8
    output_statements.append([statement[0], output, statement[1].strip()])

def branch_gtge(statement):
    opcode = get_opcode(statement[1])
    params = statement[1].partition(opcode)[2].split(",")
    rs = registers[params[0].strip().lower()]
    rt = registers[params[1].strip().lower()]
    imm = params[2].strip()
    if imm in labels: imm = int(labels[imm]) - int(statement[0]) - 1
    elif imm in names: imm = int(names[imm]) - int(statement[0]) - 1
    else: imm = offset(imm)
    output_statements.append([statement[0],
                            pack_imm(opcode, imm, rt, rs),
                            statement[1].strip()])

### Base + offset instructions/pseudoinstructions (JAL and LW/SW)
def base_offset(statement):
    opcode = get_opcode(statement[1])
    params = statement[1].partition(opcode)[2].split(",")
    rt = registers[params[0].strip().lower()]
    imm = params[1].strip().partition("(")[0]
    rs = registers[params[1].strip().partition("(")[2].partition(")")[0].lower()]
    if imm in labels: imm = int(labels[imm])
    elif imm in names: imm = int(names[imm])
    else: imm = offset(imm)
    output_statements.append([statement[0],
                            pack_imm(opcode, imm, rs, rt),
                            statement[1].strip()])

def base_offset_ret(statement):
    output_statements.append([statement[0], 0x300000fa, statement[1].strip()])

def base_offset_call(statement):
    opcode = get_opcode(statement[1])
    params = statement[1].partition(opcode)[2]
    imm = params.strip().partition("(")[0]
    rs = registers[params.strip().partition("(")[2].partition(")")[0].lower()]
    if imm in labels: imm = int(labels[imm])
    elif imm in names: imm = int(names[imm])
    else: imm = offset(imm)
    output_statements.append([statement[0],
                            pack_imm(opcode, imm, rs, 15),
                            statement[1].strip()])

def base_offset_jmp(statement):
    opcode = get_opcode(statement[1])
    params = statement[1].partition(opcode)[2]
    imm = params.strip().partition("(")[0]
    rs = registers[params.strip().partition("(")[2].partition(")")[0].lower()]
    if imm in labels: imm = int(labels[imm])
    elif imm in names: imm = int(names[imm])
    else: imm = offset(imm)
    output_statements.append([statement[0],
                            pack_imm(opcode, imm, rs, 10),
                            statement[1].strip()])

### ALU immediate instructions/pseudoinstructions (ADDI, ANDI, SUBI, etc.)
def alui(statement):
    opcode = get_opcode(statement[1])
    params = statement[1].partition(opcode)[2].split(",")
    rs = registers[params[0].strip().lower()]
    rt = registers[params[1].strip().lower()]
    imm = params[2].strip()
    if imm in labels:
        if labels[imm].bit_length() > 16:
            print("Assembly failed: Label " + imm + " bit-width too wide for immediate")
            sys.exit()
        else: imm = 4 * int(labels[imm])
    elif imm in names:
        if names[imm].bit_length() > 16:
            print("Assembly failed: Name " + imm + " bit-width too wide for immediate")
            sys.exit()
        else: imm = int(names[imm])
    else: imm = offset(imm)
    output_statements.append([statement[0],
                            pack_imm(opcode, imm, rs, rt),
                            statement[1].strip()])

def alui_subi(statement):
    opcode = get_opcode(statement[1])
    params = statement[1].partition(opcode)[2].split(",")
    rs = registers[params[0].strip().lower()]
    rt = registers[params[1].strip().lower()]
    imm = params[2].strip()
    if imm in labels:
        if labels[imm].bit_length() > 16:
            print("Assembly failed: Label " + imm + " bit-width too wide for immediate")
            sys.exit()
        else: imm = 4 * int(labels[imm])
    elif imm in names:
        if names[imm].bit_length() > 16:
            print("Assembly failed: Name " + imm + " bit-width too wide for immediate")
            sys.exit()
        else: imm = int(labels[imm])
    else: imm = offset(imm)
    output_statements.append([statement[0],
                            pack_imm(opcode, -1 * imm, rs, rt),
                            statement[1].strip()])

# Case statements for assembler directives and opcode functions
assembler_directives = { # Map assembler directives to associated functions
    ".ORIG": orig, ".ORG": orig, ".NAME": name}

opcodes_functions = { # Map opcodes to their respective assembler functions
    "eq": ext, "lt": ext, "le": ext, "ne": ext, "gt": ext_gtge, "ge": ext_gtge,
    "add": ext, "and": ext, "or": ext, "xor": ext, "sub": ext, "not": ext_not,
    "nand": ext, "nor": ext, "nxor": ext, "rshf": ext, "lshf": ext, ".word": word,
    "beq": branch, "blt": branch, "ble": branch, "bne": branch, "jmp": base_offset_jmp,
    "br": branch_br, "bgt": branch_gtge, "bge": branch_gtge, "call": base_offset_call,
    "jal": base_offset, "ret": base_offset_ret, "lw": base_offset, "sw": base_offset,
    "addi": alui, "andi": alui, "ori": alui, "xori": alui, "subi": alui_subi }

### Below code defines the main assembler code (calls instruction specific code)
def main():
    global current_address

    parser = argparse.ArgumentParser(description="Assemble an input file")
    parser.add_argument("input_filename", metavar="input_file", type=str, nargs=1,
                        help="The name of an input file to be assembled")

    input_path = Path(parser.parse_args().input_filename[0])
    if not input_path.is_file():
        print("Assembly failed: File " + str(input_path) + " was not found.")
        sys.exit()

    with open(str(input_path), "rtU") as input_file:
        # First phase (handle all assembler directives, grab all statements)
        for line in input_file:
            labeled_opcode = False
            opcode = ""
            for char in line.strip():
                if char == ';': break # Identified an assembler comment, skip line
                if char == ":": # Identified a label, reset current opcode, record
                    labels[opcode] = current_address
                    labeled_opcode = True
                    opcode = ""
                    continue

                # Skip extra spaces after the label, look for a same-line opcode
                if labeled_opcode and (char == "\t" or char == " "):
                    continue

                # Opcode determination/formation
                if char.isspace(): break
                else: opcode += char
            if opcode in assembler_directives:
                assembler_directives[opcode](line)
                continue
            if opcode.lower() in opcodes_functions:
                program_statements.append([current_address, line.strip()])
                current_address += 1
    input_file.close()

    # Second phase (assemble instructions)
    for statement in program_statements:
        opcode = ""
        if ";" in statement[1]: # Remove any comments (not needed to assemble)
            statement[1] = statement[1].partition(";")[0].strip()

        for char in statement[1]:
            if char == "\t" or char == " ": break
            else: opcode += char
        if opcode.lower() in opcodes_functions:
            opcodes_functions[opcode.lower()](statement)
        else: # throw error, undefined opcode
            print("Assembly failed: opcode " + opcode + " not found")

    print(names)
    print(labels)

    '''def rshift(val, n): return (val % 0x100000000) >> n

    for statement in output_statements:
        print(str(statement[0]), end = " ")
        binary = int(statement[1])
        while binary > 0:
            print("{0:0b}".format(binary & 0xF).zfill(4), end = " ")
            binary = rshift(binary, 4)
        print("\n")
        #print("{0:0b}".format(statement[1]))'''

    # Third phase, write the MIF file
    output_path = ""
    if "." in str(input_file.name):
        output_path = str(input_file.name).rpartition(".")[0] + ".mif"
    else: output_path = str(input_file.name) + ".mif"
    output_file = open(output_path, "wt")
    output_file.write("WIDTH=32;\n")
    output_file.write("DEPTH=16384;\n")
    output_file.write("ADDRESS_RADIX=HEX;\n")
    output_file.write("DATA_RADIX=HEX;\n")
    output_file.write("CONTENT BEGIN\n")

    # Place the first DEAD range, if necessary
    if output_statements[0][0] > 0:
        endAddress = str("{0:02X}".format(output_statements[0][0] - 1)).zfill(8)
        output_file.write("[" + "00000000" + ".." + endAddress + "] : DEAD;\n")

    # Place instructions and DEAD ranges
    for i in range(len(output_statements) - 1):
        ir = output_statements[i]
        pc = output_statements[i + 1]
        output_file.write("-- @ " + "0x" + str("{0:02X}".format(
                ir[0] * 4)).zfill(8) + " :\t\t\t" + ir[2] + "\n")
        output_file.write(str("{0:02X}".format(ir[0])).zfill(8)
                + " : " + str("{0:02X}".format(ir[1])).zfill(8) + ";\n")
        if pc[0] != ir[0] + 1:
            startAddress = str("{0:02X}".format(ir[0] + 1)).zfill(8)
            endAddress = str("{0:02X}".format(pc[0] - 1)).zfill(8)
            output_file.write("[" + startAddress + ".." + endAddress + "] : DEAD;\n")
    last = output_statements[-1] # Make sure we catch the last statement (not in range)
    output_file.write("-- @ " + "0x" + str("{0:02X}".format(
            last[0] * 4)).zfill(8) + " :\t\t\t" + last[2] + "\n")
    output_file.write(str("{0:02X}".format(last[0])).zfill(8)
            + " : " + str("{0:02X}".format(last[1])).zfill(8) + ";\n")

    # Place the last DEAD range, if necessary
    if output_statements[-1][0] < 0x3FFF:
        startAddress = str("{0:02X}".format(output_statements[-1][0] + 1)).zfill(4)
        output_file.write("[" + startAddress + ".." + "3FFF" + "] : DEAD;\n")

    output_file.write("END;\n")
    output_file.close() # Assembly successful

### For the purposes of future modularity
if __name__ == "__main__":
    main()
