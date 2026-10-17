# 16-Port Router - SystemVerilog Testbench

Class-based SystemVerilog testbench for a 16-port router: Packet, Generator, Driver, Receiver (monitor), Scoreboard with source/destination cross coverage, environment, test and top.

## Layout
- `rtl/` - `router.v` (modules `router`, `rtslice`, `rtslicef`)
- `tb/` - `router_io.sv`, `packet.sv`, `router_test.h`, `Generator.sv`, `DriverBase.sv`, `driver.sv`, `ReceiverBase.sv`, `receiver.sv`, `Scoreboard.sv`, `environment.sv`, `router_test_pkg.sv`, `test.sv`, `router_test_top.sv`
- `eda_playground/` - `testbench.sv` is the whole testbench merged into one file; `design.sv` is `router.v` ready to paste

## Run on EDA Playground
Link: https://edaplayground.com/x/nynD

Simulator: Synopsys VCS (or any SV-class capable one). Top module: `router_test_top`.

## Results
<img width="1655" height="847" alt="image" src="https://github.com/user-attachments/assets/4d7d84ca-a8e3-4e05-9bdf-8977df0bb7db" />
<img width="1886" height="646" alt="image" src="https://github.com/user-attachments/assets/efaa4271-7ead-4fdd-ad80-50ab40acf8a0" />
