//2^7 table entries
`define TABLE_ENTRIES 7
`define TABLE_ENTRIES_SIZE 128

`define GLOBAL_BITS 4
`define GLOBAL_SIZE 4

`define STRONGLY_TAKEN 2'b11
`define WEAKLY_TAKEN 2'b10
`define WEAKLY_NOT_TAKEN 2'b01
`define STRONGLY_NOT_TAKEN 2'b00

module btb(input clk, reset,
		   input [31:0] PCF_1, PCF_2,			// from fetch (program counter input) x
		   input [31:0] branch_address_in_1, branch_address_in_2,	// from execute (PCE) x
		   input [31:0] predicted_address_in_1, predicted_address_in_2, // from execute (PCBranchE) x
		   input btb_write_1, btb_write_2,			// from execute (BTBWrite) = (!found + taken) x
		   input state_change_1, state_change_2,			// from execute (PCSrcE) = Taken x
		   input state_write_1, state_write_2,			// from execute (EntryFoundE) x
		   input branch_e_1, branch_e_2,			// from execute (BranchE)
		   output entry_found_1, entry_found_2, 		// To fetch (EntryFoundF)
		   output [31:0] predicted_pc_1, predicted_pc_2, // to fetch (PredictedPCF)
		   output predicted_taken_1, predicted_taken_2); //to fetch, buffered to decode stage and sent to hazard unit
		   
//global history predictor
reg [`GLOBAL_BITS-1:0] global_history;

//BTB table entries
reg [31:0] branchPCs[`TABLE_ENTRIES_SIZE-1:0][`GLOBAL_BITS-1:0];
reg [31:0] predictedPCs[`TABLE_ENTRIES_SIZE-1:0][`GLOBAL_BITS-1:0];
reg [1:0] predictionStates[`TABLE_ENTRIES_SIZE-1:0][`GLOBAL_BITS-1:0];

//fetch stage: check if branch is in the BTB and output predicted address
assign entry_found_1 = (PCF_1 == branchPCs[PCF_1[`TABLE_ENTRIES-1:0]][global_history]);
assign predicted_pc_1 = predictedPCs[PCF_1[`TABLE_ENTRIES-1:0]][global_history];
assign predicted_taken_1 = (predictionStates[PCF_1[`TABLE_ENTRIES-1:0]][global_history] < 2'b10) ? 1 : 0;

