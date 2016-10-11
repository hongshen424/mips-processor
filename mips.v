// Pipelined MIPS processor
// Top level system including MIPS and memories
// Instantiates a controller, datapath module and hazard control unit

module mips(input clk, reset);		

  // INSTRUCTION MEMORY	
  wire [63:0] InstrF; 				// From instruction memory, to datapath
  wire [31:0] PCMaster;
  
  (* dont_touch = "true" *) Inst_memory imem(PCMaster[7:2], InstrF);


  // DATA MEMORY
  // Multiplexed signals into data memory
  wire MemoryUser;
  //assign MemoryUser = 1'b0;
  wire [31:0] WriteDataM_1, WriteDataM_2, WriteDataM_mux;	
  wire [31:0] ALUOutM_1, ALUOutM_2, ALUOutM_mux;
  wire        MemWriteM_1, MemWriteM_2, MemWriteM_mux;
  wire        MemtoRegM_1, MemtoRegM_2, MemtoRegM_mux;
  mux2 #(32) WriteDataMux(WriteDataM_1, WriteDataM_2, MemoryUser, WriteDataM_mux);
  mux2 #(32) ALUOutMux(ALUOutM_1, ALUOutM_2, MemoryUser, ALUOutM_mux);
  mux2 #(1) MemWriteMux(MemWriteM_1, MemWriteM_2, MemoryUser, MemWriteM_mux);
  mux2 #(1) MemtoRegMux(MemtoRegM_1, MemtoRegM_2, MemoryUser, MemtoRegM_mux);

  // Single outputs from data memory
  wire [31:0] ReadDataM; 	// To datapath
  wire        MemReady;	// To hazard unit


  (* dont_touch = "true" *) Data_memory dmem(clk, reset, 
		MemWriteM_mux, 		// multiplex
		ALUOutM_mux, 		// multiplex
		WriteDataM_mux, 	// multiplex
		MemtoRegM_mux, 		// multiplex
		ReadDataM, 		// Can go to both datapaths, will be ignored if irrelevant
		MemReady		// Already goes to hazard unit, only one needed
		);

  // Wires between everything
  wire [1:0]   mfRegD;
              
  // Wires between hazard/forwarding units and datapath
  wire MemtoRegE_1, MemtoRegE_2;
  wire RegWriteD_1, RegWriteD_2;
  wire RegWriteE_1, RegWriteE_2;
  wire [4:0] RsD_1, RtD_1, RsE_1, RtE_1;
  wire [4:0] RsD_2, RtD_2, RsE_2, RtE_2;
  wire [4:0] WriteRegD_1, WriteRegD_2; 
  wire [4:0] WriteRegE_1, WriteRegE_2; 
  wire [4:0] WriteRegM_1, WriteRegM_2;
  wire StallF_1, StallF_2;
  wire FlushD_1, FlushD_2;
  wire StallD_1, StallD_2;
  wire FlushE_1, FlushE_2;
  wire StallE_1, StallE_2;
  wire StallM_1, StallM_2;
  wire FlushM_1, FlushM_2;
  wire FlushW_1, FlushW_2;
  wire BranchD_1, BranchD_2;

  wire ForwardAD, ForwardBD;
  wire [1:0] ForwardAE, ForwardBE;

  wire multReady, startMultE;
  wire [1:0] mfRegE;

  wire clrBufferD_1, clrBufferD_2;
  wire PredictedE_1, PredictedE_2;
  wire RegWriteM_1, RegWriteM_2;

  // Branching wires from datapaths to hazard unit
  wire 	PCSrcE_1, PCSrcE_2;
  wire Predicted_Taken_D1, Predicted_Taken_D2;
  wire EntryFoundD_1, EntryFoundD_2;
  wire [31:0] InstrE_1, InstrE_2;
  wire [31:0] InstrM_1, InstrM_2;

  // Between datapaths, register file, and hazard unit
  wire [31:0] InstrD_1, InstrD_2;


  // Hazard unit will need to accept BOTH wires
  wire RegWriteW_1, RegWriteW_2;
  wire [4:0] WriteRegW_1, WriteRegW_2;

  // wires between datapath ONE and register file
  wire [31:0] ResultW_1, RD1D_1, RD2D_1;

  // wires between datapath TWO and register file
  wire [31:0] ResultW_2, RD1D_2, RD2D_2;

  regfile rf(		clk, 	
			RegWriteW_1, RegWriteW_2, 
			reset, 
			InstrD_1[25:21], InstrD_2[25:21], 	// Done
			InstrD_1[20:16], InstrD_2[20:16],	// Done
			WriteRegW_1, WriteRegW_2, 
			ResultW_1, ResultW_2, 			// Done
			RD1D_1, RD1D_2,				// Done
			RD2D_1, RD2D_2				// Done
			);


