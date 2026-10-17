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
