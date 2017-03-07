from pathlib import Path

import argparse
import sys

# Assembler global variables/resources (used in every section of code)
current_address = 0 # Keep track of current address; relative to .ORIG
names = {} # Define an empty dictionary to build .NAME's
labels = {} # Define an empty dictionary to build labels
output_lines = [] # Define an empty list to build the output MIF
registers = { # Register mapping names to register numbers
    "r0": 0,
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

### Below code defines instruction specific code (like an abstract syntax tree)
def orig(statement, index): current_address = int(statement[index:].strip(), 16)

def name(statement, index):
    tuple = statement[index:].strip().split("=")
    names[tuple[0].strip()] = int(tuple[1].strip(), 16)

def branch(statement, index):
    print(statement)

opcodes = { # Map opcodes to their respective assembler functions
    ".orig": orig,
    ".name": name,
    "beq": branch, "blt": branch, "ble": branch, "bne": branch }

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
        for line in input_file:
            current_index = 0
            labeled_opcode = False
            opcode = ""
            for char in line.strip():
                if char == ';': break # Identified an assembler comment, skip line
                if char == ":": # Identified a label, reset current opcode
                    labels[opcode] = current_address
                    labeled_opcode = True
                    opcode = ""
                    current_index += 1
                    continue

                # Skip extra spaces after the label, look for a same-line opcode
                if labeled_opcode and (char == "\t" or char == " "):
                    current_index += 1
                    continue

                # Opcode determination/formation
                if char.isspace():
                    break
                else:
                    current_index += 1
                    opcode += char
            current_address += 1
            print(opcodes[opcode](line, current_index + 1))

### For the purposes of future modularity
if __name__ == "__main__":
    main()
