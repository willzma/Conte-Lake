module Project(
	input        CLOCK_50,
	input        RESET_N,
	input  [3:0] KEY,
	input  [9:0] SW,
	output [6:0] HEX0,
	output [6:0] HEX1,
	output [6:0] HEX2,
	output [6:0] HEX3,
	output [6:0] HEX4,
	output [6:0] HEX5,
	output [9:0] LEDR
);

  parameter DBITS    =32; // This is a 32-bit architecture. The bus is 32 bits wide.
  parameter INSTSIZE =32'd4; // Size of an instruction in bytes (used for incrementing PC).
  parameter INSTBITS =32; // Size of an instruction in bits.
  parameter REGNOBITS=4; // Number of bits needed to address all registers.
  parameter IMMBITS  =16; // Number of bits in our immediate.
  parameter STARTPC  =32'h100; // The initial address of our PC in instruction memory.
  parameter ADDRHEX  =32'hFFFFF000; // Memory mapped I/O.
  parameter ADDRLEDR =32'hFFFFF020; // Memory mapped I/O.
  parameter ADDRKEY  =32'hFFFFF080; // Memory mapped I/O.
  parameter ADDRSW   =32'hFFFFF090; // Memory mapped I/O.
  
  // Change this to fmedian.mif before submitting
  parameter IMEMINITFILE="Test.mif";
  
  parameter IMEMADDRBITS=16; // Addressability of i-memory is 2^16
  parameter IMEMWORDBITS=2; // There are 2^2 bytes per word
  parameter IMEMWORDS=(1<<(IMEMADDRBITS-IMEMWORDBITS)); // We can map to this many words
  parameter DMEMADDRBITS=16; // Addressability of d-memory is 2^16
  parameter DMEMWORDBITS=2; // There are 2^2 bytes per word
  parameter DMEMWORDIDXBITS = DMEMADDRBITS-DMEMWORDBITS; // lg(number of words in memory)
  parameter DMEMWORDS=(1<<(DMEMADDRBITS-DMEMWORDBITS)); // number of words in memory
  
  parameter OP1BITS  =6; // # bits in primary opcode
  parameter OP1_EXT  =6'b000000;
  parameter OP1_BEQ  =6'b001000;
  parameter OP1_BLT  =6'b001001;
  parameter OP1_BLE  =6'b001010;
  parameter OP1_BNE  =6'b001011;
  parameter OP1_JAL  =6'b001100;
  parameter OP1_LW   =6'b010010;
  parameter OP1_SW   =6'b011010;
  parameter OP1_ADDI =6'b100000;
  parameter OP1_ANDI =6'b100100;
  parameter OP1_ORI  =6'b100101;
  parameter OP1_XORI =6'b100110;

  
  // Add parameters for secondary opcode values
    
  /* OP2 */
  parameter OP2BITS  = 8; // # bits in the secondary opcode
  parameter OP2_EQ   = 8'b00001000;
  parameter OP2_LT   = 8'b00001001;
  parameter OP2_LE   = 8'b00001010;
  parameter OP2_NE   = 8'b00001011;

  parameter OP2_ADD  = 8'b00100000;
  parameter OP2_AND  = 8'b00100100;
  parameter OP2_OR   = 8'b00100101;
  parameter OP2_XOR  = 8'b00100110;
  parameter OP2_SUB  = 8'b00101000;
  parameter OP2_NAND = 8'b00101100;
  parameter OP2_NOR  = 8'b00101101;
  parameter OP2_NXOR = 8'b00101110;
  parameter OP2_RSHF = 8'b00110000;
  parameter OP2_LSHF = 8'b00110001;
  
  parameter HEXBITS  = 24;
  parameter LEDRBITS = 10;
  
  // The reset signal comes from the reset button on the DE0-CV board
  // RESET_N is active-low, so we flip its value ("reset" is active-high)
  wire locked,clk2;
  // The PLL is wired to produce clk and locked signals for our logic
  Pll myPll(
    .refclk(CLOCK_50),
	 .rst      (!RESET_N),
	 .outclk_0 (clk2),
    .locked   (locked)
  );
  
  wire reset=!locked;
  
  reg [31:0] buffer = 32'd0;
  reg [31:0] cap = 32'd500000;
  reg clk; 
  
  always@(posedge clk2 or posedge reset) begin
	if (reset) begin
		buffer <= 0;
		clk <= 0;
	end
	else if (buffer < cap)
		buffer <= buffer + 1;
	else begin
		buffer <= 0;
		clk <= ~clk;
		end
  end
 
  /*************** BUS *****************/
  // Create the processor's bus
  tri [(DBITS-1):0] thebus;
  parameter BUSZ={DBITS{1'bZ}};  

  /*************** PC *****************/
  // Create PC and connect it to the bus
  reg [(DBITS-1):0] PC;
  reg LdPC, DrPC, IncPC;
     
  //Data path
  always @(posedge clk or posedge reset) begin
    if(reset)
	   PC<=STARTPC;
	 else if(LdPC)
      PC<=thebus;
    else if(IncPC)
      PC<=PC+INSTSIZE;
    else
	   PC<=PC;
  end
  assign thebus=DrPC?PC:BUSZ;

  /*************** Fetch - Instruction memory *****************/  
  (* ram_init_file = IMEMINITFILE *)
  reg [(DBITS-1):0] imem[(IMEMWORDS-1):0];
  wire [(DBITS-1):0] iMemOut;
  
  assign iMemOut=imem[PC[(IMEMADDRBITS-1):IMEMWORDBITS]];
  
  /*************** Fetch - Instruction Register *****************/    
  // Create the IR (feeds directly from memory, not from bus)
  reg [(INSTBITS-1):0] IR;
  reg LdIR;
  
  //Data path
  always @(posedge clk or posedge reset)
  begin
    if(reset)
	   IR<=32'hDEADDEAD;
	 else if(LdIR)
      IR <= iMemOut;
  end
  
  
  /*************** Decode *****************/ 
  // Put the code for getting op1, rd, rs, rt, imm, etc. here 
  wire [(OP1BITS-1)    : 0] op1;
  wire [(OP2BITS-1)    : 0] op2;
  wire [(REGNOBITS-1)  : 0] rs;
  wire [(REGNOBITS-1)  : 0] rd;
  wire [(REGNOBITS-1)  : 0] rt;
  wire [(IMMBITS-1)    : 0] imm;

  //TODO: Implement instruction decomposition logic
  assign op1 = IR[31:26];
  assign op2 = IR[25:18];
  assign rs = IR[7:4];
  assign rd = IR[11:8];
  assign rt = IR[3:0];
  assign imm = IR[23:8];
   
  /*************** sxtimm *****************/   
  wire [(DBITS-1)      : 0] sxtimm;
  reg DrOff;
  reg ShOff;
  assign thebus = ShOff? (sxtimm << 2):BUSZ;
  assign thebus = DrOff? sxtimm:BUSZ;  

  /*************** Register file *****************/ 		
  // Create the registers and connect them to the bus
  reg [(DBITS-1):0] regs[15:0];

  //Control signals
  reg WrReg,DrReg;
  
  //Data signals
  reg  [(REGNOBITS-1):0] regno;
  wire [(DBITS-1)    :0] regOut;
     
  integer r;
  integer i;
  always @(posedge clk or posedge reset)
  begin: REG_WRITE
	if(reset) begin
		 for (i=0; i<16; i=i+1) regs[i] <= 0;
	end
    else if(WrReg&&!reset)
      regs[regno]<=thebus;
  end  
  
  assign regOut= WrReg?{DBITS{1'bX}}:regs[regno];
  assign thebus= DrReg?regOut:BUSZ;

  /***********************************************/ 

  /******************** ALU **********************/
  // Create ALU unit and connect to the bus
  //Data signals
  reg signed [(DBITS-1):0] A,B;
  reg signed [(DBITS-1):0] ALUout;
  //Control signals
  reg LdA,LdB,DrALU;
 
  //Data path
  // Receive data from bus
  always @(posedge clk or posedge reset) begin
  if (reset) begin
		A <= 0;
		B <= 0;
  end
  else begin
    if(LdA)
      A <= thebus;
    if(LdB)
      B <= thebus;
  end 
  
 end

  //TODO: Implement ALU functionality
  
  reg altFunc;
  
  //ALU results
	always @ (*)
	begin: ALU_OPERATION
	
		case(op1)
			OP1_EXT: begin
					case(op2)
						OP2_EQ: begin
						  ALUout = (A == B);
						end
						OP2_LT: begin
						  ALUout = (A < B);
						end
						OP2_LE: begin
						  ALUout = (A <= B);
						end
						OP2_NE: begin
						  ALUout = (A != B);
						end
						OP2_ADD: begin
						  ALUout = (A + B);
						end
						OP2_AND: begin
						  ALUout = (A & B);
						end	
						OP2_OR: begin
						  ALUout = (A | B);
						end
						OP2_XOR: begin
						  ALUout = (A ^ B);
						end
						OP2_SUB: begin
						  ALUout = (A - B);
						end
						OP2_NAND: begin
						  ALUout = (~(A & B));
						end
						OP2_NOR: begin
						  ALUout = (~(A | B));
						end
						OP2_NXOR: begin
						  ALUout = (~(A ^ B));
						end
						OP2_RSHF: begin
						  ALUout = (A << B);
						end
						OP2_LSHF: begin
						  ALUout = (A >>> B);
						end
						default:
							ALUout = 0;
					endcase
			end
			OP1_BEQ: begin
			  if (!altFunc)
			    ALUout = (A == B);
			  else
			    ALUout = (A + B);
			end	
			OP1_BLT: begin
			  if (!altFunc)
			    ALUout = (A < B);
			  else
			    ALUout = (A + B);
			end
			OP1_BLE: begin
			  if (!altFunc)
			    ALUout = (A <= B);
			  else
			    ALUout = (A + B);
			end
			OP1_BNE: begin
			  if (!altFunc)
			    ALUout = (A != B);
			  else
			    ALUout = (A + B);
			end
			OP1_LW, OP1_SW, OP1_JAL, OP1_ADDI: begin
			  ALUout = (A + B);
			end
			OP1_ANDI: begin
			  ALUout = (A & B);
			end
			OP1_ORI: begin
			  ALUout = (A | B);
			end
			OP1_XORI: begin
			  ALUout = (A ^ B);
			end
			default:
				ALUout = 0;
		endcase
		
	end

  // Connect ALU output to the bus (controlled by DrALU)
  assign thebus=DrALU?ALUout:BUSZ;

  /*************** Data Memory *****************/    
  // TODO: Put the code for data memory and I/O here
  
  // I/O
  reg [23:0] HEXout, KEYout, SWout;
  reg [9:0] LEDRout;
  assign LEDR = LEDRout[9:0];
  
  (* ram_init_file = IMEMINITFILE *)
  reg [(DBITS-1):0] dmem[(DMEMWORDS-1):0];
  
  //Data memory
  reg [(DBITS-1):0] MAR;
  
  //Data signals
  wire [(DBITS-1):0] memin, MemVal;
  wire [(DMEMWORDIDXBITS-1):0] dmemAddr;
  
  //Control signals
  reg DrMem, WrMem, LdMAR; 
  wire MemEnable, MemWE;

  assign MemEnable = !(MAR[(DBITS-1):DMEMADDRBITS]);
  assign MemWE     = WrMem & MemEnable & !reset;

  always @(posedge clk or posedge reset)
  begin: LOAD_MAR
    if(reset) begin
      MAR<=32'b0;
    end
    else if(LdMAR) begin
      MAR<=thebus;
    end
  end
  
  
  //Data path
  assign dmemAddr = MAR[(DMEMADDRBITS-1):DMEMWORDBITS];
  assign MemVal  = MemWE? {DBITS{1'bX}} : dmem[dmemAddr];
  assign memin   = thebus;   //Snoop the bus
  
  always @(posedge clk)
  begin: DMEM_STORE
    if(MemWE) begin
      dmem[dmemAddr] <= memin;
    end
  end
  assign thebus=DrMem? MemVal:BUSZ;
      
  /******************** Processor state **********************/
  parameter S_BITS=5;
  parameter [(S_BITS-1):0]
    S_ZERO        = {(S_BITS){1'b0}},
    S_ONE         = {{(S_BITS-1){1'b0}},1'b1},
    S_FETCH1      = S_ZERO * 0,
	 S_FETCH2      = S_ONE * 1,
    S_ALUR1       = S_ONE * 2,
    S_ALUR2       = S_ONE * 3,
    S_ALUR3       = S_ONE * 4,
    S_ALUI1       = S_ONE * 5,
    S_ALUI2       = S_ONE * 6,
    S_ALUI3       = S_ONE * 7,
	 S_JAL1       = S_ONE * 8,
    S_JAL2       = S_ONE * 9,
    S_JAL3       = S_ONE * 10,
    S_JAL4       = S_ONE * 11,
    S_B1       = S_ONE * 12,
    S_B2       = S_ONE * 13,
    S_B3       = S_ONE * 14,
    S_B4       = S_ONE * 15,
    S_B5       = S_ONE * 16,
    S_B6       = S_ONE * 17,
    S_S1       = S_ONE * 18,
    S_S2       = S_ONE * 19,
    S_S3       = S_ONE * 20,
    S_S4       = S_ONE * 21,
	 S_L1       = S_ONE * 22,
    S_L2       = S_ONE * 23,
    S_L3       = S_ONE * 24,
    S_L4       = S_ONE * 25,
	 
	 //TODO: Define your processor states here
	 S_ERROR       = S_ONE * 26;

 reg [(S_BITS-1):0] state,next_state;
  always @(state or op1 or rs or rt or rd or op2 or ALUout[0]) begin
	 LdPC = 1'b0;
	 DrPC = 1'b0;
	 IncPC =  1'b0;
	 LdMAR =  1'b0;
	 WrMem =  1'b0;
	 DrMem =  1'b0;
	 LdIR =  1'b0;
	 DrOff =  1'b0;
	 ShOff =  1'b0;
	 LdA =  1'b0;
	 LdB = 1'b0;
	 DrALU =  1'b0;
	 regno = 6'bX;
	 DrReg =  1'b0;
	 WrReg =  1'b0;
	 altFunc =  1'b0;
	 next_state = state+S_ONE;
    case(state)
      S_FETCH1: begin {LdIR,IncPC}={1'b1,1'b1}; 
					end
      S_FETCH2: begin
	               case(op1)
					   OP1_EXT: begin
					     case(op2)
					       OP2_SUB,
				  		    OP2_NAND,OP2_NOR,OP2_NXOR,
						    OP2_EQ,OP2_LT,OP2_LE,OP2_NE,
						    OP2_ADD,
						    OP2_AND,OP2_OR,OP2_XOR:
						         next_state=S_ALUR1;
						    default: next_state=S_ERROR;
						  endcase
				       end
				 
					    OP1_ADDI,OP1_ANDI,OP1_ORI,OP1_XORI:
						   next_state=S_ALUI1;
							
						 OP1_JAL: begin
							next_state = S_JAL1;
						 end
						 
						 OP1_BEQ, OP1_BLT, OP1_BLE, OP1_BNE: begin
							next_state = S_B1;
						 end
						 
						 OP1_SW: begin
							next_state = S_S1;
						 end
						 
						 OP1_LW: begin
							next_state = S_L1;
						 end
							
					    endcase
					  end
		S_ALUR1: begin 
					{LdA, DrReg, regno}={1'b1, 1'b1, rs};
					end
		S_ALUR2: begin
					{LdB, DrReg, regno}={1'b1, 1'b1, rt};
					end
		S_ALUR3: begin
					{DrALU, WrReg, regno}={1'b1, 1'b1, rd};
					next_state=S_FETCH1;
					end
		
		S_ALUI1: begin 
					{LdA, DrReg, regno}={1'b1, 1'b1, rs};
					end
		S_ALUI2: begin 
					{LdB, DrOff}={1'b1, 1'b1};
					end
		S_ALUI3: begin
					{DrALU, WrReg, regno}={1'b1, 1'b1, rt};
					next_state=S_FETCH1;
					end
					
		S_JAL1: begin
				{regno, WrReg, DrPC} = {rt, 1'b1, 1'b1};
				next_state = S_JAL2;
			end
		S_JAL2: begin
				{LdA, DrReg, regno} = {1'b1, 1'b1, rs};
				next_state = S_JAL3;
			end
		S_JAL3: begin
				{LdB, ShOff, DrOff} = {1'b1, 1'b1, 1'b1};
				next_state = S_JAL4;
			end
		S_JAL4: begin
				{DrALU, LdPC} = {1'b1, 1'b1};
				next_state = S_FETCH1;
			end
			
		S_B1: begin
				{LdA, DrReg, regno} = {1'b1, 1'b1, rs};
				next_state = S_B2;
			end
		S_B2: begin
				{LdB, DrReg, regno} = {1'b1, 1'b1, rt};
				next_state = S_B3;
			end
		S_B3: begin
				{DrALU} = {1'b1};
				if (!ALUout)
					next_state = S_FETCH1;
				else
					next_state = S_B4;
			end
		S_B4: begin
				{LdA, DrPC} = {1'b1, 1'b1};
				next_state = S_B5;
			end
		S_B5: begin
				{LdB, ShOff, DrOff} = {1'b1, 1'b1, 1'b1};
				next_state = S_B6;
			end
		S_B6: begin
				{LdPC, DrALU, altFunc} = {1'b1, 1'b1, 1'b1};
				next_state = S_FETCH1;
			end
			
		S_S1: begin
				{LdA, DrReg, regno} = {1'b1, 1'b1, rs}; 
				next_state = S_S2;
			end
		S_S2: begin
				{LdB, DrOff} = {1'b1, 1'b1}; 
				next_state = S_S3;
			end
		S_S3: begin
				{DrALU, LdMAR} = {1'b1, 1'b1};
				next_state = S_S4;
			end
		S_S4: begin
				{regno, WrMem, DrReg} = {rt, 1'b1, 1'b1};
				next_state = S_FETCH1;
			end
		
		S_L1: begin
				{LdA, DrReg, regno} = {1'b1, 1'b1, rs}; 
				next_state = S_L2;
			end
		S_L2: begin
				{LdB, DrOff} = {1'b1, 1'b1};
				next_state = S_L3;
			end
		S_L3: begin
				{DrALU, LdMAR} = {1'b1, 1'b1};
				next_state = S_L4;
			end
		S_L4: begin
				{DrMem, regno, WrReg} = {1'b1, rt, 1'b1};
				next_state = S_FETCH1;
			end
			
	  // Put the code for the rest of the "dispatch" here	
	  // Put the rest of the "microcode" here
	  
      default:  next_state=S_ERROR;
    endcase
  end

  //TODO: Implement your processor state transition machine	 
  always @(posedge clk or posedge reset)
    if(reset) state<=S_FETCH1;
    else state<=next_state;
  
	  
  /*************** sign-extend (SXT) *****************/       
  //TODO: Instantiate SXT module
	SXT #(IMMBITS, DBITS) sxt(imm, sxtimm);
  
  /*************** HEX/LEDR Output *****************/    
  //TODO: Implement output logic
  //      store to HEXADDR or LEDR addr should display given values to HEX or LEDR
  always @(posedge clk or posedge reset)
  begin
    if(reset) begin
	   HEXout <= {24{1'b0}};
		LEDRout <= {{10{1'b0}}};
		end
	//else begin
		//HEXout <= regs[8];
		//LEDRout <= state;
		//end
	
	 else if(!MemEnable) // Interrupt
		if(sxtimm == ADDRHEX)
			HEXout <= regs[rt];
		else if(sxtimm == ADDRLEDR)
			LEDRout <= regs[rt];
  end
 
  //TODO: Utilize seven segment display decoders to convert hex to actual seven-segment display control signal
	SevenSeg Hex0Out(.IN(HEXout[3:0]), .OUT(HEX0));
	SevenSeg Hex1Out(.IN(HEXout[7:4]), .OUT(HEX1));
	SevenSeg Hex2Out(.IN(HEXout[11:8]), .OUT(HEX2));
	SevenSeg Hex3Out(.IN(HEXout[15:12]), .OUT(HEX3));
	SevenSeg Hex4Out(.IN(HEXout[19:16]), .OUT(HEX4));
	SevenSeg Hex5Out(.IN(HEXout[23:20]), .OUT(HEX5));
  
endmodule

module SXT(IN,OUT);
  parameter IBITS;
  parameter OBITS;
  input  [(IBITS-1):0] IN;
  output [(OBITS-1):0] OUT;
  assign OUT={{(OBITS-IBITS){IN[IBITS-1]}},IN};
endmodule