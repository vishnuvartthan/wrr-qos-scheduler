# QoS Scheduler RTL

Synthesizable, parameterized SystemVerilog RTL for a 4 requester QoS scheduler with a 32-bit request datapath on a shared memory or interconnect path. The block is framed as an AXI-like front-end scheduler rather than a full protocol implementation: multiple request sources feed per-port FIFOs, arbitration is weighted round robin, and an aging mechanism forces forward progress when low-priority traffic waits too long.

This project was built around the kind of control-heavy block that often sits between request generators and a shared downstream resource such as an interconnect port, memory controller frontend, DMA path, or accelerator ingress queue.


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

The current TCL writes reports to:

* `synth/reports/timing.rpt`
* `synth/reports/area.rpt`
* `synth/reports/power.rpt`
* `synth/reports/qor.rpt`

and outputs to:

* `synth/outputs/scheduler_netlist.v`
* `synth/outputs/scheduler_sdc.sdc`
* `synth/outputs/delays.sdf`



## Architectural scope

The scheduler accepts requests from four independent sources, buffers them per port, and selects one request for a single shared output.

The design centers on a few points:

- **Weighted round robin arbitration** for programmable bandwidth sharing
- **Aging based override** so low-weight traffic cannot starve indefinitely
- **Per-port FIFOs** to preserve ordering within each requester
- **Backpressure-safe output handling** so selected data is held stable until handshake completes
- **CSR programmability** for weights and aging threshold
- **Status counters** for grants, stalls, and aging triggered service events

This is intentionally a scheduler/control block, not a full AXI channel implementation. There is no burst decomposition, ID tracking, or out-of-order response handling in this version.

## Placement in a larger system

The intended context is an AXI-like memory subsystem or shared interconnect path where different traffic classes compete for service. A reasonable example is CPU, DMA, GPU, or accelerator traffic converging on one downstream port.

The problem being addressed is simple: fixed priority is easy to build but can starve low priority requesters under sustained pressure. Pure round robin improves fairness but does not provide bandwidth weighting. This design uses weighted round robin for configurable service bias, then adds aging so long waiting traffic still makes progress.

## Microarchitecture

### RTL partition

- `scheduler_top`  
  Top level integration, external interfaces, and module wiring.

- `scheduler_core`  
  Selection control, aging override handling, output hold logic, and handshake driven pop/serve generation.

- `wrr_arbiter`  
  Weighted round robin grant selection among eligible requesters.

- `age_tracker`  
  Per request wait tracking and starvation eligibility generation.

- `req_fifo`  
  per requester FIFO used to decouple arrivals from arbitration.

- `csr_regs`  
  Weight and threshold configuration plus status/counter readback.

- `status_counters`  
  Grant, stall, and aging triggered service counters.

- `scheduler_pkg`  
  Shared parameters and types.

### Service flow

1. Each requester pushes into its own FIFO.
2. Arbitration operates on FIFO head entries only.
3. Under normal contention, weighted round robin decides service.
4. If a requester waits past the programmed aging threshold, aging can override normal WRR selection.
5. Once a request is presented at the output, it is held stable until downstream `ready` is asserted.
6. FIFO pop happens only on a real output handshake.

That last point matters. It keeps the design safe under downstream stalls and avoids dropping or reordering requests during backpressure.

## Verification

Verification was split between module level bringup and top level behavior checking.

### Unit level testbenches

Unit benches were built for,
- `req_fifo`
- `wrr_arbiter`
- `age_tracker`
- `scheduler_core`
- `csr_regs`
- `status_counters`

### Top level integration testbench

- single port smoke traffic
- backpressure hold behavior
- WRR service under sustained contention
- aging-triggered service for otherwise disadvantaged traffic
- CSR counter readback
- a small random stress run with concurrent traffic and output stalls

The scoreboard checks:
- no loss
- no duplication
- per-port ordering preservation

### Assertions

SVA are bound at the top level and cover the main integration invariants:
- no FIFO pop without output handshake
- at most one pop in a cycle
- serve and pop consistency
- pop source matches `out_src_idx`
- held output remains stable during sustained backpressure
- no unknowns on valid output

## Synthesis and timing

Synthesized with the provided SDC and synthesis script in `scripts/constraints.sdc` and `synth/synth.tcl`. 

The generated reports are under [`synth/reports`](https://github.com/vishnuvartthan/wrr-qos-scheduler/tree/main/synth/reports).

Observed report highlights from the current run,

- **Slack:** +4513.4 ps
- **Datapath delay:** 4477 ps
- **Critical path:** starts in `csr_regs` and ends at `out_data_o`
- **Cell area:** 9431.334
- **Leaf instance count:** 2582
- **Sequential instances:** 842
- **Combinational instances:** 1740

The longest path is consistent with the structure of the design: register output from the CSR/config side, through control heavy arbitration and selection logic, to the scheduled output datapath.

One useful observation from the synthesized netlist is that the path is dominated by control logic depth rather than arithmetic. The path is mostly AOI/OAI/NAND/NOR style boolean logic and muxing, with roughly 25+ logic levels and no large arithmetic blocks. That lines up with the nature of the block: arbitration, selection, and handshake control.


### Current Scope and boundaries
This implementation is scoped as a QoS scheduler RTL block, not a full bus interconnect IP. It covers arbitration, aging-based forward progress, per-port buffering, backpressure-safe output control, and observability through CSRs and counters. It does not include burst-level protocol behavior, ID-based ordering rules, or response-path modeling. Verification is based on directed tests, random stress, and assertions, and the reported timing/area numbers come from synthesis rather than post-layout analysis.


## Repository layout

```text
.
├── rtl
│   ├── age_tracker.sv
│   ├── csr_regs.sv
│   ├── req_fifo.sv
│   ├── scheduler_core.sv
│   ├── scheduler_pkg.sv
│   ├── scheduler_top.sv
│   ├── status_counters.sv
│   └── wrr_arbiter.sv
├── scripts
│   ├── constraints.sdc
│   ├── synth.tcl
│   └── waves.tcl
├── sim
│   ├── files.f
│   ├── Makefile
│   └── out/
├── sva
│   ├── scheduler_bind.sv
│   └── scheduler_sva.sv
├── synth
│   ├── outputs
│   │   ├── delays.sdf
│   │   ├── scheduler_netlist.v
│   │   └── scheduler_sdc.sdc
│   ├── reports
│   │   ├── area.rpt
│   │   ├── power.rpt
│   │   ├── qor.rpt
│   │   └── timing.rpt
└── tb
    ├── top
    │   └── tb_scheduler_top.sv
    └── unit
        ├── tb_age_tracker.sv
        ├── tb_csr_regs.sv
        ├── tb_req_fifo.sv
        ├── tb_scheduler_core.sv
        ├── tb_status_counters.sv
        └── tb_wrr_arbiter.sv




```