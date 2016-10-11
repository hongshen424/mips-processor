module regfile(input clk,
		input write_1, write_2,
		input reset,
		input [4:0] PR1_1, PR1_2, PR2_1, PR2_2, WR_1, WR_2,
		input [31:0] WD_1, WD_2,
		output [31:0] RD1_1, RD1_2, RD2_1, RD2_2);
reg [31:0] rf [31:0];
integer i; //for reset

always @ (clk) begin
	if(reset) begin
		//reset all registers to 0
		for(i = 0; i < 32; i=i+1)
			rf[i] <= 32'd0;
	end
	
	if (write_1) begin
		rf[WR_1] <= WD_1;
	end	
	if (write_2) begin
		rf[WR_2] <= WD_2;
	end	
end
 
assign RD1_1 = (PR1_1 != 0) ? rf[PR1_1] : 0;
assign RD2_1 = (PR2_1 != 0) ? rf[PR2_1] : 0;	
assign RD1_2 = (PR1_2 != 0) ? rf[PR1_2] : 0;
assign RD2_2 = (PR2_2 != 0) ? rf[PR2_2] : 0;	

endmodule

module adder(input [31:0] a, b,
		output [31:0] y);
assign y = a + b;
endmodule

module sl2(input [31:0] a,
		output [31:0] y);
assign y = {a[29:0], 2'b00};
endmodule

module signext(	input [15:0] a,
		output [31:0] y);
assign y = {{16{a[15]}}, a};
endmodule

module equality(input [31:0] a, b,
		output y);
assign y = (a == b);
endmodule


module reset_ff #(parameter WIDTH = 8)(
		input clk, reset,
		input [(WIDTH-1):0] d,
		output reg [(WIDTH-1):0] q);

always @ (posedge clk, posedge reset)
	if (reset) begin
		q <= 0;
	end
	else begin
		q <= d;
	end
endmodule

module reset_enable_ff #(parameter WIDTH = 8)(
		input clk, reset, enable,
		input [(WIDTH-1):0] d,
		output reg [(WIDTH-1):0] q);

always @ (posedge clk, posedge reset)
	if (reset) begin
		q <= 0;
	end
	else if (enable) begin
		q <= d;
	end
endmodule


// Variable-width 2:1 multiplexer
module mux2 #(parameter WIDTH = 8)(
		input [(WIDTH-1):0] d0,
		input [(WIDTH-1):0] d1,
		input s,
		output [(WIDTH-1):0] y);
assign y = s ? d1 : d0;
endmodule

// Variable-width 4:1 multiplexer
module mux4 #(parameter WIDTH = 8)(
		input [(WIDTH-1):0] d0,
		input [(WIDTH-1):0] d1,
		input [(WIDTH-1):0] d2,
		input [(WIDTH-1):0] d3,
		input [0:1] s,
		output [(WIDTH-1):0] y);
reg [WIDTH-1:0] outputy;
assign y = outputy;

always @(*) begin
	case (s)
		2'd0: outputy = d0;
		2'd1: outputy = d1;
		2'd2: outputy = d2;
		2'd3: outputy = d3; 
	endcase
end
endmodule

module decode_buffer(
		input clk, reset, clr, enable,
		input [31:0] InstrF,
		input [31:0] PCPlus4F,
		output reg [31:0] InstrD,
		output reg [31:0] PCPlus4D,
		input EntryFoundF,
		input [31:0] PredictedPCF,
		input [31:0] PCF,
		output reg EntryFoundD,
		output reg [31:0] PredictedPCD,
		output reg [31:0] PCD, 
		input Predicted_Taken_F, 
		output reg Predicted_Taken_D);

always @ (posedge clk, posedge reset)
	if (reset) begin
		InstrD <= 32'h00000000;
		PCPlus4D <= 32'h00000000;
		EntryFoundD <= 1'b0;
		PredictedPCD <= 32'h00000000;
		PCD <= 32'h00000000;
		Predicted_Taken_D <= 1'b0;
	end
	else if (clr) begin
		InstrD <= 32'h00000000;
		PCPlus4D <= 32'h00000000;
		EntryFoundD <= 1'b0;
		PredictedPCD <= 32'h00000000;
		PCD <= 32'h00000000;
		Predicted_Taken_D <= 1'b0;
	end
	else if (enable) begin
		InstrD <=  InstrF;
		PCPlus4D <= PCPlus4F;
		EntryFoundD <= EntryFoundF;
		PredictedPCD <= PredictedPCF;
		PCD <= PCF;
		Predicted_Taken_D <= Predicted_Taken_F;
	end
endmodule

module execute_buffer(
		input clk, reset, clr, enable,
		input startMultD, signedMultD, 
		input [1:0] mfRegD,
		input RegWriteD, MemtoRegD, MemWriteD,
		input [3:0] ALUControlD,
		input ALUSrcD, RegDstD,
		input [31:0] RD1D, RD2D, 
		input [4:0] RsD, RtD, RdD,
		input [31:0] SignImmD,
		output reg startMultE, signedMultE, 
		output reg [1:0] mfRegE,
		output reg RegWriteE, MemtoRegE, MemWriteE,
		output reg [3:0] ALUControlE,
		output reg ALUSrcE, RegDstE,
		output reg [31:0] RD1E, RD2E, 
		output reg [4:0] RsE, RtE, RdE,
		output reg [31:0] SignImmE,
		input BranchD,
		input EntryFoundD,
		input [31:0] PredictedPCD,
		input [31:0] PCD,
		input [31:0] PCBranchD,
		input [31:0] PCPlus4D,
		output reg BranchE,
		output reg EntryFoundE,
		output reg [31:0] PredictedPCE,
		output reg [31:0] PCE,
		output reg [31:0] PCBranchE,
		output reg [31:0] PCPlus4E,
		input PCSrcD,
		output reg PCSrcE,
		input [31:0] InstrD, 
		output reg [31:0] InstrE
		);

