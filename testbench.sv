interface router_io(input clock);
        logic reset_n;
        logic [15:0] din;
        logic [15:0] frame_n;
        logic [15:0] valid_n;
        logic [15:0] busy_n;
        logic [15:0] dout;
        logic [15:0] frameo_n;
        logic [15:0] valido_n;

        clocking cb @(posedge clock);
                output reset_n;
                output din;
                output frame_n;
                output valid_n;
                input busy_n;
                input dout;
                input frameo_n;
                input valido_n;
        endclocking: cb
        modport tb (clocking cb,output reset_n);
endinterface: router_io

package router_test_pkg;
        int run_for_n_packets=0;
        int TRACE_ON=0;
`ifndef INC_PACKET_SV
`define INC_PACKET_SV
class Packet;
        rand bit[3:0] sa,da;
        rand logic [7:0] payload[$];
        string name;
        constraint limit{
                sa inside {[0:15]};
                da inside{[0:15]};
                payload.size() inside{[2:4]};
        }

        extern function new(string name ="Packet");
        extern function bit compare(Packet pkt2cmp,ref string message);
        extern function void display(string prefix ="Note");

endclass : Packet

function Packet::new(string name);
        this.name=name;
endfunction:new

function bit Packet::compare(Packet pkt2cmp,ref string message);
        if(payload.size() != pkt2cmp.payload.size()) begin
                message = "payload size mismatch :\n";
                message = {message,$sformatf("payload.size() = %0d, pkt2cmp_payload.size() = %0d\n",payload.size(),pkt2cmp.payload.size())};
                return(0);
        end
        if(payload != pkt2cmp.payload) begin
                message = "payload content mismatch :\n";
                message = {message,$sformatf("packet sent: %p\nPkt received: %p",payload,pkt2cmp.payload)};
                return(0);
        end
        message = "Successfully compared";
        return(1);
endfunction:compare

function void Packet::display(string prefix);
        $display("[%s]%T %s sa=%0d,da=%0d",prefix,$realtime,name,sa,da);
        foreach(payload[i])
                $display("[%s]%T %s payload[%0d] = %0d",prefix,$realtime,name,i,payload[i]);
endfunction :display

`endif
`ifndef INC_ROUTER_TEST_H
`define INC_ROUTER_TEST_H
typedef mailbox #(Packet) pkt_mbox;
`endif
`ifndef INC_DRIVER_SV
`define INC_DRIVER_SV
`ifndef INC_DRIVERBASE_SV
`define INC_DRIVERBASE_SV
class DriverBase;
  virtual router_io.tb rtr_io;  // interface signal
  string    name;               // unique identifier
  bit[3:0]  sa, da;             // source and destination addresses
  logic[7:0]  payload[$];       // Packet payload
  Packet    pkt2send;           // stimulus Packet object

  extern function new(string name = "DriverBase", virtual router_io.tb rtr_io);
  extern virtual task send();
  extern virtual task send_addrs();
  extern virtual task send_pad();
  extern virtual task send_payload();
endclass

function DriverBase::new(string name, virtual router_io.tb rtr_io);
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, name);
  this.name   = name;
  this.rtr_io = rtr_io;
endfunction

task DriverBase::send();
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, this.name);
  this.send_addrs();
  this.send_pad();
  this.send_payload();
endtask

task DriverBase::send_addrs();
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, this.name);
  this.rtr_io.cb.frame_n[this.sa] <= 1'b0;
  for(int i=0; i<4; i++) begin
    this.rtr_io.cb.din[this.sa] <= this.da[i];
    @(this.rtr_io.cb);
  end
endtask

task DriverBase::send_pad();
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, this.name);
  this.rtr_io.cb.din[this.sa] <= 1'b1;
  this.rtr_io.cb.valid_n[this.sa] <= 1'b1;
  repeat(5) @(this.rtr_io.cb);
endtask

task DriverBase::send_payload();
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, this.name);
  foreach(this.payload[index]) begin
    for(int i=0; i<8; i++) begin
      this.rtr_io.cb.din[this.sa] <= this.payload[index][i];
      this.rtr_io.cb.valid_n[this.sa] <= 1'b0;
      this.rtr_io.cb.frame_n[this.sa] <= ((index == (this.payload.size() - 1)) && (i == 7));
      @(this.rtr_io.cb);
    end
  end
  this.rtr_io.cb.valid_n[this.sa] <= 1'b1;
