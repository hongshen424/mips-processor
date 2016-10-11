module ALU_tb();
reg [31:0] In1, In2;
reg [3:0] Func;
wire [31:0] ALUout;
alu uut(In1, In2, Func, ALUout);

initial begin
	//test all Funcs
	Func = 0;
	repeat(15) begin
		In1 = $random;
		In2 = $random;
		#10;
		Func = Func+1;
		
	end
	#10;
	$stop;
end



endmodule
