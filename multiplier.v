//multiplication module

module multiplier(input [31:0] a,
		  input [31:0] b,
		  input start,
		  input is_signed,
		  input clk, reset,
		  output reg [63:0] s,
		  output ready);
	reg lsb;
	reg [5:0] bit; 
	reg [31:0] abs_a, abs_b;
	assign ready = !bit;

	always @( posedge clk ) begin
		if (reset) begin
			bit = 6'd0;
		end 
		else begin
     			if( ready && start ) begin
				//abs a is the absolute  value 
				abs_a = is_signed ? (a[31] ? -a : a) : a;
				abs_b = is_signed ? (b[31] ? -b : b) : b;
				bit = 32;
        			s = { 32'd0, abs_a };
     			end 
			else if( bit ) begin
				lsb = s[0];
       				s = s >> 1;
        			bit = bit - 1;
				//if lsb was 1 then we add multplicand
        			if(lsb)
					s[63:31] = s[62:31] + abs_b;
				
				//done, set the sign of the output for signed operations
				if(!bit && a[31] ^ b[31] )
					s = -s;
			end
     		end
	end
endmodule
