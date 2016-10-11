module mainDecoder(	input [5:0] op, 
			output reg memtoreg,
			output reg memwrite,
			output reg branch,
			output reg alusrc,
			output reg regdst,
			output reg regwrite,
			output reg jump,
			output reg [3:0] aluop,
			output reg branchNE);
		
// Main decoder

reg [11:0] controls;
//assign {regwrite, regdst, alusrc, branch, memwrite, memtoreg, jump, aluop} = controls;

always @ (*) begin
	case(op)
		6'b000000: controls <= 12'b011000000010; // R-type
		6'b100011: controls <= 12'b010100100000; // lw
		6'b101011: controls <= 12'b000101000000; // sw
		6'b000100: controls <= 12'b000010000001; // beq
		6'b001000: controls <= 12'b010100000000; // addi
		6'b000010: controls <= 12'b000000010000; // j
		//new
		6'b000101: controls <= 12'b100010000100; // bne
		6'b001001: controls <= 12'b010100000000; // addiu
		6'b001100: controls <= 12'b010100000101; // andi
		6'b001101: controls <= 12'b010100000110; // ori
		6'b001110: controls <= 12'b010100000111; // xori
		6'b001010: controls <= 12'b010100000011; // slti
		6'b001011: controls <= 12'b010100000011; // sltiu
		6'b001111: controls <= 12'b010100001000; // lui
		default:   controls <= 12'bxxxxxxxxxxxx; // invalid opcode
	endcase
	branchNE = controls[11];
	regwrite = controls[10];	
	regdst = controls[9];
	alusrc = controls[8];
	branch = controls[7];
	memwrite = controls[6];
	memtoreg = controls[5];
	jump = controls[4];
	aluop = controls[3:0];
end
endmodule

module aluDecoder(	input [5:0] funct,
			input [3:0] aluop,
			output reg [3:0] alucontrol,
			output reg startMult, signedMult, 
			output reg [1:0] mfReg);
//ALUop 		

reg [7:0] controls;
			
always @ (*) begin
	case (aluop)
		4'b0000: controls <= 8'b00100000; // add for lw, sw, addi
		4'b0001: controls <= 8'b01100000; // sub for beq
		4'b0011: controls <= 8'b01110000; // slt for slti
		4'b0100: controls <= 8'b11110000; // set not equal for bne
		4'b0101: controls <= 8'b00000000; // and for andi
		4'b0110: controls <= 8'b00010000; // or for ori
		4'b0111: controls <= 8'b10000000; // xor for xori
		4'b1000: controls <= 8'b11100000; // a[31:16] = b[15:0] for lui
		
		//3'b010
		default: case (funct)	     // R-type functions
			6'b100000: controls <= 8'b00100000; // add
			6'b100001: controls <= 8'b00100000; // addu
			6'b100010: controls <= 8'b01100000; // sub
			6'b100011: controls <= 8'b01100000; // subu
			6'b100100: controls <= 8'b00000000; // and
			6'b100101: controls <= 8'b00010000; // or
			6'b100110: controls <= 8'b10000000; // xor
			6'b100111: controls <= 8'b10010000; // xnor(using NOR's funct code)
			6'b101010: controls <= 8'b01110000; // slt
			6'b101011: controls <= 8'b01110000; // sltu
			6'b010000: controls <= 8'b00000010; // mfhi
			6'b010010: controls <= 8'b00000001; // mflo
			6'b011000: controls <= 8'b00001100; // mult
			6'b011001: controls <= 8'b00001000; // multu
			default: controls <= 8'b00000000; // invalid data in funct field
			endcase
	endcase
	alucontrol = controls[7:4];
	startMult = controls[3];
	signedMult = controls[2];
	mfReg = controls[1:0];

end
endmodule