endtask
`endif
class Driver extends DriverBase;
        pkt_mbox in_box;
        pkt_mbox out_box;
        semaphore sem[];

        extern function new(string name = "Driver",int port_id,semaphore sem[], pkt_mbox in_box,out_box,virtual router_io.tb rtr_io);
        extern virtual task start();
endclass

function Driver::new(string name,int port_id,semaphore sem[], pkt_mbox in_box,out_box,virtual router_io.tb rtr_io);
        super.new(name,rtr_io);
        if(TRACE_ON) $display("[TRACE]%t %s:%m",$realtime,name);
        this.sa=port_id;
        this.sem=sem;
        this.in_box=in_box;
        this.out_box=out_box;
endfunction

task Driver::start();
        if(TRACE_ON) $display("[TRACE]%t %s:%m",$realtime,this.name);
        fork
                forever begin
                        this.in_box.get(this.pkt2send);
                        if(this.pkt2send.sa !=this.sa) continue;
                        this.da=this.pkt2send.da;
                        this.payload=this.pkt2send.payload;
                        this.sem[this.da].get(1);
                        this.send();
                        this.out_box.put(this.pkt2send);
                        this.sem[this.da].put(1);
                end
        join_none
endtask
`endif
`ifndef INC_RECEIVER_SV
`define INC_RECEIVER_SV
`ifndef INC_RECEIVERBASE_SV
`define INC_RECEIVERBASE_SV
class ReceiverBase;
  virtual router_io.tb rtr_io;  // interface signals
  string   name;                // unique identifier
  bit[3:0] da;                  // output port to monitor
  logic[7:0] pkt2cmp_payload[$];        // actual payload array
  Packet   pkt2cmp;             // actual Packet object

  extern function new(string name = "ReceiverBase", virtual router_io.tb rtr_io);
  extern virtual task recv();
  extern virtual task get_payload();
endclass

function ReceiverBase::new(string name, virtual router_io.tb rtr_io);
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, name);
  this.name = name;
  this.rtr_io = rtr_io;
  this.pkt2cmp = new();
endfunction

task ReceiverBase::recv();
  static int pkt_cnt = 0;
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, this.name);
  this.get_payload();
  this.pkt2cmp.da = da;
  this.pkt2cmp.payload = this.pkt2cmp_payload;
  this.pkt2cmp.name = $psprintf("rcvdPkt[%0d]", pkt_cnt++);
endtask

task ReceiverBase::get_payload();
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, this.name);
  this.pkt2cmp_payload.delete();
  fork
    begin: wd_timer_fork
    fork: frameo_wd_timer
      @(negedge this.rtr_io.cb.frameo_n[da]);
      begin
        repeat(1000) @(rtr_io.cb);
        $display("\n%m\n[ERROR]%t Frame signal timed out!\n", $realtime);
        $finish;
      end
    join_any: frameo_wd_timer
    disable fork;
    end: wd_timer_fork
  join
  forever begin
    logic[7:0] datum;
    for (int i=0; i<8; ) begin
      if (!this.rtr_io.cb.valido_n[da])
        datum[i++] = this.rtr_io.cb.dout[da];
      if (this.rtr_io.cb.frameo_n[da])
        if (i == 8) begin
          this.pkt2cmp_payload.push_back(datum);
          return;
        end
        else begin
          $display("\n%m\n[ERROR]%t Packet payload not byte aligned!\n", $realtime);
          $finish;
        end
      @(this.rtr_io.cb);
    end
    this.pkt2cmp_payload.push_back(datum);
  end
