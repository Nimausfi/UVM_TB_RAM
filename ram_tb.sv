 
`include "uvm_macros.svh"
import uvm_pkg::*;
 
class transaction extends uvm_sequence_item;
	rand bit wr;
	rand bit [7:0] din;
	rand bit [3:0] addr;
	bit [7:0] dout;
 
  constraint addr_C {addr > 2; addr < 8;};
 
function new(input string inst = "TRANS");
super.new(inst);
endfunction
 
`uvm_object_utils_begin(transaction)
`uvm_field_int(wr,UVM_DEFAULT)
`uvm_field_int(din,UVM_DEFAULT)
`uvm_field_int(addr,UVM_DEFAULT)
`uvm_field_int(dout,UVM_DEFAULT)
`uvm_object_utils_end
 
endclass
///////////////////////////GENERATOR 
class generator extends uvm_sequence#(transaction);
`uvm_object_utils(generator)
 
	transaction t;
	integer i;
 
function new(input string inst = "GEN");
super.new(inst);
endfunction
 
virtual task body();
t = transaction::type_id::create("TRANS");
  for(i =0; i< 50; i++) begin
start_item(t);
t.randomize();
`uvm_info("GEN", "Data send to Driver", UVM_NONE);
t.print(uvm_default_line_printer);
finish_item(t);
#20;
end
endtask
endclass
///////////////////////////DRIVER
class driver extends uvm_driver#(transaction);
`uvm_component_utils(driver)
 
	transaction t;
	virtual ram_if rif;
 
function new(input string inst = "DRV", uvm_component c);
super.new(inst,c);
endfunction
 
virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
t = transaction::type_id::create("TRANS");
if(!uvm_config_db#(virtual ram_if)::get(this,"","rif",rif))
`uvm_info("DRV", "Unable to access Interface", UVM_NONE);
endfunction
 
virtual task run_phase(uvm_phase phase);
forever begin
seq_item_port.get_next_item(t);
rif.wr = t.wr;
rif.din = t.din;
rif.addr = t.addr;
`uvm_info("DRV","Send data to DUT", UVM_NONE);
t.print(uvm_default_line_printer);
seq_item_port.item_done();
@(posedge rif.clk);
 
if(t.wr == 1'b0)
  @(posedge rif.clk);
  
end
endtask
 
endclass
///////////////////////////MONITOR
class monitor extends uvm_monitor;
`uvm_component_utils(monitor)
 
	uvm_analysis_port #(transaction) send;
	virtual ram_if rif;
	transaction t;
 
function new(input string inst = "MON", uvm_component c);
super.new(inst,c);
send = new("WRITE",this);
endfunction
 
virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
t = transaction::type_id::create("TRANS");
if(!uvm_config_db#(virtual ram_if)::get(this,"","rif",rif))
`uvm_info("MON", "Unable to access Interface", UVM_NONE);
endfunction
 
virtual task run_phase(uvm_phase phase);
forever begin
@(posedge rif.clk);  
t.wr = rif.wr;
t.din = rif.din;
t.addr = rif.addr;
//t.dout = rif.dout;
 
if(rif.wr == 1'b0) begin
    @(posedge rif.clk)
    t.dout = rif.dout;
end 
    
  
`uvm_info("MON","Send data to Scoreboard", UVM_NONE);
t.print(uvm_default_line_printer);
send.write(t);
 
end
endtask
 
endclass
///////////////////////////SCOREBOARD
class scoreboard extends uvm_scoreboard;
`uvm_component_utils(scoreboard)
 
	uvm_analysis_imp #(transaction,scoreboard) recv;
	//transaction data;
 
  reg [7:0] tarr[20] = '{default:0} ;
 
function new(input string inst = "SCO", uvm_component c);
super.new(inst,c);
recv = new("READ",this);
endfunction
 
//virtual function void build_phase(uvm_phase phase);
//super.build_phase(phase);
////data = transaction::type_id::create("TRANS");
//endfunction
 
virtual function void write(transaction data);
`uvm_info("SCO","Data rcvd from Monitor", UVM_NONE);
data.print(uvm_default_line_printer);                        
  
  if(data.wr == 1'b1)
    begin
      tarr[data.addr] = data.din;
      `uvm_info("SCO", $sformatf("Data Write oper din : %0h and tarr[addr] : %0h", data.din,tarr[data.addr]), UVM_NONE);    
    end 
 
  if(data.wr == 1'b0)
    begin
  
      if(data.dout == tarr[data.addr])
        `uvm_info("SCO", "Test Passed", UVM_NONE)
      else
        `uvm_error("SCO", "TEST Failed")
      
            `uvm_info("SCO", $sformatf("DATA read oper dout :%0h and tarr[addr] : %0h", data.dout, tarr[data.addr]), UVM_NONE);  
    end
  
  
endfunction
  
  
endclass
///////////////////////////AGENT
class agent extends uvm_agent;
`uvm_component_utils(agent)
 
function new(input string inst = "AGENT", uvm_component c);
super.new(inst,c);
endfunction
 
	monitor m;
	driver d;
	uvm_sequencer #(transaction) seq;
 
 
virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
m = monitor::type_id::create("MON",this);
d = driver::type_id::create("DRV",this);
seq = uvm_sequencer #(transaction)::type_id::create("SEQ",this);
endfunction
 
virtual function void connect_phase(uvm_phase phase);
super.connect_phase(phase);
d.seq_item_port.connect(seq.seq_item_export);
endfunction

endclass
///////////////////////////ENVIRONMENT
class env extends uvm_env;
`uvm_component_utils(env)
 
function new(input string inst = "ENV", uvm_component c);
super.new(inst,c);
endfunction
 
	scoreboard s;
	agent a;
 
virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
a = agent::type_id::create("AGENT",this);
s = scoreboard::type_id::create("SCO",this);
endfunction
 
 
virtual function void connect_phase(uvm_phase phase);
super.connect_phase(phase);
a.m.send.connect(s.recv);
endfunction

endclass
///////////////////////////TEST
class test extends uvm_test;
`uvm_component_utils(test)
 
function new(input string inst = "TEST", uvm_component c);
super.new(inst,c);
endfunction
 
	generator gen;
	env e;
 
virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
e = env::type_id::create("ENV",this);
gen = generator::type_id::create("GEN",this);
endfunction
 
virtual task run_phase(uvm_phase phase);
phase.raise_objection(this);
gen.start(e.a.seq);
phase.drop_objection(this);
endtask
endclass
 
module ram_tb;
test t;
ram_if rif();
 
ram dut (.clk(rif.clk), .wr(rif.wr), .din(rif.din), .dout(rif.dout), .addr(rif.addr));
 
initial begin
rif.clk = 0;
end
 
always#10 rif.clk = ~rif.clk;
 
initial begin
t = new("TEST", null);
uvm_config_db #(virtual ram_if)::set(null, "*", "rif", rif);
run_test();
end
 
endmodule