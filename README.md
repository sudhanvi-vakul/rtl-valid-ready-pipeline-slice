# Stage 2 - Valid/Ready Pipeline Register Slice

A reusable valid/ready pipeline stage built on top of the Stage 0 RTL CI/CD backbone.

---

## 1) Project Summary

This project implements a **valid/ready register slice** that safely moves transactions between an upstream producer and a downstream consumer in a synchronous RTL datapath.

The block is intentionally simple in appearance, but architecturally important:
- it defines how work advances when both sides agree
- it prevents data loss during stalls
- it allows bubble movement through the pipeline
- it provides a clean place to learn and prove backpressure behavior
- it becomes reusable in later projects such as issue pipelines, execution lanes, MMIO response paths, bus adapters, and accelerator front ends

This Stage 2 project is the first step where the portfolio moves from **safe data crossing** (Stage 1 CDC) into **microarchitectural flow control**.

---

## 2) Project Goal

Build a parameterized register slice with:
- `valid/ready` handshake semantics
- registered payload storage
- correct hold-under-stall behavior
- correct bubble insertion/removal behavior
- optional skid buffering for one-cycle backpressure absorption
- self-checking verification with waveform evidence
- reproducible runs through the Stage 0 backbone flow

---

## 3) Why This Project Matters

A surprising amount of modern RTL is not only arithmetic or control state machines. A lot of design quality comes from how data **moves**.

This project teaches the core movement rules used in:
- CPU pipelines
- NoC/router datapaths
- bus/register response channels
- DMA paths
- streaming accelerators
- queue fronts and backs
- decoupled execution interfaces

If this block is wrong, later systems show:
- duplicated transfers
- dropped transfers
- corrupted ordering
- dead cycles
- unstable outputs during backpressure
- hard-to-debug pipeline deadlocks

So this project is small in code size, but large in architectural importance.

---

## 4) What Is Implemented

Recommended design files for this project:

- `rtl/vr_slice.sv`  
  Base one-stage valid/ready register slice

- `rtl/vr_slice_pkg.sv` *(optional)*  
  Common typedefs, constants, helper functions

- `tb/vr_slice_integrated_tb.sv`  
  Self-checking integrated testbench covering pass-through, stalls, bubbles, bursts, and optional skid mode

- `scripts/run.py`  
  Existing Stage 0 runner reused without changing the overall workflow style

- `tests/tests.yaml` or `tests.yaml`  
  Test registration for smoke and deeper regression runs

---

## 5) Recommended Repo Structure

The project should keep the same backbone style you established in Stage 0.

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

- `rtl/` stores synthesizable RTL only
- `tb/` stores self-checking testbenches
- `docs/` stores design intent, verification plan, and repeatable command logs
- `reports/` stores generated run outputs
- `evidence/` stores curated screenshots and selected proof artifacts you want to keep in git
- `scripts/` keeps the Stage 0 reproducible execution style intact

---

## 6) Interface Concept

Typical interface for a valid/ready slice:

### Upstream side
- `in_valid` : producer says payload is available
- `in_ready` : slice says it can accept payload
- `in_data`  : payload from producer

### Downstream side
- `out_valid` : slice says payload is available to consumer
- `out_ready` : consumer says it can accept payload
- `out_data`  : payload toward consumer

### Control / infrastructure
- `clk`
- `rst_n`

### Optional parameters
- `DATA_W` : payload width
- `SKID_EN` : enable optional skid buffer behavior
- `RESET_VALUE` *(optional)* : easier waveform readability during reset

---

## 7) Expected Handshake Behavior

The register slice must obey the standard transfer rules.

### Rule A - Input transfer occurs when
```text
in_valid && in_ready
```

### Rule B - Output transfer occurs when
```text
out_valid && out_ready
```

### Rule C - Payload stability under stall
If `out_valid=1` and `out_ready=0`, then:
- `out_valid` must remain asserted
- `out_data` must remain stable
- the stored transaction must not be overwritten or lost

### Rule D - Bubble behavior
If the stage is empty, it should be able to:
- advertise readiness upstream
- accept a new transaction
- later present it downstream

### Rule E - No ghost traffic
The slice must never create a transaction that was never accepted at the input.

### Rule F - No duplication
One accepted input beat must eventually correspond to exactly one output beat.

---

## 8) Base Microarchitecture

A simple non-skid register slice can be understood with two state variables:
- `full_q` : whether the stage currently holds a valid transaction
- `data_q` : stored payload

### Intuition
- when empty, the stage can accept data
- when full and downstream is stalled, it must hold its contents
- when full and downstream consumes, it either becomes empty or immediately refills depending on upstream activity

### Common implementation style
The stage usually computes:
- whether it can accept new data this cycle
- whether downstream is consuming this cycle
- next-state for `full_q`
- next-state for `data_q`

One common behavioral view is:

- **empty + incoming beat** → capture data and become full
- **full + stalled** → hold everything
- **full + downstream consume + no refill** → become empty
- **full + downstream consume + refill same cycle** → remain full with new payload

This last case is especially important because it enables throughput of one beat per cycle once the pipeline is flowing.

---

## 9) Optional Skid Buffer Behavior

A skid-capable slice is useful when backpressure can arrive one cycle later than ideal, or when you want to absorb a one-cycle readiness mismatch without dropping throughput.

### Why skid exists
Without a skid path, a design sometimes must deassert `in_ready` immediately when downstream stalls. In some systems this causes timing pressure or throughput loss.

A skid buffer gives the design a temporary second holding location so that one additional beat can be safely absorbed under carefully controlled conditions.