endtask
`endif
class Receiver extends ReceiverBase;
        pkt_mbox out_box;

        extern function new(string name="Receiver",int port_id,pkt_mbox out_box,virtual router_io.tb rtr_io);
        extern virtual task start();
endclass

function Receiver::new(string name,int port_id,pkt_mbox out_box,virtual router_io.tb rtr_io);
        super.new(name,rtr_io);
        if(TRACE_ON) $display("[TRACE]%t %s:%m", $realtime,name);
        this.da=port_id;
        this.out_box=out_box;
endfunction

task Receiver::start();
        if(TRACE_ON) $display("[TRACE]%t %s:%m",$realtime,name);
        fork
                forever begin
                        this.recv();
                        begin
                                Packet pkt = new this.pkt2cmp;
                                this.out_box.put(pkt);
                        end
                end
        join_none
endtask
`endif
`ifndef INC_GENERATOR_SV
`define INC_GENERATOR_SV
class Generator;
        string name;
        Packet pkt2send;
        pkt_mbox out_box[];

        extern function new(string name="Generator");
        extern virtual task gen();
        extern virtual task start();
endclass

function Generator::new(string name);
        if(TRACE_ON) $display("[TRACE]%t %s:%m",$realtime,name);
        this.name=name;
        this.pkt2send=new();
        this.out_box= new[16];
        foreach(this.out_box[i])
                this.out_box[i]=new();
endfunction

task Generator::gen();
        static int pkts_generated =0 ;
        if(TRACE_ON) $display("[TRACE]%t %s:%m",$realtime,this.name);
        this.pkt2send.name = $sformatf("Packet[%0d]",pkts_generated++);
        if(!this.pkt2send.randomize()) begin
                $display("\n%m\n[ERROR]%t Randomization failed!\n",$realtime);
                $finish;
        end
endtask

task Generator::start();
        if(TRACE_ON) $display("[TRACE]%t %s:%m",$realtime,this.name);
        fork
                for(int i=0;i<run_for_n_packets || run_for_n_packets <=0;i++)
                begin
                        this.gen();
                        begin
                                Packet pkt =new this.pkt2send;
                                this.out_box[pkt.sa].put(pkt);
                        end
                end
        join_none
endtask
`endif
`ifndef INC_SCOREBOARD_SV
`define INC_SCOREBOARD_SV
class Scoreboard;
        string name;
        event DONE;
        Packet refPkt[$];
        Packet pkt2send;
        Packet pkt2cmp;
        pkt_mbox driver_mbox;
        pkt_mbox receiver_mbox;
        bit [3:0] sa,da;

        covergroup router_cov;
                coverpoint sa { type_option.weight =0;}
                coverpoint da { type_option.weight =0;}
                cross sa,da;
        endgroup

        extern function new(string name="Scoreboard",pkt_mbox driver_mbox=null,receiver_mbox=null);
        extern virtual task start();
        extern virtual task check();
endclass

function Scoreboard::new(string name,pkt_mbox driver_mbox,receiver_mbox);
        if(TRACE_ON) $display("[TRACE]%t %s:%m",$realtime,name);
        this.name=name;
        if(driver_mbox ==null) driver_mbox=new();
        this.driver_mbox = driver_mbox;
        if(receiver_mbox == null) receiver_mbox=new();
        this.receiver_mbox=receiver_mbox;
        router_cov=new();
endfunction

task Scoreboard::start();
        if(TRACE_ON) $display("[TRACE]%t %s:%m",$realtime,name);
        fork
                forever begin
                        receiver_mbox.get(pkt2cmp);
                        while(driver_mbox.num()) begin
                                Packet pkt;
                                driver_mbox.get(pkt);
                                refPkt.push_back(pkt);
                        end
                        check();
                end
        join_none
endtask

task Scoreboard::check();
        int index[$];
        string message;
        static int pkts_checked=0;
        real coverage_result;
        if(TRACE_ON) $display("[TRACE]%t %s:%m",$realtime,name);
        index=refPkt.find_first_index() with (item.da ==this.pkt2cmp.da);
        if(index.size() <=0) begin
                $display("\n%m\n[ERROR]%t %s not found in Refernce Queue\n",$realtime,this.pkt2cmp.name);
                pkt2cmp.display("ERROR");
                $finish;
        end
        pkt2send=refPkt[index[0]];
        refPkt.delete(index[0]);
        if(!pkt2send.compare(pkt2cmp,message)) begin
                $display("\n%m\n[ERROR]%t Packet #%0d %s\n",$realtime,pkts_checked,message);
                pkt2send.display("ERROR");
                pkt2cmp.display("ERROR");
                $finish;
        end
        this.sa=pkt2send.sa;
        this.da=pkt2send.da;
        router_cov.sample();
        coverage_result = $get_coverage();
        $display("[NOTE]%0t Packet #%0d %s coverage = %3.2f",$time,pkts_checked++,message,coverage_result);
        if((pkts_checked>=run_for_n_packets) || (coverage_result == 100))
                ->DONE;
endtask
`endif
class environment;
        string  name;
        rand int run_for_n_packets;
        virtual router_io.tb rtr_io;

        semaphore sem[];
        Driver drvr[];
        Receiver rcvr[];
        Generator gen;
        Scoreboard sb;
        constraint valid{this.run_for_n_packets inside{[1500:2500]};}

        extern function new(string name="Env",virtual router_io.tb rtr_io);
        extern virtual task run();
        extern virtual function void configure();
        extern virtual function void build();
        extern virtual task start();
        extern virtual task wait_for_end();
        extern virtual task reset();
