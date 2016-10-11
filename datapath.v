// Datapath
module datapath(input          clk, reset,

                output         RegWriteD, 
		 //input	 MemtoRegD,         
                //input          MemWriteD,
                //input   [3:0]  ALUControlD,
                //input          ALUSrcD, RegDstD,
                output          BranchD,

                input  [31:0] PCF,
                input   [31:0] InstrF,
                output  [31:0] ALUOutM, WriteDataM,
                output         MemWriteM,
                input   [31:0] ReadDataM,
		 output MemtoRegE,
		 output RegWriteE,
		 output MemtoRegM,
		 output RegWriteM,
		 output RegWriteW,
		 output [4:0] RsD,
		 output [4:0] RtD,
		 output [4:0] RsE,
		 output [4:0] RtE,
		 output [4:0] WriteRegD,
		 output [4:0] WriteRegE,
		 output [4:0] WriteRegM,
		 output [4:0] WriteRegW,
		 input StallF,
		 input StallD,
		 input FlushE,
		 input ForwardAD,
		 input ForwardBD,
		 input [1:0] ForwardAE, 
		 input [1:0] ForwardBE,


		 //input JumpD,
		 //input startMultD, signedMultD, 
		 output [1:0] mfRegD,


		 output multReady,
		 output [1:0] mfRegE,
		 output startMultE,


		 //input branchNE,

		 input StallE,
		 input StallM,
		 input FlushW,
		 output clrBufferD,
		 input FlushD,
		 output BranchE,
		 output PredictedE,
		 input FixMispredict,
		 output PCSrcE,
		 output [31:0] ResultW,
		 output [31:0] RD1D, RD2D,
		 input FlushM,
		 output [31:0] PCE, PCBranchE,
		 output BTBWriteE, EntryFoundE,
		 input [31:0] PredictedPCF,

		 input Predicted_Taken_F,
		 output Predicted_Taken_D, EntryFoundD, 
		 output [31:0] InstrD, InstrE, InstrM,
		 output [31:0] PCPlus4E,

		 output [31:0] PCJump,
		 input EntryFoundF
		 );

// Controller module
//wire        RegWriteD, 
wire          MemtoRegD;     
wire          MemWriteD;
wire   [3:0]  ALUControlD;
wire          ALUSrcD, RegDstD;
wire JumpD;
wire startMultD, signedMultD; 
//wire [1:0] mfRegD;
wire branchNE;

wire [3:0] aluop;

mainDecoder dec(InstrD[31:26], MemtoRegD, MemWriteD, BranchD, ALUSrcD, RegDstD, RegWriteD, JumpD, aluop, branchNE);
aluDecoder aluDec(InstrD[5:0], aluop, ALUControlD, startMultD, signedMulDt, mfRegD);


// FETCH STAGE

// Pretty much just shared now, in module 'mips'
// "InstrF" comes as an input

