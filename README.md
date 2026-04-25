# Valid/Ready Pipeline Register Slice

![SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-blue)
![Microarchitecture](https://img.shields.io/badge/Focus-Handshake%20Pipeline-success)
![Verification](https://img.shields.io/badge/Verification-Directed%20%2B%20Assertions-orange)
![Status](https://img.shields.io/badge/Project-Advanced%20Version%20In%20Progress-yellow)

A reusable **valid/ready pipeline register slice** built in **SystemVerilog** with:
- baseline single-stage buffering
- optional skid support
- stable stall behavior
- same-cycle consume/refill support
- directed self-checking verification
- handshake assertions
- parameterized payload width
- optional debug and occupancy visibility

This project focuses on a small but important RTL primitive that I can reuse later in larger datapaths, pipeline stages, interconnect paths, and subsystem integration work.

---

## Table of Contents

- [Overview](#overview)
- [Project Goals](#project-goals)
- [Architecture](#architecture)
- [Implemented Modules](#implemented-modules)
- [What This Version Adds](#what-this-version-adds)
- [Verification Strategy](#verification-strategy)
- [Testcase Coverage](#testcase-coverage)
- [Waveform Inspection Goals](#waveform-inspection-goals)
- [Repository Structure](#repository-structure)
- [How to Run](#how-to-run)
- [Expected Outputs](#expected-outputs)
- [What This Project Demonstrates](#what-this-project-demonstrates)
- [Future Reuse](#future-reuse)
- [Summary](#summary)

---

## Overview

This project implements a synchronous pipeline slice that moves payloads between an upstream producer and a downstream consumer using a `valid/ready` handshake.

The block is small, but it sits in the middle of an important microarchitecture problem:
- accept data only when capacity exists
- hold data stable under backpressure
- preserve ordering exactly
- support steady-state throughput
- optionally absorb a short backpressure mismatch with skid storage

I am using this project to build a reusable handshake building block rather than a one-off classroom register.

---

## Project Goals

- Build a reusable valid/ready slice in SystemVerilog
- Support correct stall, bubble, drain, and refill behavior
- Preserve data ordering and transfer accounting
- Add optional skid behavior as a clean design option
- Verify the design with directed tests, assertions, and waveform evidence
- Keep the implementation parameterized and reusable for later projects

---

## Architecture

```text
                upstream side                          downstream side

        in_valid
        in_data[DATA_W-1:0]
             |
             v
    +--------------------------+
    |      vr_slice.sv         |
    |                          |
    |  main register stage     |
    |  valid/ready control     |
    |  optional skid storage   |
    |  optional debug signals  |
    +--------------------------+
             |
             +------> out_valid
             +------> out_data[DATA_W-1:0]
             ^
             |
        in_ready / out_ready handshake control
```

### Conceptual occupancy

```text
SKID_EN = 0
  occupancy = 0 -> empty
  occupancy = 1 -> main stage full

SKID_EN = 1
  occupancy = 0 -> empty
  occupancy = 1 -> main stage full
  occupancy = 2 -> main stage + skid entry full
```

---

## Implemented Modules

### RTL

#### `rtl/vr_slice.sv`
Top-level valid/ready pipeline slice.

**Current design scope**
- parameterized `DATA_W`
- baseline single-stage buffering
- optional skid mode through `SKID_EN`
- optional debug and occupancy visibility
- same-cycle consume/refill behavior
- stable output behavior under stall

### Testbench

#### `tb/vr_slice_integrated_tb.sv`
Main self-checking testbench used for directed scenarios, scoreboard-style checks, and transfer accounting.

### Assertions

#### `tb/assertions/` *(planned / current enhancement area)*
Handshake stability and protocol safety checks such as:
- hold valid under stall
- hold data under stall
- reset clears interface state cleanly
- optional occupancy legality checks

---

## What This Version Adds

Compared to the baseline slice, this advanced version adds:

- **optional skid mode**  
  lets the slice absorb one extra beat during short backpressure events

- **handshake assertions**  
  checks protocol stability during stall and reset behavior

- **parameter sweep for `DATA_W`**  
  verifies the block across multiple payload widths

- **optional debug and occupancy signals**  
  makes waveform review and testcase debugging easier

- **separate directed tests**  
  keeps verification focused instead of relying only on one large integrated scenario

These additions make the block more reusable in later projects.

In other words, the original directed plan was 28 tests, and the advanced implementation path closes at 32 tests once the added enhancement-focused checks are included.

---

## Verification Strategy

Verification uses three layers together. The original base plan tracked 28 tests through TC28. For the advanced version I am actually implementing, the closure target is 32 tests, with four added cases for width-specific sanity, debug visibility, and skid/non-skid comparison.


### Directed tests
Focused scenarios for:
- reset
- first accept
- first drain
- hold under stall
- bubble then refill
- same-cycle consume/refill
- skid capture and drain
- transfer counting
- width sweep behavior

### Self-checking comparison
The testbench tracks accepted and delivered transfers to catch:
- dropped transactions
- duplicate transactions
- ordering errors
- count mismatches

### Assertions
Assertions strengthen protocol checking for:
- stable `out_valid` under stall
- stable `out_data` under stall
- clean reset behavior
- optional skid legality / occupancy legality

---

## Testcase Coverage

| Test ID | Name | Scope | Status |
|---|---|---|---|
| TC01 | Reset Default State | baseline | PASS |
| TC02 | First Accept Into Empty Slice | baseline | PASS |
| TC03 | First Output Transfer | baseline | PASS |
| TC04 | Hold Under Downstream Stall | baseline | PASS |
| TC05 | Drain To Empty | baseline | PASS |
| TC06 | Bubble Then Refill | baseline | PASS |
| TC07 | Back-to-Back Throughput | baseline | PASS |
| TC08 | Alternating Input Valid | baseline | PASS |
| TC09 | Alternating Output Ready | baseline | PASS |
| TC10 | Simultaneous Consume And Refill | baseline | PASS |
| TC11 | Long Burst Transfer | baseline | PASS |
| TC12 | Output Idle Behavior While Empty | baseline | PASS |
| TC13 | Input Blocking When Full And Stalled | baseline | PASS |
| TC14 | Repeated Same Payload Values | baseline | PASS |
| TC15 | Corner Data Patterns | baseline | PASS |
| TC16 | Random Valid/Ready Throttling | stress | PASS |
| TC17 | Long Stall With Persistent Upstream Requests | stress | PASS |
| TC18 | Random Burst Length Sweep | stress | PASS |
| TC19 | Reset During Held Valid | reset robustness | PASS |
| TC20 | Reset During Streaming Traffic | reset robustness | PASS |
| TC21 | Recovery Immediately After Reset | reset robustness | PASS |
| TC22 | Transfer Count Accounting | accounting | PASS |
| TC23 | Assertion Stress Run | assertions | PASS |
| TC24 | Skid Disabled Reference Behavior | skid reference | PASS |
| TC25 | Skid Single Extra Capture | skid | PASS |
| TC26 | Skid Hold And Drain Ordering | skid | PASS |
| TC27 | Skid With Repeated Backpressure Pulses | skid | PASS |
| TC28 | Skid Random Traffic Stress | skid | PASS |
| TC29 | DATA_W = 8 Sanity Run | width sweep | PASS |
| TC30 | DATA_W = 32 Sanity Run | width sweep | PASS |
| TC31 | Occupancy / Debug Signal Consistency | debug visibility | TODO |
| TC32 | Skid On/Off Shared Scenario Comparison | regression | TODO |

---

## Best mental model

Think of the flow like this:

 - Smoke = “did I break the basics?”
 - Flow = “does the normal baseline slice behavior work?”
 - Stress = “does it survive harder/random/reset situations?”
 - No-skid ref = “does baseline mode behave correctly?”
 - Skid = “does the enhanced buffer behavior work?”
 - W8 / W32 = “does parameterization hold?”
 - Debug = “are debug/occupancy signals trustworthy?”
 - Compare = “are shared skid-off/skid-on behaviors consistent?”
 - Integrated = “does a representative combined run still look healthy?”


---

## Repository Structure

```text
rtl-valid-ready-pipeline-slice/
├── README.md
├── requirements.txt
├── tests.yaml│
├── ci/
├── docs/
│   ├── commands.md
│   ├── debug.md
│   ├── design_notes.md
│   └── verification_notes.md│
├── evidence/
│   └── waveforms/
│       ├── smoke_test1_results.png
│       ├── smoke_test2_results.png
│       └── smoke_test_passed.png
├── reports/
│   └── .gitkeep
├── rtl/
│   ├── vr_slice.sv
│   └── vr_slice_smoke.sv
├── scripts/
│   ├── __init__.py
│   ├── regress.py
│   ├── report.py
│   ├── run.py
│   ├── triage.py
│   └── adapters/
│       ├── __init__.py
│       ├── questa.py
│       └── xsim.py
├── tb/
│   ├── .gitkeep
│   ├── vr_slice_compare_tb.sv
│   ├── vr_slice_debug_tb.sv
│   ├── vr_slice_flow_tb.sv
│   ├── vr_slice_integrated_smoke_tb.sv
│   ├── vr_slice_integrated_tb.sv
│   ├── vr_slice_noskid_ref_tb.sv
│   ├── vr_slice_skid_tb.sv
│   ├── vr_slice_smoke_tb.sv
│   ├── vr_slice_stress_tb.sv
│   ├── vr_slice_sva.sv
│   ├── vr_slice_tb_base.sv
│   ├── vr_slice_w32_tb.sv
│   └── vr_slice_w8_tb.sv
├── tests/
│   └── .gitkeep
└── tools/
    └── new_project.py
```

---

## How to Run

Example smoke run:

```bash
python3 -m scripts.run --tool xsim --suite smoke --test vr_slice --waves
```

Example regression pattern:

```bash
python3 -m scripts.run --tool xsim --suite regress --test vr_slice --waves
```

Example width sweep pattern:

```bash
python3 -m scripts.run --tool xsim --suite regress --test vr_slice --waves
```

The exact regression list depends on the entries wired into `tests.yaml`.

---

## Waveform Inspection Goals

Waveform evidence is used to inspect:
- reset to empty-state behavior
- empty-to-full transition
- stable `out_valid` and `out_data` under stall
- drain back to empty
- bubble creation and later refill
- same-cycle consume/refill throughput behavior
- blocked input acceptance in baseline mode
- skid capture and ordered drain in skid mode
- transfer counters and occupancy visibility during stress


## Expected Outputs

Typical generated artifacts include:
- compile logs
- simulation logs
- waveform database files
- run-specific report folders under `reports/run_*`
- testcase summary text in logs
- curated screenshots under `evidence/waveforms/`

Typical files include:
- `xsim.log`
- `xvlog.log`
- `work.sim.wdb`
- `run.tcl`

---

## What This Project Demonstrates

- reusable **valid/ready handshake RTL**
- practical **pipeline control design**
- correct **stall / bubble / refill behavior**
- optional **skid buffering**
- **directed + assertion-based verification**
- **parameterized RTL verification**
- structured evidence through **logs and waveforms**

---

## Future Reuse

This block is intended to be reused later as:
- a standard pipeline register slice
- a reusable handshake-checking reference
- a template for other flow-control blocks
- a clean starting point for larger datapath integration

The value of this project is not just that the design works, but that the design style and verification style can carry forward into later stages.

---

## Summary

This project implements a reusable **valid/ready pipeline register slice** with optional skid support, directed verification, handshake assertions, parameterized width support, and waveform-based evidence. It serves as a foundational flow-control block for later RTL and microarchitecture projects where safe data movement under backpressure matters as much as the datapath itself.
