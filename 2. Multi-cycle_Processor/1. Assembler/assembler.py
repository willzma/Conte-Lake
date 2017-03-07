from pathlib import Path

import argparse
import sys

# Assembler global variables/resources (used in every section of code)
current_address = 0 # Keep track of current address; relative to .ORIG
names = {} # Define an empty dictionary to build .NAME's
labels = {} # Define an empty dictionary to build labels
program_statements = [] # Define an empty list to build actual program statements
output_statements = [] # Define an empty list to build the output MIF
registers = { # Register mapping names to register numbers
    "Zero": 0, "r0": 0,
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
    "jal": 0b001100,
    "lw": 0b010010, "sw": 0b011010,
    "addi": 0b100000, "andi": 0b100100, "ori": 0b100101, "xori": 0b100110 }

ext_opcodes = { # Map EXT opcodes to their binary counterparts
    "eq": 0b00000000001000, "lt": 0b00000000001001, "le": 0b00000000001010,
    "ne": 0b00000000001011, "add": 0b00000000100000, "and": 0b00000000100100,
    "or": 0b00000000100101, "xor": 0b00000000100110, "sub": 0b00000000101000,
    "nand": 0b00000000101100, "nor": 0b00000000101101, "nxor": 0b00000000101110,
    "rshf": 0b00000000110000, "lshf": 0b00000000110001 }

### Below code defines instruction specific code (like an abstract syntax tree)
def get_opcode(statement): # Only use this for pre-stripped, filtered statements
    opcode = ""
    for char in statement:
        if char == "\t" or char == " ": break
        else: opcode += char
    return opcode

def orig(statement):
    global current_address
    current_address = int(statement.partition(".ORIG")[2].strip(), 16)

def name(statement):
    tuple = statement.partition(".NAME")[2].strip().split("=")
    names[tuple[0].strip()] = int(tuple[1].strip(), 16)

def branch(statement):
    opcode = get_opcode(statement)
    params = statement.partition(opcode)[2].split(",")
    rs = registers[params[0].strip().lower()]
    rt = registers[params[1].strip().lower()]
    imm = params[2].strip()
    if imm in labels: imm = int(labels[imm]) - current_address
    elif imm in names: imm = int(names[imm]) - current_address
    else: imm = int(imm)

    output = opcodes[opcode] << 24
    output += imm
    output <<= 5
    output += rs
    output <<= 3
    output += rt
    print(imm)
    print(output)


### Below code defines pseudo-instructions (instructions that don't fit defaults)
def branch_br(statement, index):
    print(labels[statement[index:].strip()])

# Case statements for assembler directives and opcode functions
assembler_directives = { # Map assembler directives to associated functions
    ".ORIG": orig, ".NAME": name }

opcodes_functions = { # Map opcodes to their respective assembler functions
    "beq": branch, "blt": branch, "ble": branch, "bne": branch,
    "br": branch_br }

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
        # First pass (handle all assembler directives, grab all statements)
        for line in input_file:
            labeled_opcode = False
            opcode = ""
            for char in line.strip():
                if char == ';': break # Identified an assembler comment, skip line
                if char == ":": # Identified a label, reset current opcode, record
                    labels[opcode] = current_address + 1
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
            if opcode in opcodes or opcode in ext_opcodes:
                program_statements.append(line.strip())
                current_address += 1

        print(names)
        print(labels)

        branch("beq	s1,s2,FirstInstWorks")

        # Second pass (assemble instructions)
        for statement in program_statements:
            opcode = ""
            if ";" in statement: # Remove any comments
                statement = statement.partition(";")[0].strip()

            print(statement)

            for char in statement:
                if char == "\t" or char == " ": break
                else: opcode += char
            if opcode in opcodes_functions:
                opcodes_functions[opcode](statement)
            #else: # throw error, undefined opcode
                #print("implement this")

        # Prepare the MIF file

### For the purposes of future modularity
if __name__ == "__main__":
    main()
