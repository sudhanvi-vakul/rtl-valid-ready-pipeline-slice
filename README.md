# Flow-Controlled Pipeline Register Slice with Valid/Ready Handshake and Backpressure Support

A standalone RTL project that implements and verifies a reusable valid/ready pipeline register slice for synchronous datapath flow control.

---

## Project Summary

This project builds a **valid/ready pipeline register slice** in SystemVerilog. The block sits between an upstream producer and a downstream consumer and governs when data is accepted, held, and released.

Although the RTL is compact, the behavior it implements is foundational in real hardware systems:
- throughput-friendly movement of work through a pipeline
- safe hold behavior during downstream stalls
- clean bubble propagation through an elastic stage
- reusable handshake logic for larger datapaths, fabrics, and interfaces
- optional skid buffering for one-cycle backpressure absorption

This repository is **self-contained**. All RTL, testbench code, scripts, documentation, and verification artifacts needed for this project live inside this repo.

---

## Project Goal

Build and verify a reusable register slice with:
- standard `valid/ready` handshake semantics
- correct accept/hold/release behavior
- stable payload during stall
- bubble insertion and removal behavior
- no data loss, no duplication, and no ghost transfers
- optional skid-buffer support for enhanced backpressure handling
- reproducible simulation and artifact capture

---

## Why This Project Matters

A large amount of digital design work is not only arithmetic or control logic. A major part of microarchitecture is **how work moves**.

This project demonstrates the core movement rules behind:
- CPU pipelines
- streaming datapaths
- NoC and router channels
- MMIO and bus response paths
- DMA fronts and backs
- accelerator feeding pipelines
- decoupled interfaces used in larger SoC blocks

If a register slice is wrong, later systems can show:
- dropped transfers
- duplicated transfers
- unstable output payloads under stall
- corrupted ordering
- dead cycles and throughput collapse
- difficult-to-debug pipeline lockups

That makes this a small project in code size, but a very important one in architectural value.

---

## What Is Implemented

Recommended files for this project:

- `rtl/vr_slice.sv`  
  Main valid/ready register slice RTL

- `rtl/vr_slice_pkg.sv` *(optional)*  
  Common parameters, typedefs, helper constants

- `tb/vr_slice_integrated_tb.sv`  
  Self-checking integrated testbench for directed and stress scenarios

- `tests.yaml`  
  Test registration for smoke and regression-style runs

- `scripts/run.py`  
  Main reproducible execution entry point

- `docs/design_notes.md`  
  Design intent, interface reasoning, and microarchitecture notes

- `docs/verification_notes.md`  
  Advanced verification plan and closure checklist

- `docs/commands.md`  
  Runbook for setup, simulation, debug, and artifact handling

---

## Recommended Repo Structure

```text
rtl-valid-ready-pipeline-slice/
├── README.md
├── requirements.txt
├── tests.yaml
├── rtl/
│   ├── vr_slice.sv
│   └── vr_slice_pkg.sv                # optional
├── tb/
│   └── vr_slice_integrated_tb.sv
├── scripts/
│   ├── run.py
│   ├── regress.py
│   ├── triage.py
│   └── adapters/
│       └── xsim.py
├── docs/
│   ├── design_notes.md
│   ├── verification_notes.md
│   └── commands.md
├── reports/
│   └── run_<timestamp>/
├── evidence/
│   ├── waveforms/
│   ├── screenshots/
│   └── logs/
├── ci/
└── tools/
```

### Folder intent

- `rtl/` stores synthesizable design logic
- `tb/` stores self-checking testbench code
- `scripts/` stores reproducible execution helpers
- `docs/` stores design, verification, and command references
- `reports/` stores generated simulation outputs
- `evidence/` stores curated screenshots, wave configs, and selected logs
- `ci/` stores CI-related hooks if you later automate regressions

---

## Interface Concept

Typical register slice interface:

### Upstream-facing signals
- `in_valid` : producer indicates payload is available
- `in_ready` : slice indicates it can accept payload
- `in_data`  : payload entering the slice

### Downstream-facing signals
- `out_valid` : slice indicates payload is available
- `out_ready` : consumer indicates it can accept payload
- `out_data`  : payload leaving the slice

### Infrastructure signals
- `clk`
- `rst_n`

### Typical parameters
- `DATA_W` : payload width
- `SKID_EN` : enables optional skid storage behavior
- `RESET_VALUE` *(optional)* : makes reset waveforms easier to inspect

---

## Expected Handshake Rules

The slice should obey the standard transfer model.

### Input-side acceptance
A new payload is accepted when:

```text
in_valid && in_ready
```

### Output-side consumption
A stored payload is consumed when:

