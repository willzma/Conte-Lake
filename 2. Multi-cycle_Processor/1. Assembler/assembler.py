from pathlib import Path

import argparse
import sys

current_address = 0x0 # Keep track of current address; relative to .ORIG
names = {} # Define an empty dictionary to build .NAME's

def main():
    parser = argparse.ArgumentParser(description="Assemble an input file")
    parser.add_argument("input_filename", metavar="input_file", type=str, nargs=1,
                        help="The name of an input file to be assembled")

    input_file = Path(parser.parse_args().input_filename[0])
    if not input_file.is_file():
        print("Assembly failed: File " + str(input_file) + " was not found.")
        sys.exit()

if __name__ == "__main__":
    main()
