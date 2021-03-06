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

	parameter DBITS = 32;
	parameter INSTSIZE = 32'd4;
	parameter INSTBITS = 32;
	parameter REGNOBITS = 4;
	parameter REGWORDS = (1 << REGNOBITS);
	parameter IMMBITS = 16;
	parameter STARTPC = 32'h100;
	parameter ADDRHEX = 32'hFFFFF000;
	parameter ADDRLEDR = 32'hFFFFF020;
	parameter ADDRKDATA = 32'hFFFFF080;
	parameter ADDRKCTRL = 32'hFFFFF084;
	parameter ADDRSDATA = 32'hFFFFF090;
	parameter ADDRSCTRL = 32'hFFFFF094;
	parameter ADDRTCNT = 32'hFFFFF100;
	parameter ADDRTLIM = 32'hFFFFF104;
	parameter ADDRTCTRL = 32'hFFFFF108;

	// Change this to fmedian2.mif before submitting
	parameter IMEMINITFILE = "fmedian2.mif";

	parameter IMEMADDRBITS = 16;
	parameter IMEMWORDBITS = 2;
	parameter IMEMWORDS = (1 << (IMEMADDRBITS - IMEMWORDBITS));
	parameter DMEMADDRBITS = 16;
	parameter DMEMWORDBITS = 2;
	parameter DMEMWORDS = (1 << (DMEMADDRBITS - DMEMWORDBITS));

	/* OP1 */
	parameter OP1BITS = 6;
	parameter OP1_EXT = 6'b000000;
	parameter OP1_BEQ = 6'b001000;
	parameter OP1_BLT = 6'b001001;
	parameter OP1_BLE = 6'b001010;
	parameter OP1_BNE = 6'b001011;
	parameter OP1_JAL = 6'b001100;
	parameter OP1_LW = 6'b010010;
	parameter OP1_SW = 6'b011010;
	parameter OP1_ADDI = 6'b100000;
	parameter OP1_ANDI = 6'b100100;
	parameter OP1_ORI  = 6'b100101;
	parameter OP1_XORI = 6'b100110;

	// Add parameters for secondary opcode values

	/* OP2 */
	parameter JAL_FUNC = 8'b00001100;

	parameter OP2BITS = 8;
	parameter OP2_EQ = 8'b00001000;
	parameter OP2_LT = 8'b00001001;
	parameter OP2_LE = 8'b00001010;
	parameter OP2_NE = 8'b00001011;

	parameter OP2_ADD = 8'b00100000;
	parameter OP2_AND = 8'b00100100;
	parameter OP2_OR = 8'b00100101;
	parameter OP2_XOR = 8'b00100110;
	parameter OP2_SUB = 8'b00101000;
	parameter OP2_NAND = 8'b00101100;
	parameter OP2_NOR = 8'b00101101;
	parameter OP2_NXOR = 8'b00101110;
	parameter OP2_RSHF = 8'b00110000;
	parameter OP2_LSHF = 8'b00110001;

	parameter HEXBITS = 24;
	parameter LEDRBITS = 10;

	wire clk, locked;
	Plloc myPll(
		.refclk(CLOCK_50),
		.rst      (!RESET_N),
		.outclk_0 (clk),
		.locked   (locked)
	);

	wire reset = !locked;

	/**** DATA FORWARDING CONTROLLER ****/
	wire rs_match_A = (~isnop_A) & (rs_D != 4'b0) & (rs_D === destreg_A);
	wire rs_match_M = (~isnop_M) & (rs_D != 4'b0) & (rs_D === destreg_M);
	wire rt_match_A = (~isnop_A) & (rt_D != 4'b0) & (rt_D === destreg_A);
	wire rt_match_M = (~isnop_M) & (rt_D != 4'b0) & (rt_D === destreg_M);
	wire [(DBITS - 1):0] agex_fwd = aluout_A;
	wire [(DBITS - 1):0] mem_fwd = wregval_M;
	wire stall = ldmem_A & (rs_match_A || rt_match_A);

	/**** BRANCH RESOLUTION ****/
	wire dobranch = aluout_A[0:0] & ~isnop_A & isbranch_A;
	wire dojump = ~isnop_A & isjump_A;
	wire [(DBITS - 1):0] destination = dobranch ? (pcpred_A + (sxtimm_A << 2)) : dojump ? (aluin1_A + (sxtimm_A << 2)) : pcpred_A;
	wire mispred = dobranch | dojump;



	/**** FETCH STAGE ****/
	// The PC register and update logic
	reg [(DBITS - 1):0] PC;
	always @(posedge clk or posedge reset) begin
		if (reset) begin
			PC <= STARTPC; // Initial step
		end else if (mispred) begin
			PC <= destination;
		end else if (!stall) begin
			PC <= pcpred_F; // Proceed 1 step
		end
	// If you failed all conditions, you are stalled. Stay on this step.
	end

	// This is the value of "incremented PC", computed in stage 1
	wire [(DBITS - 1):0] pcplus_F = PC + INSTSIZE;
	wire [(DBITS - 1):0] pcpred_F;

	// This is the predicted value of the PC
	// that we used to fetch the next instruction
	assign pcpred_F = pcplus_F;

	// Instruction-fetch
	(* ram_init_file = IMEMINITFILE *)
	reg [(DBITS - 1):0] imem[(IMEMWORDS - 1):0];
	wire [(DBITS - 1):0] inst_F;
	assign inst_F = imem[PC[(IMEMADDRBITS - 1):IMEMWORDBITS]];



	/*** DECODE STAGE ***/
	// If fetch and decoding stages are the same stage,
	// just connect signals from fetch to decode
	// AHA - we don't want these in the same stage. Always block added.
	reg [(DBITS - 1):0] inst_D;
	reg [(DBITS - 1):0] pcpred_D;
	reg isnop_D;

	// Instruction decoding
	// These have zero delay from inst_D
	// because they are just new names for those signals
	wire [(OP1BITS - 1):0] op1_D;
	wire [(REGNOBITS - 1):0] rs_D, rt_D, rd_D;
	wire [(OP2BITS - 1):0] op2_D;
	wire [(IMMBITS - 1):0] rawimm_D;
	// I added this VVVV
	wire [(DBITS - 1): 0] sxtimm_D;

	// Here I am manually hooking up these wires
	assign op1_D = inst_D[31:26];
	assign op2_D = inst_D[25:18];
	assign rs_D = inst_D[7:4];
	assign rd_D = inst_D[11:8];
	assign rt_D = inst_D[3:0];
	assign rawimm_D = inst_D[23:8];

	// Instantiate SXT module
	SXT #(IMMBITS, DBITS) sxt(rawimm_D, sxtimm_D);

	// Register-read
	reg [(DBITS - 1):0] regs[(REGWORDS - 1):0];
	// Two read ports, always using rs and rt for register numbers
	wire [(REGNOBITS - 1):0] rregno1_D = rs_D, rregno2_D = rt_D;
	wire [(DBITS - 1):0] RSval_D = rs_match_A ? agex_fwd : rs_match_M ? mem_fwd : regs[rregno1_D]; // Holds RS value
	wire [(DBITS - 1):0] RTval_D = rt_match_A ? agex_fwd : rt_match_M ? mem_fwd : regs[rregno2_D]; // Holds RT value

	reg aluimm_D; // If enabled, aluin2 is the sxtimm_D. Otherwise its regval2.
	reg [(OP2BITS - 1):0] alufunc_D; // ALU func
	reg isbranch_D;
	reg isjump_D;
	reg [(REGNOBITS - 1):0] destreg_D; // The destination register in this context
	reg wrmem_D; // Write RT to mem at aluout address?
	reg ldmem_D; // Set reg write value to value at aluout address?
	reg wrreg_D; // Write to destreg_D?
	reg flush_D; // Unimplemented

	// Control signals
	always @(*) begin
		isnop_D = 1'b0;
		aluimm_D = 1'b0;
		alufunc_D = {OP2BITS{1'bX}};
		isbranch_D = 1'b0;
		isjump_D = 1'b0;
		destreg_D = {REGNOBITS{1'b0}};
		wrreg_D = 1'b0;
		wrmem_D = 1'b0;
		ldmem_D = 1'b0;
		inst_D = inst_F;
		pcpred_D = pcpred_F;

		if (reset || mispred) begin
			isnop_D = 1'b1;
		end else if (!stall) begin
			case (op1_D)
				// All OP2
				OP1_EXT: begin
					case (op2_D)
						OP2_SUB, OP2_NAND, OP2_NOR, OP2_NXOR, OP2_EQ, OP2_LT, OP2_LE, OP2_NE,
						OP2_ADD, OP2_AND, OP2_OR, OP2_XOR, OP2_RSHF, OP2_LSHF: begin
							alufunc_D = op2_D;
							destreg_D = rd_D;
							wrreg_D = 1'b1;
						end
						default: ;
					endcase
				end
				// Immediate arithmetic. Notice how alufunc is handled - concat 2 0's
				OP1_ADDI, OP1_ANDI, OP1_ORI, OP1_XORI: begin
					aluimm_D = 1'b1;
					alufunc_D = {2'b0, op1_D};
					destreg_D = rt_D;
					wrreg_D = 1'b1;
				end
				// Branches
				OP1_BEQ, OP1_BLE, OP1_BLT, OP1_BNE: begin
					alufunc_D = {2'b0, op1_D};
					isbranch_D = 1'b1;
				end
				// JAL
				OP1_JAL: begin
					alufunc_D = JAL_FUNC;
					isjump_D = 1'b1;
					destreg_D = rt_D;
					wrreg_D = 1'b1;
				end
				// Store word: Use imm, add to RS, use this as address. Store RT here.
				OP1_SW: begin
					aluimm_D = 1'b1;
					alufunc_D = OP2_ADD;
					wrmem_D = 1'b1;
				end
				// Load word
				OP1_LW: begin
					aluimm_D = 1'b1;
					alufunc_D = OP2_ADD;
					ldmem_D = 1'b1;
					destreg_D = rt_D;
					wrreg_D = 1'b1;
				end
				default: ;
			endcase
		end
	end



	/**** AGEN/EXEC STAGE ****/
	reg signed [(DBITS - 1):0] aluin1_A;
	reg signed [(DBITS - 1):0] aluin2_A;
	reg signed [(DBITS - 1):0] sxtimm_A;
	reg [(DBITS - 1):0] pcpred_A;
	reg [(OP2BITS - 1):0] alufunc_A;
	reg wrreg_A;
	reg wrmem_A;
	reg ldmem_A;
	reg isnop_A;
	reg [(REGNOBITS - 1):0] destreg_A;
	reg [(DBITS - 1):0] RTreg_A;
	reg isbranch_A;
	reg isjump_A;

	// AHA - we don't want these in the same stage. Always block added.
	always @(posedge clk or posedge reset) begin
		if (reset) begin
			isnop_A <= 1'b1;
		end else begin
			aluin1_A <= RSval_D; // Always load RS into 1st input
			aluin2_A <= aluimm_D ? sxtimm_D : RTval_D; // Perhaps load sxtimm into 2nd input, otherwise RT.
			sxtimm_A <= sxtimm_D;
			alufunc_A <= alufunc_D;
			wrreg_A <= wrreg_D;
			wrmem_A <= wrmem_D;
			ldmem_A <= ldmem_D;
			destreg_A <= destreg_D;
			RTreg_A <= RTval_D;
			isnop_A <= isnop_D | stall;
			isbranch_A <= isbranch_D;
			isjump_A <= isjump_D;
			pcpred_A <= pcpred_D;
		end
	end

	reg signed [(DBITS - 1):0] aluout_A;

	always @(alufunc_A or aluin1_A or aluin2_A or pcpred_A) begin
		case (alufunc_A)
			OP2_EQ: aluout_A = {31'b0, aluin1_A == aluin2_A};
			OP2_LT: aluout_A = {31'b0, aluin1_A < aluin2_A};
			OP2_LE: aluout_A = {31'b0, aluin1_A <= aluin2_A};
			OP2_NE: aluout_A = {31'b0, aluin1_A != aluin2_A};
			OP2_ADD: aluout_A = aluin1_A + aluin2_A;
			OP2_AND: aluout_A = aluin1_A & aluin2_A;
			OP2_OR: aluout_A = aluin1_A | aluin2_A;
			OP2_XOR: aluout_A = aluin1_A ^ aluin2_A;
			OP2_SUB: aluout_A = aluin1_A - aluin2_A;
			OP2_NAND: aluout_A = ~(aluin1_A & aluin2_A);
			OP2_NOR: aluout_A = ~(aluin1_A | aluin2_A);
			OP2_NXOR: aluout_A = ~(aluin1_A ^ aluin2_A);
			OP2_RSHF: aluout_A = (aluin1_A >>> aluin2_A);
			OP2_LSHF: aluout_A = (aluin1_A << aluin2_A);
			JAL_FUNC: aluout_A = pcpred_A;
			default: aluout_A = {DBITS{1'bX}};
		endcase
	end



	/*** MEM STAGE ****/
	reg signed [(DBITS - 1):0] memaddr_M;
	reg wrmem_M;
	reg ldmem_M;
	reg wrreg_M;
	reg ldreg_M;
	reg isnop_M;
	reg [(REGNOBITS - 1):0] destreg_M;
	reg [(DBITS - 1):0] wmemval_M;

	always @(posedge clk or posedge reset) begin
		if (reset) begin
			isnop_M <= 1'b1;
		end else begin
			memaddr_M <= aluout_A;
			wrmem_M <= wrmem_A;
			ldmem_M <= ldmem_A;
			wrreg_M <= wrreg_A;
			destreg_M <= destreg_A;
			wmemval_M <= RTreg_A;
			isnop_M <= isnop_A;
		end
	end

	// Create and connect HEX register
	reg [23:0] HEXout;
	reg [9:0] LEDRout;
	assign LEDR = LEDRout[9:0];
	SevenSeg ss5(.OUT(HEX5), .IN(HEXout[23:20]));
	SevenSeg ss4(.OUT(HEX4), .IN(HEXout[19:16]));
	SevenSeg ss3(.OUT(HEX3), .IN(HEXout[15:12]));
	SevenSeg ss2(.OUT(HEX2), .IN(HEXout[11:8]));
	SevenSeg ss1(.OUT(HEX1), .IN(HEXout[7:4]));
	SevenSeg ss0(.OUT(HEX0), .IN(HEXout[3:0]));

	reg [(DBITS - 1):0] ledr_data;
	always @(posedge clk or posedge reset) begin
		if (reset) begin
			LEDRout <= 10'b0;
			ledr_data <= 32'b0;
		end else if (wrmem_M && (memaddr_M == ADDRLEDR) && !isnop_M) begin
			// NOP check - Don't display HEX on NOP
			LEDRout <= wmemval_M[9:0];
			ledr_data <= {22'b0, wmemval_M[9:0]};
		end
	end

	reg [(DBITS - 1):0] hex_data;
	always @(posedge clk or posedge reset) begin
		if (reset) begin
			HEXout <= 24'hFEDEAD;
			hex_data <= 32'h00FEDEAD;
		end else if (wrmem_M && (memaddr_M == ADDRHEX) && !isnop_M) begin
			// NOP check - Don't display LEDR on NOP
			HEXout <= wmemval_M[23:0];
			hex_data <= {8'b0, wmemval_M[23:0]};
		end
	end

	// Now the real data memory
	wire MemEnable = !(memaddr_M[(DBITS - 1):DMEMADDRBITS]);
	wire MemWE = !reset & wrmem_M & MemEnable & !isnop_M; // NOP check - Don't write to mem on NOP
	(* ram_init_file = IMEMINITFILE, ramstyle = "no_rw_check" *)
	reg [(DBITS - 1):0] dmem[(DMEMWORDS - 1):0];

	always @(posedge clk) begin
		if (MemWE) begin
			dmem[memaddr_M[(DMEMADDRBITS - 1):DMEMWORDBITS]] <= wmemval_M;
		end
	end

	wire [(DBITS - 1):0] MemVal = MemWE ? {DBITS{1'bX}} : dmem[memaddr_M[(DMEMADDRBITS - 1):DMEMWORDBITS]];

	// Connect memory and input devices to the bus
	// you might need to change the following statement.

	// Connect SW device
	wire [(DBITS-1):0] sw_data;

	Debouncer #(
		.INIT(10'd0),
		.DBITS(DBITS),
		.IOBITS(10),
		.DEVICE_ADDR(ADDRSDATA),
		.CTRL_ADDR(ADDRSCTRL),
		.DEBOUNCE(900000)
	) devSW (
		.CLK(clk),
		.RESET(reset),
		.ABUS(memaddr_M),
		.DIN(wmemval_M),
		.DOUT(sw_data),
		.WE(wrmem_M),
		.IN(SW)
	);

	// Connect Key
	wire [(DBITS-1):0] key_data;

	Debouncer #(
		.INIT(4'd0),
		.DBITS(DBITS),
		.IOBITS(4),
		.DEVICE_ADDR(ADDRKDATA),
		.CTRL_ADDR(ADDRKCTRL),
		.DEBOUNCE(1)
	) devKEY (
		.CLK(clk),
		.RESET(reset),
		.ABUS(memaddr_M),
		.DIN(wmemval_M),
		.DOUT(key_data),
		.WE(wrmem_M),
		.IN(~KEY)
	);

	// Connect Timer
	wire [(DBITS-1):0] timer_data;

	Timer #(
		.DBITS(DBITS),
		.LIM_ADDR(ADDRTLIM),
		.CNT_ADDR(ADDRTCNT),
		.CTRL_ADDR(ADDRTCTRL),
		.MSTIME(90000)
	) devTimer (
		.CLK(clk),
		.RESET(reset),
		.ABUS(memaddr_M),
		.DIN(wmemval_M),
		.DOUT(timer_data),
		.WE(wrmem_M)
	);

	wire [(DBITS-1):0] dbus = (memaddr_M == ADDRHEX) ? hex_data :
									(memaddr_M == ADDRLEDR) ? ledr_data :
									(sw_data | key_data | timer_data);


	wire [(DBITS - 1):0] memout_M = MemEnable ? MemVal : dbus;


	// Determine register write value
	wire [(DBITS - 1):0] wregval_M = ldmem_M ? memout_M : memaddr_M;


	/*** Write Back Stage *****/
	integer r;
	integer i;
	always @(posedge clk or posedge reset) begin
		if (reset) begin
			for (i = 0; i < 16; i = i + 1) begin
				regs[i] <= 0;
			end
		end else if (wrreg_M && !reset && !isnop_M) begin
			// NOP check - Don't write to reg on NOP
			regs[destreg_M] <= wregval_M;
		end
	end
endmodule

module SXT(IN,OUT);
	parameter IBITS;
	parameter OBITS;
	input  [(IBITS - 1):0] IN;
  output [(OBITS - 1):0] OUT;
  assign OUT = {{(OBITS - IBITS){IN[IBITS - 1]}}, IN};
endmodule

module Debouncer(CLK, RESET, ABUS, DOUT, DIN, WE, IN);
	parameter DBITS;
	parameter IOBITS;
	parameter DEVICE_ADDR; // Address of data register
	parameter CTRL_ADDR; // Address of control register
	parameter INIT; // An empty register for resetting current and previous registers
	parameter DEBOUNCE; // Number of cycles for debounce functionality.

	input CLK;
	input RESET;
	input WE;
	input [(DBITS-1):0] ABUS; // Current address supplied by the processor.
	input [(IOBITS-1):0] IN; // Raw input of the device
	input [(DBITS-1):0] DIN;
	output [(DBITS-1):0] DOUT;

	reg [(DBITS-1):0] counter; // Counter variable.
	reg [(IOBITS-1):0] last;
	reg [(IOBITS-1):0] current; // Used to determine if IO data has changed
	reg ready;
	reg overflow; // The ready and overflow bits of the controller

	wire [(DBITS-1):0] io_data = {{(DBITS - IOBITS){1'b0}}, current}; // Extends the IO data.
	wire [(DBITS-1):0] ctrl = {{(DBITS - 2){1'b0}}, overflow, ready};
	wire dataActive = ABUS == DEVICE_ADDR; // Is this data access...
	wire ctrlActive = ABUS == CTRL_ADDR; // Or is this a control access?
	wire writeCtrl = WE && ctrlActive; // Are we writing control?
	wire readData = !WE && dataActive; // Are we reading data?
	wire readCtrl = !WE && ctrlActive; // Are we reading control?

	always @(posedge CLK or posedge RESET)
		if (RESET) begin
			current <= INIT; // Set current to all 0's
			last <= INIT; // Set previous to all 0's
			counter <= 0; // Reset counter
			ready <= 1'b0; // Reset ready bit
			overflow <= 1'b0; // Reset overflow bit
		end else begin

			if (counter == DEBOUNCE - 1) begin // Finished debouncing. Always runs for KEY.
				last <= current; // Previous now holds the last read value of IO data.
				current <= IN; // Confidently set current to raw input. Remember, current is appended to data.
				counter <= 0;
				if (last != current) begin // Change in data detected, we have a new value
					if (ready) // If we were already holding a new value, turn on overflow.
						overflow <= 1'b1;
					ready <= 1'b1;
				end
			end
			else begin
				counter <= counter + 1; // Increase counter
		   end

			if (readData) begin // On data reads, reset control.
				ready <= 1'b0;
				overflow <= 1'b0;
			end else if (writeCtrl)
			// If writing to control, check bus data to see if overflow was manually reset.
				if (!DIN[1])
					overflow <= 1'b0;
		end

	// Only output data on reads.
	assign DOUT = readData ? io_data : readCtrl ? ctrl : {DBITS{1'b0}};

endmodule

module Timer(CLK, RESET, ABUS, WE, DIN, DOUT);
	parameter DBITS;
	parameter LIM_ADDR; // MMIO address for limit reg
	parameter CNT_ADDR; // MMIO address for counter reg
	parameter CTRL_ADDR; // MMIO address for control reg
	parameter MSTIME; // Number of clock cycles per milli second

	input CLK;
	input RESET;
	input WE;
	input [(DBITS-1):0] ABUS;
	input [(DBITS-1):0] DIN;
	output [(DBITS-1):0] DOUT;

	reg [(DBITS-1):0] limit; // LIM
	reg [(DBITS-1):0] count; // CNT
	reg [(DBITS-1):0] internal_lim; // Used as lim for internal clock
	reg ready;
   reg overflow;

	wire [(DBITS-1):0] ctrl = {{(DBITS - 2){1'b0}},overflow,ready};

	wire countActive = ABUS == CNT_ADDR;
	wire limitActive = ABUS == LIM_ADDR;
	wire ctrlActive = ABUS == CTRL_ADDR;

	// Logic for function selection
	wire readCount = !WE && countActive;
	wire writeCount = WE && countActive;
	wire readLimit = !WE && limitActive;
	wire writeLimit = WE && limitActive;
	wire readCtrl = !WE && ctrlActive;
	wire writeCtrl = WE && ctrlActive;

	always @(posedge CLK or posedge RESET) begin
		if (RESET) begin
			internal_lim <= 0;
			count <= 0;
			limit <= 0;
			ready <= 1'b0;
			overflow <= 1'b0;
		end else begin
			if (internal_lim >= (MSTIME - 1)) begin // 1 MS has passed
				internal_lim <= 0;
				if (limit != 0 && count >= (limit - 1)) begin // Limit reached
					count <= 0;
					ready <= 1'b1;
					if (ready)
						overflow <= 1'b1;
				end else // Lim,it not reached
					count <= count + 1;
			end else // MS still not complete
				internal_lim <= internal_lim + 1;

			if (writeLimit) begin // Limit set
				limit <= DIN;
			end else if (writeCount) begin // Count set
				count <= DIN;
			end else if (writeCtrl) begin // Control set
				if (!DIN[0])
					ready <= 1'b0;
				if (!DIN[1])
					overflow <= 1'b0;
			end
		end
	end
	// Output based on func selection
	assign DOUT = readLimit ? limit : readCount ? count :	readCtrl ? ctrl : {DBITS{1'b0}};
endmodule