wire [31:0] PCPlus4F;
adder PCadd1(PCF, 32'b100, PCPlus4F);


// DECODE STAGE
wire [31:0] PCPlus4D;

wire notStallD;
not stallDnot(notStallD, StallD);

assign clrBufferD = JumpD;

wire [31:0] PredictedPCD, PCD;


decode_buffer bufferD(clk, reset, FlushD, notStallD, InstrF, PCPlus4F, InstrD, PCPlus4D, EntryFoundF, PredictedPCF, PCF, EntryFoundD, PredictedPCD, PCD, Predicted_Taken_F, Predicted_Taken_D);

//wire [31:0] ResultW;
//wire [31:0] RD1D, RD2D;
wire [31:0] SignImmD, SignImmshD;
wire [31:0] RD1muxed, RD2muxed;
wire EqualD, EqualOrNotEqualD;
wire [31:0] PCBranchD;
wire PCSrcD;

// Moved out of module
//regfile rf(clk, RegWriteW, reset, InstrD[25:21], InstrD[20:16], WriteRegW, ResultW, RD1D, RD2D);

signext se(InstrD[15:0], SignImmD);
sl2 immsh(SignImmD, SignImmshD);
adder PCadd2(PCPlus4D, SignImmshD, PCBranchD); 

// Determine if branching:
mux2 #(32) PCmuxRD1(RD1D, ALUOutM, ForwardAD, RD1muxed);
mux2 #(32) PCmuxRD2(RD2D, ALUOutM, ForwardBD, RD2muxed);

// For Jump
assign PCJump = {PCPlus4D[31:28], InstrD[25:0], 2'b00};

equality equals(RD1muxed, RD2muxed, EqualD);
assign EqualOrNotEqualD = (branchNE) ? ~EqualD : EqualD;
and PCsrcand(PCSrcD, BranchD, EqualOrNotEqualD);

assign RsD = InstrD[25:21];
assign RtD = InstrD[20:16];
assign RdD = InstrD[15:11];

mux2 #(5) WriteRegDmux(InstrD[20:16], InstrD[15:11], RegDstD, WriteRegD);



// EXECUTE STAGE
wire         signedMultE;
//wire [1:0]  mfRegE;
//wire        RegWriteE, MemtoRegE; 
wire        MemWriteE, ALUSrcE, RegDstE;
wire [3:0]  ALUControlE;
wire [31:0] ALUOutE;
wire [31:0] RD1E, RD2E;
wire [31:0] SignImmE;
wire [4:0]  RdE;
// wire [31:0] PCPlus4E; moved to output
wire [31:0] PredictedPCE;

wire notStallE;
not stallEnot(notStallE, StallE);

execute_buffer bufferE(clk, reset, FlushE, notStallE,
	startMultD, signedMultD, mfRegD,
	RegWriteD, MemtoRegD, MemWriteD, ALUControlD,
	ALUSrcD, RegDstD, RD1D, RD2D, InstrD[25:21], InstrD[20:16], InstrD[15:11], SignImmD,
	startMultE, signedMultE, mfRegE,
	RegWriteE, MemtoRegE, MemWriteE, ALUControlE,
	ALUSrcE, RegDstE, RD1E, RD2E, RsE, RtE, RdE, SignImmE,
	BranchD, EntryFoundD, PredictedPCD, PCD, PCBranchD, PCPlus4D, 
	BranchE, EntryFoundE, PredictedPCE, PCE, PCBranchE, PCPlus4E,
	PCSrcD, PCSrcE,
	InstrD, InstrE
	);
	

equality prediction(PredictedPCE, PCBranchE, PredictedE);
	// PredictedE = PredictedPCE == PCBranchE
not EntryFoundNot(notEntryFoundE, EntryFoundE);
and BTBWriteAnd(BTBWriteE, PCSrcE, notEntryFoundE);



wire [31:0] srcaE, srcbE, WriteDataE;
// wire [4:0] WriteRegE - will be output anyways

mux2 #(5) WriteRegEmux(RtE, RdE, RegDstE, WriteRegE);

mux4 #(32) srcaEmux(RD1E, ResultW, ALUOutM, 32'h00000000, ForwardAE, srcaE);
mux4 #(32) WriteDataEmux(RD2E, ResultW, ALUOutM, 32'h00000000, ForwardBE, WriteDataE);
mux2 #(32) srcbEmux(WriteDataE, SignImmE, ALUSrcE, srcbE);

wire [31:0] ALUOut;
alu alu(srcaE, srcbE, ALUControlE, ALUOut);

wire [63:0] MultOut;
multiplier mult(srcaE, srcbE, startMultE, signedMultE, clk, reset, MultOut, multReady);

mux4 #(32) resultMux(ALUOut, MultOut[31:0], MultOut[63:32], 32'h00000000, mfRegE, ALUOutE);

// MEMORY STAGE

wire notStallM;
not stallMnot(notStallM, StallM);

memory_buffer bufferM(clk, reset, FlushM, notStallM,
	RegWriteE, MemtoRegE, MemWriteE, ALUOutE, WriteDataE, WriteRegE,
	RegWriteM, MemtoRegM, MemWriteM, ALUOutM, WriteDataM, WriteRegM,
	InstrE, InstrM);

// (nothing actually needed here!)



// WRITEBACK STAGE
wire        MemtoRegW;
wire [31:0] ReadDataW, ALUOutW;


writeback_buffer bufferW(clk, reset, FlushW,
	RegWriteM, MemtoRegM, ReadDataM, ALUOutM, WriteRegM,
	RegWriteW, MemtoRegW, ReadDataW, ALUOutW, WriteRegW);

mux2 #(32)  resultmux(ALUOutW, ReadDataW, MemtoRegW, ResultW);


endmodule



