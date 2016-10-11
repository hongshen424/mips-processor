module testbench();
reg clk, reset;
wire [31:0] instr;
mips uut(clk, reset);


initial begin
	reset <= 1; //reset PC
	#12; reset <= 0;
end

always@(posedge clk) begin
	if(instr == 32'hxxxxxxxx)
		$stop;
end

always begin
clk <= 1; #5; clk <=0; #5;
end

endmodule