endclass

function environment::new(string name="Env", virtual router_io.tb rtr_io);
        if(TRACE_ON) $display("[TRACE]%t %s:%m",$realtime,name);
        this.name=name;
        this.rtr_io=rtr_io;
endfunction

task environment::run();
        if(TRACE_ON) $display("[TRACE]%t %s:%m",$realtime,this.name);
        this.build();
        this.reset();
        this.start();
        this.wait_for_end();
endtask

function void environment::configure();
        if(TRACE_ON) $display("[TRACE]%t %s:%m",$realtime,this.name);
        this.randomize();
endfunction

function void environment::build();
        if(TRACE_ON) $display("[TRACE]%t %s:%m",$realtime,this.name);
        if(this.run_for_n_packets ==0) this.run_for_n_packets=2000;
        this.sem=new[16];
        this.drvr=new[16];
        this.rcvr=new[16];
        this.gen=new();
        this.sb=new();
        foreach(sem[i])
                this.sem[i]=new(1);
        for(int i=0;i<drvr.size();i++)
                this.drvr[i]=new($sformatf("drvr[%0d]",i),i,this.sem,this.gen.out_box[i],this.sb.driver_mbox,this.rtr_io);
        for(int i=0;i<rcvr.size();i++)
                this.rcvr[i]=new($sformatf("rcvr[%0d]",i),i,this.sb.receiver_mbox,this.rtr_io);
endfunction

task environment::reset();
        if(TRACE_ON) $display("[TRACE]%t %s: %m",$realtime,this.name);
        this.rtr_io.reset_n=1'b0;
        this.rtr_io.cb.frame_n<='1;
        this.rtr_io.cb.valid_n<='1;
        ##2 this.rtr_io.cb.reset_n<=1'b1;
        repeat(15) @(this.rtr_io.cb);
endtask

task environment::start();
        if(TRACE_ON) $display("[TRACE]%t %s: %m",$realtime,this.name);
        this.gen.start();
        this.sb.start();
        foreach(this.drvr[i])
                this.drvr[i].start();
        foreach(this.rcvr[i])
                this.rcvr[i].start();
endtask

task environment::wait_for_end();
        if(TRACE_ON) $display("[TRACE]%t %s: %m",$realtime,this.name);
        wait(this.sb.DONE.triggered);
endtask
endpackage

program automatic test(router_io.tb rtr_io);
        import router_test_pkg::*;
        environment env;
        initial begin
                env =new("env",rtr_io);
                env.configure();
                run_for_n_packets=env.run_for_n_packets;
                env.run();
        end
endprogram: test

//`timescale 1ns/100ps
module router_test_top;
parameter simulation_cycle=100;
bit SystemClock;
router_io top_io(SystemClock);
test t(top_io);
router dut(
        .reset_n(top_io.reset_n),
        .clock(top_io.clock),
        .din(top_io.din),
        .frame_n(top_io.frame_n),
        .valid_n(top_io.valid_n),
        .dout(top_io.dout),
        .valido_n(top_io.valido_n),
        .busy_n(top_io.busy_n),
        .frameo_n(top_io.frameo_n)
);
initial begin
        SystemClock=0;
        forever begin
                #(simulation_cycle/2)
                SystemClock=~SystemClock;
        end
end
endmodule