// MERGED FETCH STAGE
  wire [31:0] PCNext;
  wire [31:0] PCMasterPlus8;

  wire StallBothAtFetch;
  wire notStallPC;
  not PCnot(notStallPC, StallBothAtFetch);
  reset_enable_ff #(32) PCreg(clk, reset, notStallPC, PCNext, PCMaster); 
  adder PCadd1(PCMaster, 32'b1000, PCMasterPlus8);

  // Needed for second datapath to calculate branch addresses
  wire [31:0] PCMasterPlus4;
  adder PCadd2(PCMaster, 32'b0100, PCMasterPlus4);

// BRANCHING
  // BTB Inputs, from datapaths
  wire [31:0] PCE_1, PCE_2, PCBranchE_1, PCBranchE_2;
  wire BTBWriteE_1, BTBWriteE_2;
  wire EntryFoundE_1, EntryFoundE_2;
  wire BranchE_1, BranchE_2;
  wire Predicted_Taken_F1, Predicted_Taken_F2;

  // BTB outputs
  wire EntryFoundF_1, EntryFoundF_2;
  wire [31:0] PredictedPCF_1, PredictedPCF_2;

  // Choosing PC predicted by BTB
  wire [31:0] PCPrediction;
  wire [1:0] EntryFoundCombined;
  assign EntryFoundCombined = {EntryFoundF_1, EntryFoundF_2};
  mux4 #(32) PCPredictionMux(PCMasterPlus8, PredictedPCF_2, PredictedPCF_1, PredictedPCF_1, EntryFoundCombined, PCPrediction);

  // Choosing PC for fixing mispredictions
  wire FixMispredict, FixMispredict_1, FixMispredict_2;
  assign FixMispredict = FixMispredict_1 || FixMispredict_2;
  wire [31:0] PCPlus4E_1, PCPlus4E_2;
  wire [31:0] PCMisprediction; // After mux
  wire [31:0] PCMisprediction_P1, PCMisprediction_P2; // Preliminary muxed signals
  mux2 #(32) PCMispredictionMux_P1(PCPlus4E_1, PCBranchE_1, PCSrcE_1, PCMisprediction_P1);
  mux2 #(32) PCMispredictionMux_P2(PCPlus4E_2, PCBranchE_2, PCSrcE_2, PCMisprediction_P2);
  mux2 #(32) PCMispredictionMux_PipelineSelector(PCMisprediction_P1, PCMisprediction_P2, FixMispredict_2, PCMisprediction);

  // Choosing final PC from branching operations
  wire [31:0] PCBranching;
  mux2 #(32) PCBranchMux(PCPrediction, PCMisprediction, FixMispredict, PCBranching);

// JUMPING
  wire [31:0] PCJump_1, PCJump_2, PCJump_muxed;

  mux2 #(32) PCJumpMux(PCJump_1, PCJump_2, clrBufferD_2, PCJump_muxed);

  wire JumpOrBranch;
  assign JumpOrBranch = ((clrBufferD_1 || clrBufferD_2) && !(PCSrcE_1 || PCSrcE_2));			//assign JumpNotBranch = (JumpD && ~PCSrcE);
  mux2 #(32) PCSourceMux(PCBranching, PCJump_muxed, JumpOrBranch, PCNext);


  // BRANCH TARGET BUFFER
  btb buffer(clk, reset, PCMaster, PCMasterPlus4, PCE_1, PCE_2, PCBranchE_1, PCBranchE_2, BTBWriteE_1, BTBWriteE_2, PCSrcE_1, PCSrcE_2, EntryFoundE_1, EntryFoundE_2, BranchE_1, BranchE_2, EntryFoundF_1, EntryFoundF_2, PredictedPCF_1, PredictedPCF_2, Predicted_Taken_F1, Predicted_Taken_F2);


  datapath dp_1(clk, reset, 
		RegWriteD_1,
              BranchD_1,                               // to hazard unit
              PCMaster, InstrF[31:0],                    // to/from instruction memory
              ALUOutM_1, WriteDataM_1, 
              MemWriteM_1, 
	       ReadDataM, 				// Single from data memory
              MemtoRegE_1, RegWriteE_1, MemtoRegM_1,
              RegWriteM_1, RegWriteW_1,
              RsD_1, RtD_1, RsE_1, RtE_1,
              WriteRegD_1, WriteRegE_1, WriteRegM_1, WriteRegW_1,

              StallF_1, StallD_1, FlushE_1,
              ForwardAD, ForwardBD,
              ForwardAE, ForwardBE, 

	       mfRegD,
	       multReady, mfRegE, startMultE, 

	       StallE_1, StallM_1, FlushW_1, clrBufferD_1, FlushD_1,

	       BranchE_1, PredictedE_1, FixMispredict_1, PCSrcE_1, 

	       ResultW_1, RD1D_1, RD2D_1, FlushM_1,
		PCE_1, PCBranchE_1, BTBWriteE_1, EntryFoundE_1, PredictedPCF_1,

		Predicted_Taken_F1,
		Predicted_Taken_D1, EntryFoundD_1, InstrD_1, InstrE_1, InstrM_1,
		PCPlus4E_1,

		PCJump_1, EntryFoundF_1
              );    

  datapath dp_2(clk, reset, 
	       RegWriteD_2,
              BranchD_2,                               	// to hazard unit
              PCMasterPlus4, InstrF[63:32],                  // to/from instruction memory
              ALUOutM_2, WriteDataM_2, 
              MemWriteM_2, 
		ReadDataM,					// okay
              MemtoRegE_2, RegWriteE_2, MemtoRegM_2,
              RegWriteM_2, RegWriteW_2,
              RsD_2, RtD_2, RsE_2, RtE_2,
              WriteRegD_2, WriteRegE_2, WriteRegM_2, WriteRegW_2,

              StallF_2, StallD_2, FlushE_2,
              ForwardAD, ForwardBD,
              ForwardAE, ForwardBE, 

	       mfRegD,
	       multReady, mfRegE, startMultE, 

	       StallE_2, StallM_2, FlushW_2, clrBufferD_2, FlushD_2,

	       BranchE_2, PredictedE_2, FixMispredict_2, PCSrcE_2, 

	       ResultW_2, RD1D_2, RD2D_2, FlushM_2,
		PCE_2, PCBranchE_2, BTBWriteE_2, EntryFoundE_2, PredictedPCF_2,
	
		Predicted_Taken_F2,
		Predicted_Taken_D2, EntryFoundD_2, InstrD_2, InstrE_2, InstrM_2,
		PCPlus4E_2,

		PCJump_2, EntryFoundF_2
              );


  Hazard_detector hazard(clk, reset,
				BranchD_2,
				MemtoRegE_1, MemtoRegE_2,
				RegWriteD_1,
				RegWriteE_1, RegWriteE_2,
				MemtoRegM_1, MemtoRegM_2,
				RegWriteM_1, RegWriteM_2,
				RegWriteW_1, RegWriteW_2,
				RsD_1, RsD_2,
				RtD_1, RtD_2,
				RsE_1, RsE_2,
				RtE_1, RtE_2,
				WriteRegD_1,
				WriteRegE_1, WriteRegE_2,
				WriteRegM_1, WriteRegM_2,
				WriteRegW_1, WriteRegW_2,

				StallF_1, StallF_2,
				StallD_1, StallD_2, 
				FlushE_1, FlushE_2, 

				multReady,
				mfRegD,
				startMultE,

				StallE_1, StallE_2,
				StallM_1, StallM_2,
				FlushM_1, FlushM_2,
				FlushW_1, FlushW_2,
				MemReady,
				MemWriteM_1,

				clrBufferD_1, clrBufferD_2,
				FlushD_1, FlushD_2,

				BranchE_1, BranchE_2,
				PredictedE_1, PredictedE_2,
				FixMispredict_1, FixMispredict_2,
				PCSrcE_1, PCSrcE_2, 

				Predicted_Taken_D1, Predicted_Taken_D2,
				EntryFoundD_1, EntryFoundD_2,
				InstrD_1, InstrD_2,
				InstrE_1, InstrE_2,
				InstrM_1, InstrM_2,

				ForwardAD, ForwardBD,
				ForwardAE, ForwardBE,
				StallBothAtFetch, MemoryUser,
				MemWriteM_1, MemWriteM_2
				);

   
endmodule
