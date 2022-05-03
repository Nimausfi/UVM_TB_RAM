module ram(
  input clk,wr,
  input [7:0] din,
  output reg [7:0] dout,
  input [3:0] addr
  			);
     
  reg [7:0] mem [15:0];
  integer i = 0;
     
  initial begin
  for(i = 0; i < 16; i = i + 1) begin
  mem[i] = 0;
  end
     
  end
     
always@(posedge clk)
  begin
  if(wr == 1'b1)
  mem[addr] <= din;
  else
  dout <= mem[addr];
  end
endmodule