always @ (posedge clk, posedge reset)
	if (reset) begin
		startMultE <= 0;
		signedMultE <= 0;
		mfRegE <= 2'b00;
		RegWriteE <= 0;
		MemtoRegE <= 0;
		MemWriteE <= 0;
		ALUControlE <= 4'h0;
		ALUSrcE <= 0;
		RegDstE <= 0;
		RD1E <= 32'h00000000;
		RD2E <= 32'h00000000; 
		RsE <= 4'h0;
		RtE <= 4'h0;
		RdE <= 4'h0;
		SignImmE <= 32'h00000000;
		BranchE <= 1'b0;
		EntryFoundE <= 1'b0;
		PredictedPCE <= 32'h00000000;
		PCE <= 32'h00000000;
		PCBranchE <= 32'h00000000;
		PCPlus4E <= 32'h00000000;
		PCSrcE <= 1'b0;
		InstrE <= 32'h00000000;
	end
	else if (clr) begin
		startMultE <= 0;
		signedMultE <= 0;
		mfRegE <= 2'b00;
		RegWriteE <= 0;
		MemtoRegE <= 0;
		MemWriteE <= 0;
		ALUControlE <= 4'h0;
		ALUSrcE <= 0;
		RegDstE <= 0;
		RD1E <= 32'h00000000;
		RD2E <= 32'h00000000; 
		RsE <= 4'h0;
		RtE <= 4'h0;
		RdE <= 4'h0;
		SignImmE <= 32'h00000000;
		BranchE <= 1'b0;
		EntryFoundE <= 1'b0;
		PredictedPCE <= 32'h00000000;
		PCE <= 32'h00000000;
		PCBranchE <= 32'h00000000;
		PCPlus4E <= 32'h00000000;
		PCSrcE <= 1'b0;
		InstrE <= 32'h00000000;
	end
	else if (enable) begin
		startMultE <= startMultD;
		signedMultE <= signedMultD;
		mfRegE <= mfRegD;
		RegWriteE <= RegWriteD;
		MemtoRegE <= MemtoRegD;
		MemWriteE <= MemWriteD;
		ALUControlE <= ALUControlD;
		ALUSrcE <= ALUSrcD;
		RegDstE <= RegDstD;
		RD1E <= RD1D;
		RD2E <= RD2D;
		RsE <= RsD;
		RtE <= RtD;
		RdE <= RdD;
		SignImmE <= SignImmD;
		BranchE <= BranchD;
		EntryFoundE <= EntryFoundD;
		PredictedPCE <= PredictedPCD;
		PCE <= PCD;
		PCBranchE <= PCBranchD;
		PCPlus4E <= PCPlus4D;
		PCSrcE <= PCSrcD;
		InstrE <= InstrD;
	end
endmodule

module memory_buffer(
		input clk, reset, clr, enable,
		input RegWriteE, MemtoRegE, MemWriteE,
		input [31:0] ALUOutE, WriteDataE,
		input [4:0] WriteRegE,
		output reg RegWriteM, MemtoRegM, MemWriteM,
		output reg [31:0] ALUOutM, WriteDataM,
		output reg [4:0] WriteRegM,
		input [31:0] InstrE, 
		output reg [31:0] InstrM
		);

always @ (posedge clk, posedge reset)
	if (reset) begin
		RegWriteM <= 0;
		MemtoRegM <= 0;
		MemWriteM <= 0;
		ALUOutM <= 32'h00000000;
		WriteDataM <= 32'h00000000;
		WriteRegM <= 4'h0;
		InstrM <= 32'h00000000;
	end
	else if (clr) begin
		RegWriteM <= 0;
		MemtoRegM <= 0;
		MemWriteM <= 0;
		ALUOutM <= 32'h00000000;
		WriteDataM <= 32'h00000000;
		WriteRegM <= 4'h0;
		InstrM <= 32'h00000000;
	end
	else if (enable) begin
		RegWriteM <= RegWriteE;
		MemtoRegM <= MemtoRegE;
		MemWriteM <= MemWriteE;
		ALUOutM <= ALUOutE;
		WriteDataM <= WriteDataE;
		WriteRegM <= WriteRegE;
		InstrM <= InstrE;
	end
endmodule

module writeback_buffer(
		input clk, reset, clr,
		input RegWriteM, MemtoRegM,
		input [31:0] ReadDataM, ALUOutM,
		input [4:0] WriteRegM,
		output reg RegWriteW, MemtoRegW,
		output reg [31:0] ReadDataW, ALUOutW,
		output reg [4:0] WriteRegW
		);

always @ (posedge clk, posedge reset)
	if (reset) begin
		RegWriteW <= 0;
		MemtoRegW <= 0;
		ReadDataW <= 32'h00000000;
		ALUOutW <= 32'h00000000;
		WriteRegW <= 4'h0;
	end
	else if (clr) begin
		RegWriteW <= 0;
		MemtoRegW <= 0;
		ReadDataW <= 32'h00000000;
		ALUOutW <= 32'h00000000;
		WriteRegW <= 4'h0;
	end
	else begin
		RegWriteW <= RegWriteM;
		MemtoRegW <= MemtoRegM;
		ReadDataW <= ReadDataM;
		ALUOutW <= ALUOutM;
		WriteRegW <= WriteRegM;
	end
endmodule