### What to prove in skid mode
- the main register still behaves correctly
- skid storage only captures when required
- no overwritten payloads occur
- ordering is preserved across main + skid entries
- release from skid back into main/out path is correct

---

## 10) Design Choices Recommended for This Repo

### Baseline version first
Implement the simplest correct register slice first:
- one storage register
- one valid bit
- no combinational data loops
- clean registered behavior

### Skid version second
After the baseline passes:
- add parameterized skid support
- keep the same interface
- reuse the same testbench with parameter overrides

### Why this order matters
If you start with skid logic immediately, debug becomes harder because two storage locations and multiple movement conditions exist from day one.

---

## 11) Verification Strategy Overview

Verification should be done as an **integrated, self-checking testbench**, not only by visually inspecting waves.

The testbench should verify:
- reset behavior
- empty/full-like occupancy behavior for a one-stage slice
- pass-through / first transfer correctness
- stall hold correctness
- bubble movement
- back-to-back throughput
- random valid/ready throttling
- payload ordering
- no drop / no duplicate behavior
- optional skid absorption behavior

### Verification model recommendation
Use a small queue or scoreboard in the TB:
- push payload into expected queue when input handshake occurs
- pop and compare when output handshake occurs
- check queue depth against DUT occupancy expectations when applicable

This gives precise proof of ordering and no-loss behavior.

---

## 12) Suggested Verification Scenarios

The detailed version lives in `docs/verification_notes.md`, but at a high level the project should cover:

1. reset default state  
2. first accept into empty slice  
3. first output transfer  
4. downstream stall while full  
5. bubble propagation after consumer drains  
6. back-to-back transfers without stalls  
7. alternating valid patterns  
8. alternating ready patterns  
9. simultaneous consume and refill  
10. long bursts  
11. random traffic with scoreboard  
12. payload stability under stall  
13. no output when empty  
14. no input accept when blocked  
15. optional skid capture and release  
16. reset during traffic  
17. reset recovery  
18. corner payload patterns  
19. throughput measurement sanity  
20. assertions for protocol safety

---

## 13) Evidence You Should Capture

You like structured proof artifacts, so capture them intentionally.

### Save these items
- `xsim.log`
- waveform database `.wdb`
- curated `.wcfg`
- screenshots for critical scenarios
- summary snippets showing PASS/FAIL per testcase

### Recommended screenshots
- reset state
- first transaction accepted
- stall with held payload
- simultaneous consume+refill case
- long back-to-back transfer region
- skid capture and later drain (if skid enabled)

---

## 14) Execution Flow

Assuming the repo was cloned from your Stage 0 CI/CD backbone and adapted for Stage 2:

### Typical smoke run
```bash
python3 -m scripts.run --tool xsim --suite smoke --test vr_slice --waves
```

### Open latest waveform
```bash
set latest=`ls -td reports/run_* | head -1`
echo $latest
xsim $latest/work.sim.wdb &
```

### Inspect logs
```bash
grep -nE "TC[0-9][0-9]|PASS|FAIL|ERROR|MISMATCH" $latest/xsim.log
```

A fuller commands log is provided in `docs/commands.md`.

---

## 15) What You Learn From This Project

After finishing this project properly, you should be comfortable with:
- valid/ready semantics
- backpressure behavior
- stall-safe registered datapaths
- bubble movement in pipelines
- throughput versus latency tradeoffs
- scoreboard-based checking for decoupled interfaces
- writing protocol-oriented assertions
- reusing a standardized RTL execution backbone across projects

---

## 16) Suggested Milestone Order

### M0 - Repo bootstrap
Clone the Stage 0 backbone into a new Stage 2 repo and update names/files.

### M1 - Baseline slice RTL
Implement the one-register valid/ready stage.

### M2 - Integrated TB
Build directed testbench with scoreboard.

### M3 - Directed verification closure
Close all deterministic scenarios and capture wave evidence.

### M4 - Random throttling regression
Stress input/output valid/ready combinations.

### M5 - Assertions
Add protocol assertions for stability and no-illegal-transfer behavior.

### M6 - Optional skid support
Enable `SKID_EN` mode and extend TB coverage.

---

## 17) Stage-to-Stage Portfolio Positioning

This project sits in your staged portfolio like this:

- **Stage 0**: reproducible RTL CI/CD backbone
- **Stage 1**: safe data transfer across clock domains
- **Stage 2**: safe transaction movement within a synchronous pipeline

That makes the story clean:
- first you proved **safe crossing**
- now you prove **safe flow control**
- later you can build larger datapaths and microarchitectures using these foundations

---

## 18) Recommended Next Extensions

Once the base project is closed, natural extensions are:
- multi-stage chaining of slices
- sideband metadata (`last`, `id`, `resp`, etc.)
- multi-entry elastic buffers
- integration into a tiny issue/execute path
- AXI-stream-like channel wrapper
- latency/throughput counters in TB
- formal-ready assertions or stronger property sets later

---

## 19) Deliverables Checklist

Before you call Stage 2 done, you should have:

- [ ] clean repo created from Stage 0 backbone
- [ ] RTL for base register slice
- [ ] optional skid mode or at least planned hook for it
- [ ] integrated self-checking TB
- [ ] passing smoke suite
- [ ] passing regression suite
- [ ] curated waveform screenshots
- [ ] `docs/design_notes.md` completed
- [ ] `docs/verification_notes.md` completed with results table
- [ ] `docs/commands.md` updated with your real Nobel commands
- [ ] README reflecting actual final repo structure

---

## 20) Final Notes

Keep the implementation disciplined:
- correctness first
- throughput second
- skid third
- polish and evidence always

This project is where your portfolio starts to look more like real microarchitecture work instead of only isolated RTL blocks.
