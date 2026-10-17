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
