# QoS Scheduler RTL

SystemVerilog RTL project for a 4-requester QoS scheduler implementing weighted round robin arbitration with aging-based starvation prevention.

## Features
- 4 independent requester inputs
- Per-requester FIFO buffering
- Weighted round robin arbitration
- Aging-based anti-starvation override
- Backpressure-safe output handshake
- CSR-programmable weights and aging threshold
- Status counters for grants, stalls, and starvation-prevention events

## RTL Modules
- `scheduler_top`
- `scheduler_core`
- `wrr_arbiter`
- `age_tracker`
- `req_fifo`
- `csr_regs`
- `status_counters`

## Verification
- Unit testbenches for key RTL modules
- Top-level integration testbench
- SystemVerilog assertions in `sva/scheduler_sva.sv`

## Directory Structure
- `rtl/` : synthesizable RTL
- `tb/` : testbenches
- `sva/` : assertions
- `sim/` : run scripts and filelists
- `docs/` : spec and diagrams

## Build / Sim
Example with Xcelium:
```bash
make -C sim test_top
