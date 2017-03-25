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

  parameter DBITS    =32;
  parameter INSTSIZE =32'd4;
  parameter INSTBITS =32;
  parameter REGNOBITS =4;
  parameter REGWORDS=(1<<REGNOBITS);
  parameter IMMBITS  =14;
  parameter STARTPC  =32'h100;
  parameter ADDRHEX  =32'hFFFFF000;
  parameter ADDRLEDR =32'hFFFFF020;
  parameter ADDRKEY  =32'hFFFFF080;
  parameter ADDRSW   =32'hFFFFF090;
    // Change this to fmedian2.mif before submitting
  parameter IMEMINITFILE="Test.mif";
  
  parameter IMEMADDRBITS=16;
  parameter IMEMWORDBITS=2;
  parameter IMEMWORDS=(1<<(IMEMADDRBITS-IMEMWORDBITS));
  parameter DMEMADDRBITS=16;
  parameter DMEMWORDBITS=2;
  parameter DMEMWORDS=(1<<(DMEMADDRBITS-DMEMWORDBITS));
  
 
  parameter OP1BITS  =6;
  parameter OP1_ALUR =6'b000000;
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
  parameter OP2BITS  = 8;
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
  wire clk,locked;
  // The PLL is wired to produce clk and locked signals for our logic
   Pll myPll(
    .refclk(CLOCK_50),
	 .rst      (!RESET_N),
	 .outclk_0 (clk),
    .locked   (locked)
  );
  
  wire reset=!locked;

  
   
  	/**** FETCH STAGE ****/ 
  
	// The PC register and update logic
	 reg [(DBITS-1):0] PC;
	always @(posedge clk) begin
	if(reset)
		PC<=STARTPC;
	else if(mispred_B)
		PC<=pcgood_B;
	else if(!stall_F)
		PC<=pcpred_F;
	end
	// This is the value of "incremented PC", computed in stage 1
	wire [(DBITS-1):0] pcplus_F=PC+INSTSIZE;
	// This is the predicted value of the PC
	// that we used to fetch the next instruction
	assign pcpred_F=pcplus_F;
	

	// Instruction-fetch
	(* ram_init_file = IMEMINITFILE *)
	
   	reg [(DBITS-1):0] imem[(IMEMWORDS-1):0];
	/*
	initial 
	begin 
		$readmemh("Test_mini.hex", imem);
	end
        */
	assign inst_F=imem[PC[(IMEMADDRBITS-1):IMEMWORDBITS]];
	
	
	/*** DECODE STAGE ***/ 

	// If fetch and decoding stages are the same stage,
	// just connect signals from fetch to decode
	wire [(DBITS-1):0] inst_D=inst_F;
	wire [(DBITS-1):0] pcplus_D=pcplus_F;
	wire [(DBITS-1):0] pcpred_D=pcpred_F;
	// Instruction decoding
	// These have zero delay from inst_D
	// because they are just new names for those signals
	wire [(OP1BITS-1):0]   op1_D;
	wire [(REGNOBITS-1):0] rs_D,rt_D,rd_D;
	
	wire [(OP2BITS-1):0] op2_D;
	wire [(IMMBITS-1):0] rawimm_D;
	
	// Register-read
	reg [(DBITS-1):0] regs[(REGWORDS-1):0];
	// Two read ports, always using rs and rt for register numbers
	wire [(REGNOBITS-1):0] rregno1_D=rs_D, rregno2_D=rt_D;
	wire [(DBITS-1):0] regval1_D=regs[rregno1_D];
	wire [(DBITS-1):0] regval2_D=regs[rregno2_D];



	
	// Control signals 
	always @* begin
		{aluimm_D,      alufunc_D}=
		{    1'bX,{OP2BITS{1'bX}}};
		{isbranch_D,isjump_D,isnop_D,wrmem_D}=
		{      1'b0,    1'b0,   1'b0,   1'b0};
		{selaluout_D,selmemout_D,selpcplus_D,wregno_D,          wrreg_D}=
		{       1'bX,       1'bX,       1'bX,{REGNOBITS{1'bX}},   1'b0};
		
		
		
		if(reset|flush_D)
			isnop_D=1'b1;
		else case(op1_D)
		OP1_ALUR:
			{aluimm_D,alufunc_D,selaluout_D,selmemout_D,selpcplus_D,wregno_D,wrreg_D}=
			{    1'b0,    op2_D,       1'b1,       1'b0,       1'b0,    rd_D,   1'b1};
		// TODO: Write the rest of the decoding code
		default:  ;
		endcase
	end
	
		

	/**** AGEN/EXEC STAGE ****/

	

	reg signed [(DBITS-1):0] aluout_A;
	always @(alufunc_A or aluin1_A or aluin2_A)
	case(alufunc_A)
		OP2_EQ:  aluout_A={31'b0,aluin1_A==aluin2_A};
		OP2_LT:  aluout_A={31'b0,aluin1_A< aluin2_A};
		OP2_LE:  aluout_A={31'b0,aluin1_A<=aluin2_A};
		OP2_NE:  aluout_A={31'b0,aluin1_A!=aluin2_A};
		OP2_ADD: aluout_A=aluin1_A+aluin2_A;
		OP2_AND: aluout_A=aluin1_A&aluin2_A;
		OP2_OR:  aluout_A=aluin1_A|aluin2_A;
		OP2_XOR: aluout_A=aluin1_A^aluin2_A;
		OP2_SUB: aluout_A=aluin1_A-aluin2_A;
		OP2_NAND:aluout_A=~(aluin1_A&aluin2_A);
		OP2_NOR: aluout_A=~(aluin1_A|aluin2_A);
		OP2_NXOR: aluout_A=~(aluin1_A^aluin2_A);
		OP2_RSHF: aluout_A = (aluin_A << aluin_B);
		OP2_LSHF: aluout_A = (aluin_A >>> aluin_B);
		default: aluout_A={DBITS{1'bX}};
	endcase

		
	// TODO: Generate the dobranch, brtarg, isjump, and jmptarg signals somehow...
	wire [(DBITS-1):0] pcgood_A=
		dobranch_A?brtarg_A:
		isjump_A?jmptarg_A:
		pcplus_A;
	wire mispred_A=(pcgood_A!=pcpred_A);
	wire mispred_B=mispred_A&&!isnop_A;
	wire [(DBITS-1):0] pcgood_B=pcgood_A;
	// TODO: This is a good place to generate the flush_? signals


	
	/*** MEM STAGE ****/ 

	// TODO: Write code that produces wmemval_M, wrmem_M, wrreg_M, etc.
	
	reg [(DBITS-1):0] aluout_M,pcplus_M;

	always @(posedge clk)
		{aluout_M,pcplus_M}<=
		{aluout_A,pcplus_A};



       // Create and connect HEX register
	reg [23:0] HexOut;
	SevenSeg ss5(.OUT(HEX5),.IN(HexOut[23:20]));
	SevenSeg ss4(.OUT(HEX4),.IN(HexOut[19:16]));
	SevenSeg ss3(.OUT(HEX3),.IN(HexOut[15:12]));
	SevenSeg ss2(.OUT(HEX2),.IN(HexOut[11:8]));
	SevenSeg ss1(.OUT(HEX1),.IN(HexOut[7:4]));
	SevenSeg ss0(.OUT(HEX0),.IN(HexOut[3:0]));
	always @(posedge clk or posedge reset)
		if(reset)
			HexOut<=24'hFEDEAD;
		else if(wrmem_M&&(memaddr_M==ADDRHEX))
			HexOut <= wmemval_M[23:0];

	// TODO: Write the code for LEDR here

	// Now the real data memory
	wire MemEnable=!(memaddr_M[(DBITS-1):DMEMADDRBITS]);
	wire MemWE=(!reset)&wrmem_M&MemEnable;
	(* ram_init_file = IMEMINITFILE, ramstyle="no_rw_check" *)
	reg [(DBITS-1):0] dmem[(DMEMWORDS-1):0];
	always @(posedge clk)
		if(MemWE)
			dmem[memaddr_M[(DMEMADDRBITS-1):DMEMWORDBITS]]<=wmemval_M;

	wire [(DBITS-1):0] MemVal=MemWE?{DBITS{1'bX}}:dmem[memaddr_M[(DMEMADDRBITS-1):DMEMWORDBITS]];

	// Connect memory and input devices to the bus
// you might need to change the following statement. 
	wire [(DBITS-1):0] memout_M=
		MemEnable?MemVal:
		(memaddr_M==ADDRKEY)?{28'b0,~KEY}:
		(memaddr_M==ADDRSW)? { 20'b0,SW}:
		32'hDEADDEAD;

	// TODO: Decide what gets written into the destination register (wregval_M),
	// when it gets written (wrreg_M) and to which register it gets written (wregno_M)

	/*** Write Back Stage *****/ 

	always @(posedge clk)
		if(wrreg_M&&!reset)
			regs[wregno_M]<=wregval_M;




	
	
	
endmodule




module SXT(IN,OUT);
  parameter IBITS;
  parameter OBITS;
  input  [(IBITS-1):0] IN;
  output [(OBITS-1):0] OUT;
  assign OUT={{(OBITS-IBITS){IN[IBITS-1]}},IN};
endmodule
