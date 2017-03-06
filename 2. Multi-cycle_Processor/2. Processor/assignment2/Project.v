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
  parameter REGNOBITS=4;
  parameter IMMBITS  =16;
  parameter STARTPC  =32'h100;
  parameter ADDRHEX  =32'hFFFFF000;
  parameter ADDRLEDR =32'hFFFFF020;
  parameter ADDRKEY  =32'hFFFFF080;
  parameter ADDRSW   =32'hFFFFF090;
  // Change this to fmedian.mif before submitting
  parameter IMEMINITFILE="test.mif";
  parameter IMEMADDRBITS=16;
  parameter IMEMWORDBITS=2;
  parameter IMEMWORDS=(1<<(IMEMADDRBITS-IMEMWORDBITS));
  parameter DMEMADDRBITS=16;
  parameter DMEMWORDBITS=2;
  parameter DMEMWORDIDXBITS = DMEMADDRBITS-DMEMWORDBITS;
  parameter DMEMWORDS=(1<<(DMEMADDRBITS-DMEMWORDBITS));
  
  parameter OP1BITS  =6;
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
   
  /*************** sxtimm *****************/   
  wire [(DBITS-1)      : 0] sxtimm;
  reg DrOff;


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
  always @(posedge clk)
  begin: REG_WRITE
    if(WrReg&&!reset)
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
  always @(posedge clk) begin
    if(LdA)
      A <= thebus;
    if(LdB)
      B <= thebus;
  end  

  //TODO: Implement ALU functionality
  
  //ALU results
	always @ (*)
	begin: ALU_OPERATION
		case(op1)
			OP1_EXT: begin
			  ALUout = 0;
			end
			default:
				ALUout = 0;
		endcase
	end

  // Connect ALU output to the bus (controlled by DrALU)
  assign thebus=DrALU?ALUout:BUSZ;

  /*************** Data Memory *****************/    
  // TODO: Put the code for data memory and I/O here  
  //Data memory
  reg [(DBITS-1):0] MAR;
  
  //Data signals
  wire [(DBITS-1):0] memin, MemVal;
  wire [(DMEMWORDIDXBITS-1):0] dmemAddr;
  
  //Control singals
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
    S_FETCH1      = S_ZERO,
	 S_FETCH2      = S_FETCH1+S_ONE,
    S_ALUR1       = S_FETCH2+S_ONE,
	 //TODO: Define your processor states here
	 S_ERROR       = S_ALUR1+S_ONE;

 reg [(S_BITS-1):0] state,next_state;
  always @(state or op1 or rs or rt or rd or op2 or ALUout[0]) begin
    {LdPC,DrPC,IncPC,LdMAR,WrMem,DrMem,LdIR,DrOff,ShOff, LdA, LdB,ALUfunc,DrALU,regno,DrReg,WrReg,next_state}=
    {1'b0,1'b0, 1'b0, 1'b0, 1'b0, 1'b0,1'b0, 1'b0, 1'b0,1'b0,1'b0,   6'bX,1'b0,  6'bX, 1'b0, 1'b0,state+S_ONE};
    case(state)
      S_FETCH1: {LdIR,IncPC}={1'b1,1'b1};
      S_FETCH2: begin
	               case(op1)
					   OP1_ALUR: begin
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
					    //...
					    OP1_ADDI,OP1_ANDI,OP1_ORI,OP1_XORI:
						   next_state=S_ALUI1;
					    endcase
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

  
  /*************** HEX/LEDR Output *****************/    
  //TODO: Implement output logic
  //      store to HEXADDR or LEDR addr should display given values to HEX or LEDR

  //TODO: Utilize seven segment display decoders to convert hex to actual seven-segment display control signal
  
endmodule

module SXT(IN,OUT);
  parameter IBITS;
  parameter OBITS;
  input  [(IBITS-1):0] IN;
  output [(OBITS-1):0] OUT;
  assign OUT={{(OBITS-IBITS){IN[IBITS-1]}},IN};
endmodule