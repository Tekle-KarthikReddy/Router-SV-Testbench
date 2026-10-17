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
