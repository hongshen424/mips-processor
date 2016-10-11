// hazard unit module

module Hazard_detector(input clk, reset,
				  input BranchD_2,
				  input MemtoRegE_1, MemtoRegE_2,
				  input RegWriteD_1,
				  input RegWriteE_1, RegWriteE_2,
				  input MemtoRegM_1, MemtoRegM_2,
				  input RegWriteM_1, RegWriteM_2,
				  input RegWriteW_1, RegWriteW_2,
				  input [4:0] RsD_1, RsD_2,
				  input [4:0] RtD_1, RtD_2,
				  input [4:0] RsE_1, RsE_2,
				  input [4:0] RtE_1, RtE_2,
				  input [4:0] WriteRegD_1,
				  input [4:0] WriteRegE_1, WriteRegE_2,
				  input [4:0] WriteRegM_1, WriteRegM_2,
				  input [4:0] WriteRegW_1, WriteRegW_2,

				  output StallF_1, StallF_2,
				  output StallD_1, StallD_2,
				  output FlushE_1, FlushE_2,
				  input multReady,
				  input [1:0] mfReg,
				  input multStart,
				  output StallE_1, StallE_2,			// no reg for basic memstall condition
				  output StallM_1, StallM_2,			// no reg for basic memstall condition
				  output reg FlushM_1,
				  output FlushM_2,
				  output reg FlushW_1, FlushW_2,
				  input MemReady,
				  input MemWriteM,
				  input clrBufferD_1, clrBufferD_2,
				  output FlushD_1, FlushD_2,
				  
				  //FOR BRANCH PREDICTION
				  input BranchE_1, BranchE_2,
				  input PredictedE_1, PredictedE_2,
				  output FixMispredict_1, FixMispredict_2,
				  input PCSrcE_1, PCSrcE_2,
				  
				  //NEW
				  input PredictedTakenD_1, PredictedTakenD_2,
				  input EntryFoundD_1, EntryFoundD_2,
				  input [31:0] InstrD_1, InstrD_2,
				  input [31:0] InstrE_1, InstrE_2,
				  input [31:0] InstrM_1, InstrM_2,
				  
				  output ForwardAD,
				  output ForwardBD,
				  output [1:0] ForwardAE, 
				  output [1:0] ForwardBE,
				  output StallBothAtFetch,
				  output reg MemoryUser,
				  input MemWriteM_1, MemWriteM_2);
	
	assign ForwardAE = 2'b00;
	assign ForwardBE = 2'b00;
	assign ForwardAD = 1'b0;
	assign ForwardBD = 1'b0;
	
	//assign lwstall = ((RsD == RtE) || (RtD == RtE)) && MemtoRegE;

	// Conditions
	wire P1_E1, P1_M1, P1_E2, P1_M2;
	wire P2_E2, P2_M2, P2_D1, P2_E1, P2_M1;

	assign P1_E1 = (RegWriteE_1 && (((WriteRegE_1 == RsD_1) && (RsD_1 != 5'b00000)) || ((WriteRegE_1 == RtD_1) && (RtD_1 != 5'b00000))));
	assign P1_M1 = (RegWriteM_1 && (((WriteRegM_1 == RsD_1) && (RsD_1 != 5'b00000)) || ((WriteRegM_1 == RtD_1) && (RtD_1 != 5'b00000))));
	assign P1_E2 = (RegWriteE_2 && (((WriteRegE_2 == RsD_1) && (RsD_1 != 5'b00000)) || ((WriteRegE_2 == RtD_1) && (RtD_1 != 5'b00000))));
	assign P1_M2 = (RegWriteM_2 && (((WriteRegM_2 == RsD_1) && (RsD_1 != 5'b00000)) || ((WriteRegM_2 == RtD_1) && (RtD_1 != 5'b00000))));

	assign P2_E2 = (RegWriteE_2 && (((WriteRegE_2 == RsD_2) && (RsD_2 != 5'b00000)) || ((WriteRegE_2 == RtD_2) && (RtD_2 != 5'b00000))));
	assign P2_M2 = (RegWriteM_2 && (((WriteRegM_2 == RsD_2) && (RsD_2 != 5'b00000)) || ((WriteRegM_2 == RtD_2) && (RtD_2 != 5'b00000))));
	assign P2_D1 = (RegWriteD_1 && (((WriteRegD_1 == RsD_2) && (RsD_2 != 5'b00000)) || ((WriteRegD_1 == RtD_2) && (RtD_2 != 5'b00000))));
	assign P2_E1 = (RegWriteE_1 && (((WriteRegE_1 == RsD_2) && (RsD_2 != 5'b00000)) || ((WriteRegE_1 == RtD_2) && (RtD_2 != 5'b00000))));
	assign P2_M1 = (RegWriteM_1 && (((WriteRegM_1 == RsD_2) && (RsD_2 != 5'b00000)) || ((WriteRegM_1 == RtD_2) && (RtD_2 != 5'b00000))));

	// Stalling actions
	//wire StallBothAtFetch;
	wire StallOneAtDecode;
	wire StallTwoAtDecode;
	wire StartMemStall;
	reg [2:0] MemStall;
	wire SimpleMemStall;

	reg StallE_1_FromFSM;
	reg StallE_2_FromFSM;
	reg StallM_1_FromFSM;
	reg StallM_2_FromFSM;
	
	//BRANCHING
	wire BranchTwoStall, BranchOneFlushTwo;
	assign FixMispredict_1 = ((PCSrcE_1 ^ PredictedE_1) && BranchE_1);
	assign FixMispredict_2 = ((PCSrcE_2 ^ PredictedE_2) && BranchE_2);
	//second instruction is a branch: need to let inst1 finish
	assign BranchTwoStall = (BranchD_2 && (InstrD_1 != 0 || InstrE_1 != 0 || InstrM_1 != 0 ));
	//first instruction is a branch predicted taken: need to flush instr2
	assign BranchOneFlushTwo = (EntryFoundD_1 && PredictedTakenD_1);
	
	//JUMPING
	//flag to flushJump after memstall is over
	reg flushJump;
	//flushD from a jump
	reg flushDFromJump;
	wire JumpTwoStall;
	wire Jump;
	assign JumpTwoStall = (clrBufferD_2 && (InstrD_1 != 0 || InstrE_1 != 0 || InstrM_1 != 0 ));
	assign Jump = (clrBufferD_1 || (clrBufferD_2 && !JumpTwoStall));
	always @(*) begin
		if(Jump && (SimpleMemStall || StartMemStall || MemStall != 0)) begin
			flushJump <= 1; 
			flushDFromJump <= 0;
		end
		else if (Jump && !(SimpleMemStall || StartMemStall || MemStall != 0)) begin
			flushDFromJump <= 1;
		end

		if(flushJump && !(SimpleMemStall || StartMemStall || MemStall != 0)) begin
			flushJump <= 0; 
			flushDFromJump <= 1;
		end
		else if (!Jump) begin
			flushDFromJump <= 0;
		end
	end

	//StallBothAtFetch is also an output singal to stall F
	assign StallBothAtFetch = ((P1_E1 || P1_M1 || P1_E2 || P1_M2 || P2_E2 || P2_M2 || P2_D1 || P2_E1 || P2_M1) || (StartMemStall || MemStall != 0 || SimpleMemStall) || (BranchTwoStall ) || JumpTwoStall) && !(FixMispredict_1 || FixMispredict_2);
	assign StallOneAtDecode = (P1_E1 || P1_M1 || P1_E2 || P1_M2) || (StartMemStall || MemStall != 0 || SimpleMemStall);
	assign StallTwoAtDecode = (P2_E2 || P2_M2 || P2_D1 || P2_E1 || P2_M1) || (StartMemStall || MemStall != 0 || SimpleMemStall) || BranchTwoStall || JumpTwoStall;
	assign StartMemStall = ((MemtoRegM_1 && MemtoRegM_2) || (MemWriteM_1 && MemWriteM_2) || (MemtoRegM_1 && MemWriteM_2) || (MemWriteM_2 && MemtoRegM_1));
	assign SimpleMemStall = ((MemtoRegM_1 || MemWriteM_1 || MemtoRegM_2 || MemWriteM_2) && (!MemReady && MemStall == 0));

	// Output signals
	assign StallF_1 = StallBothAtFetch || StallOneAtDecode; // Not being actually used in datapaths
	assign StallF_2 = StallBothAtFetch || StallTwoAtDecode;

	assign StallD_1 = StallOneAtDecode;
	assign StallD_2 = StallTwoAtDecode;
	assign FlushD_1 = (StallBothAtFetch && StallTwoAtDecode && (MemStall == 0) && !(StallOneAtDecode && StallTwoAtDecode)) || FixMispredict_1 || FixMispredict_2 || flushDFromJump; //fixmispredict1
	assign FlushD_2 = (StallBothAtFetch && StallOneAtDecode && (MemStall == 0) && !(StallOneAtDecode && StallTwoAtDecode)) || FixMispredict_1 || FixMispredict_2 || flushDFromJump; //fixmispredict1 || fixmispredict2

	assign StallE_1 = (StallE_1_FromFSM || (MemStall == 0 && SimpleMemStall && !StartMemStall));
	assign StallE_2 = (StallE_2_FromFSM || (MemStall == 0 && SimpleMemStall && !StartMemStall));

	assign FlushE_1 = (StallOneAtDecode || FixMispredict_1 || FixMispredict_2 || flushDFromJump) && (MemStall == 0);
	assign FlushE_2 = (StallTwoAtDecode || BranchOneFlushTwo || FixMispredict_1 || FixMispredict_2 || flushDFromJump) && (MemStall == 0);

	assign StallM_1 = (StallM_1_FromFSM || (MemStall == 0 && SimpleMemStall));
	assign StallM_2 = (StallM_2_FromFSM || (MemStall == 0 && SimpleMemStall));

	assign FlushM_2 =  FixMispredict_1 || FixMispredict_2;

  	//assign FixMispredict = 1'b0;

	always @(negedge clk) begin
		if(reset) begin
			flushJump <= 0;
			MemStall <= 0;
			MemoryUser <= 0;
			StallE_1_FromFSM <= 0;
			StallE_2_FromFSM <= 0;
			StallM_1_FromFSM <= 0;
			StallM_2_FromFSM <= 0;
			FlushM_1 <= 0;
			//FlushM_2 <= 0;
			FlushW_1 <= 0;
			FlushW_2 <= 0;
		end else begin
			if (StartMemStall && MemStall == 0) begin
				//start stall when both pipelies try to access memory concurrently
				//pipeline 1 gets to go first
				MemStall = 1;
				MemoryUser = 1'b0;
				StallE_1_FromFSM = 1'b1;
				StallE_2_FromFSM = 1'b1;
				StallM_1_FromFSM = 1'b1;
				StallM_2_FromFSM = 1'b1;
	
				FlushM_1 = 1'b1;
				FlushW_2 = 1'b1;
			end
			else if (MemStall == 1 && MemReady) begin
				//switch to pipeline two as memory user
				MemStall = 3;
				MemoryUser = 1'b1;
			end
			else if(MemStall == 3 && MemReady) begin
				MemStall = 4;
			end
			else if(MemStall == 4 && MemReady) begin
				MemStall = 2;
			end
			else if (MemStall == 2 && MemReady) begin
				MemStall = 0;
				StallE_1_FromFSM = 1'b0;
				StallE_2_FromFSM = 1'b0;
				StallM_1_FromFSM = 1'b0;
				StallM_2_FromFSM = 1'b0;
				
				FlushM_1 = 1'b0;
				FlushW_2 = 1'b0;
			end
			else if (MemReady && (MemtoRegM_1 || MemWriteM_1)) begin
				MemoryUser = 1'b0;
			end
			else if (MemReady && (MemtoRegM_2 || MemWriteM_2)) begin
				MemoryUser = 1'b1;
			end
		end
	end

endmodule