assign entry_found_2 = (PCF_2 == branchPCs[PCF_2[`TABLE_ENTRIES-1:0]][global_history]);
assign predicted_pc_2 = predictedPCs[PCF_2[`TABLE_ENTRIES-1:0]][global_history];
assign predicted_taken_2 = (predictionStates[PCF_2[`TABLE_ENTRIES-1:0]][global_history] < 2'b10) ? 1 : 0;

//for reset
integer i, j;

always@(negedge clk) begin
	//reset
	if(reset) begin
		for(j = 0; j < `GLOBAL_SIZE; j=j+1) begin
			for(i = 0; i < `TABLE_ENTRIES_SIZE; i = i+1) begin
				branchPCs[i][j] <= 1; //will never match because instructions are words
				predictedPCs[i][j] <= 1;
				predictionStates[i][j] <= `STRONGLY_NOT_TAKEN;
			end
		end
		global_history = `STRONGLY_NOT_TAKEN; 
	end else begin
		//writing a new entry to BTB
		if(btb_write_1) begin
			branchPCs[branch_address_in_1[`TABLE_ENTRIES-1:0]][global_history] <=  branch_address_in_1;
			predictedPCs[branch_address_in_1[`TABLE_ENTRIES-1:0]][global_history] <= predicted_address_in_1;
			predictionStates[branch_address_in_1[`TABLE_ENTRIES-1:0]][global_history] <=  `WEAKLY_TAKEN;
		end
		//changing the state of an entry
		if(state_write_1) begin
			if(state_change_1 == 1) begin
			//taken
				if(predictionStates[branch_address_in_1[`TABLE_ENTRIES-1:0]][global_history] != `STRONGLY_TAKEN)
					predictionStates[branch_address_in_1[`TABLE_ENTRIES-1:0]][global_history] = predictionStates[branch_address_in_1[`TABLE_ENTRIES-1:0]][global_history] + 1;
			end else begin
			//not taken
				if(predictionStates[branch_address_in_1[`TABLE_ENTRIES-1:0]][global_history] != `STRONGLY_NOT_TAKEN)
					predictionStates[branch_address_in_1[`TABLE_ENTRIES-1:0]][global_history] = predictionStates[branch_address_in_1[`TABLE_ENTRIES-1:0]][global_history] - 1;
			end
			
			//after state change, update entry
			case(predictionStates[branch_address_in_1[`TABLE_ENTRIES-1:0]][global_history])
				`STRONGLY_TAKEN: predictedPCs[branch_address_in_1[`TABLE_ENTRIES-1:0]][global_history] = predicted_address_in_1;
				`WEAKLY_TAKEN: predictedPCs[branch_address_in_1[`TABLE_ENTRIES-1:0]][global_history] = predicted_address_in_1;
				`WEAKLY_NOT_TAKEN: predictedPCs[branch_address_in_1[`TABLE_ENTRIES-1:0]][global_history] = branch_address_in_1 + 4;
				`STRONGLY_NOT_TAKEN: predictedPCs[branch_address_in_1[`TABLE_ENTRIES-1:0]][global_history] = branch_address_in_1 + 4;
			endcase
		end
		//PIPELINE 2
		//writing a new entry to BTB
		if(btb_write_2) begin
			branchPCs[branch_address_in_2[`TABLE_ENTRIES-1:0]][global_history] <=  branch_address_in_2;
			predictedPCs[branch_address_in_2[`TABLE_ENTRIES-1:0]][global_history] <= predicted_address_in_2;
			predictionStates[branch_address_in_2[`TABLE_ENTRIES-1:0]][global_history] <=  `WEAKLY_TAKEN;
		end
		//changing the state of an entry
		if(state_write_1) begin
			if(state_change_1 == 1) begin
			//taken
				if(predictionStates[branch_address_in_2[`TABLE_ENTRIES-1:0]][global_history] != `STRONGLY_TAKEN)
					predictionStates[branch_address_in_2[`TABLE_ENTRIES-1:0]][global_history] = predictionStates[branch_address_in_2[`TABLE_ENTRIES-1:0]][global_history] + 1;
			end else begin
			//not taken
				if(predictionStates[branch_address_in_2[`TABLE_ENTRIES-1:0]][global_history] != `STRONGLY_NOT_TAKEN)
					predictionStates[branch_address_in_2[`TABLE_ENTRIES-1:0]][global_history] = predictionStates[branch_address_in_2[`TABLE_ENTRIES-1:0]][global_history] - 1;
			end
			
			//after state change, update entry
			case(predictionStates[branch_address_in_2[`TABLE_ENTRIES-1:0]][global_history])
				`STRONGLY_TAKEN: predictedPCs[branch_address_in_2[`TABLE_ENTRIES-1:0]][global_history] = predicted_address_in_2;
				`WEAKLY_TAKEN: predictedPCs[branch_address_in_2[`TABLE_ENTRIES-1:0]][global_history] = predicted_address_in_2;
				`WEAKLY_NOT_TAKEN: predictedPCs[branch_address_in_2[`TABLE_ENTRIES-1:0]][global_history] = branch_address_in_2 + 4;
				`STRONGLY_NOT_TAKEN: predictedPCs[branch_address_in_2[`TABLE_ENTRIES-1:0]][global_history] = branch_address_in_2 + 4;
			endcase
		end
		//changing the state of global history predictor
		if(branch_e_1) begin
			if(state_change_1 == 1) begin
			//taken
				if(global_history != `STRONGLY_TAKEN)
					global_history = global_history + 1;
			end else begin
			//not taken
				if(global_history != `STRONGLY_NOT_TAKEN)
					global_history = global_history - 1;
			end
		end
		if(branch_e_2) begin
			if(state_change_2 == 1) begin
			//taken
				if(global_history != `STRONGLY_TAKEN)
					global_history = global_history + 1;
			end else begin
			//not taken
				if(global_history != `STRONGLY_NOT_TAKEN)
					global_history = global_history - 1;
			end
		end
	end
end

endmodule
