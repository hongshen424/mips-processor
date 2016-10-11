module alu (input [31:0] In1, In2, input [3:0] Func, output reg [31:0] ALUout);
  wire [31:0] BB ;
  wire [31:0] S ;
  wire   cout ;
  
  assign BB = (Func[2]) ? ~In2 : In2 ;
  assign {cout, S} = Func[2] + In1 + BB ;
  always @ * begin
   case (Func[3:0]) 
    4'b0000 : ALUout <= In1 & BB; //and
    4'b0001 : ALUout <= In1 | BB; //or
    4'b0010 : ALUout <= S; //add
    4'b0011 : ALUout <= 0;
    4'b0100 : ALUout <= 0;
    4'b0101 : ALUout <= 0;
    4'b0110 : ALUout <= S; //subtract
    4'b0111 : ALUout <= {31'd0, S[31]}; //slt
    4'b1000 : ALUout <= In1 ^ In2; //xor
    4'b1001 : ALUout <= In1 ~^ In2; //xnor
    4'b1010 : ALUout <= 0;
    4'b1011 : ALUout <= 0;
    4'b1100 : ALUout <= 0;
    4'b1101 : ALUout <= 0;
    4'b1110 : ALUout <= {In2[15:0], In1[15:0]}; //lui
    4'b1111 : ALUout <= 0; 
   endcase
  end 
   
 endmodule
