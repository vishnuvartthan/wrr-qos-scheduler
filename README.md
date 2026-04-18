# QoS Scheduler RTL for Shared Resource Arbitration

Synthesizable, parameterized SystemVerilog RTL for a 4 requester QoS scheduler with a 32-bit request datapath on a shared memory or interconnect path. The block is framed as an AXI-like front-end scheduler rather than a full protocol implementation: multiple request sources feed per-requester FIFOs, arbitration is weighted round robin, and an aging mechanism forces forward progress when low-priority traffic waits too long.


## Running the project

### Simulation

```bash
cd sim
```
From the `sim/` directory:

```bash
make help
make tb_scheduler_top
make unit
make regress
make clean
```

- `make tb_scheduler_top` runs the full integration testbench
- `make unit` runs all unit testbenches.
- `make regress` runs both unit benches and the top testbench.

### Synthesis

The synthesis script is set up for a standard Genus flow, but the library and search path entries are environment-specific. Before running it, update `scripts/synth.tcl` with the paths used on your machine.

synth.tcl
```bash
set_db init_lib_search_path <USER_LIB_PATH>     # replace with your standard-cell library directory
set_db init_hdl_search_path <USER_HDL_PATH>     # replace with your RTL/source directory
read_libs <USER_STD_CELL_LIB>                   # replace with your technology library file

...
```
 
The rest of the flow and report generation can stay the same. 

A typical Genus run:

```bash
cd synth
genus -f ../scripts/synth.tcl
```


## Architectural scope

The scheduler accepts requests from four independent sources, buffers them per port, and selects one request for a single shared output.

The design centers on a few points:

- **Weighted round robin arbitration** for programmable bandwidth sharing
- **Aging based override** so low-weight traffic cannot starve indefinitely
- **Per-port FIFOs** to preserve ordering within each requester
- **Backpressure-safe output handling** so selected data is held stable until handshake completes
- **CSR programmability** for weights and aging threshold
- **Status counters** for grants, stalls, and aging triggered service events


### Service flow

1. Each requester pushes into its own FIFO.
2. Arbitration operates on FIFO head entries only.
3. Under normal contention, weighted round robin decides service.
4. If a requester waits past the programmed aging threshold, aging can override normal WRR selection.
5. Once a request is presented at the output, it is held stable until downstream `ready` is asserted.
6. FIFO pop happens only on a real output handshake.


## Verification

Verification was split between module level bringup and top level behavior checking.

### Top level integration testbench

- single port smoke traffic
- backpressure hold behavior
- WRR service under sustained contention
- aging-triggered service for otherwise disadvantaged traffic
- CSR counter readback
- a small random stress run with concurrent traffic and output stalls

### Assertions

SVA are bound at the top level and cover the main integration invariants:
- no FIFO pop without output handshake
- at most one pop in a cycle
- serve and pop consistency
- pop source matches `out_src_idx`
- held output remains stable during sustained backpressure
- no unknowns on valid output

The generated reports are under [`synth/reports`](https://github.com/vishnuvartthan/wrr-qos-scheduler/tree/main/synth/reports).