```text
out_valid && out_ready
```

### Hold-under-stall requirement
If `out_valid=1` while `out_ready=0`, then:
- `out_valid` must remain asserted
- `out_data` must remain stable
- the payload must not be overwritten or lost

### Bubble behavior
If the stage is empty, it must be able to:
- advertise readiness upstream
- accept a new transaction
- later present it downstream correctly

### No ghost transfers
The stage must never invent a transaction that was not accepted at the input.

### No duplication
Each accepted input beat must map to exactly one output beat.

---

## Microarchitecture Overview

A simple non-skid register slice can be understood with two core state elements:
- `full_q` : indicates whether the stage currently holds a valid item
- `data_q` : stores the payload associated with that valid item

### Behavioral intuition
- when empty, the slice should be ready to accept data
- when full and stalled, it should hold both valid and payload stable
- when full and downstream consumes, it may either become empty or immediately refill in the same cycle depending on upstream activity

### Important throughput case
The case below is critical for one-beat-per-cycle flow:
- **full + downstream consume + upstream refill in same cycle** → remain full with the new payload

That is what allows a register slice to sustain flow instead of introducing avoidable bubbles.

---

## Optional Skid Buffer Mode

A skid-capable slice adds a temporary second holding location so that one extra beat can be absorbed under controlled backpressure conditions.

### Why skid mode matters
It helps when:
- downstream backpressure arrives at a timing-sensitive boundary
- immediate upstream throttling is undesirable
- one-cycle absorption improves throughput or timing closure options

### What must be proven in skid mode
- no payload overwrite occurs
- ordering is preserved across main and skid storage
- skid capture only happens in legal situations
- skid release back into the main path is correct
- no extra or missing transfers appear at the output

---

## Verification Strategy

The project should be verified with a **self-checking integrated testbench** that covers both directed and stress scenarios.

Core verification targets include:
- reset state correctness
- empty-stage acceptance behavior
- full-stage stall hold behavior
- back-to-back throughput behavior
- simultaneous consume-and-refill behavior
- random valid/ready toggling
- payload order preservation
- optional skid behavior under one-cycle backpressure events

The detailed closure plan lives in:
- `docs/verification_notes.md`

---

## Evidence to Capture

For a strong GitHub portfolio repo, keep curated proof artifacts such as:
- saved waveform configuration file
- screenshots showing reset behavior
- screenshots showing stall hold stability
- screenshots showing simultaneous consume/refill
- screenshots showing skid capture and release, if implemented
- selected logs showing testcase names and PASS status

Suggested evidence locations:
- `evidence/waveforms/`
- `evidence/screenshots/`
- `evidence/logs/`

---

## Tool Flow

This project is intended to run with a lightweight, reproducible simulation flow.

Example environment:
- Python 3
- XSim (Vivado 2019.2 on Nobel)
- waveform inspection through `.wdb` outputs

Primary execution style:

```bash
python3 -m scripts.run --tool xsim --suite smoke --test vr_slice --waves
```

More detailed commands are documented in:
- `docs/commands.md`

---

## Skills Demonstrated

This project demonstrates:
- SystemVerilog RTL design
- valid/ready handshake design
- synchronous flow-control microarchitecture
- backpressure-aware datapath behavior
- self-checking testbench development
- waveform-based debug and evidence capture
- reproducible simulation workflow organization

---

## Suggested Extensions

After the baseline slice is correct, useful extensions include:
- optional skid buffer implementation
- parameterized payload structs via packed types
- assertion checks for payload stability and handshake legality
- randomized traffic stress testing
- coverage collection for accept/hold/release/skid events
- chaining multiple slices to study latency and throughput effects

---

## Project Positioning

This repository is written as a **standalone RTL portfolio project**.

It can later be reused inside larger pipelines, SoC subsystems, or interface paths, but this repo is intentionally scoped as an independent block-level design and verification effort with its own closure, evidence, and documentation.

---

## Quick Start

```bash
python3 -m scripts.run --tool xsim --suite smoke --test vr_slice --waves
```

Then inspect:
- generated reports under `reports/`
- waveform database under the latest run directory
- curated evidence under `evidence/`

---

## Current Status Template

Use this section later to summarize progress.

- RTL implementation: TODO / IN PROGRESS / DONE
- Integrated testbench: TODO / IN PROGRESS / DONE
- Directed scenario closure: TODO / IN PROGRESS / DONE
- Skid-mode closure: TODO / IN PROGRESS / DONE
- Curated waveform evidence: TODO / IN PROGRESS / DONE
- README polish and final screenshots: TODO / IN PROGRESS / DONE

---

## License / Usage

Use the license model you prefer for your project repositories.
