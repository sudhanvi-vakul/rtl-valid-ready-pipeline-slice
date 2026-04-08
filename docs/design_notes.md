# Design Notes - Valid/Ready Pipeline Register Slice

---

## 1) Design Objective

Design a reusable synchronous pipeline element that transfers payloads using a `valid/ready` handshake while preserving:
- functional correctness
- data ordering
- stable behavior under stall
- one-beat-per-cycle throughput in steady-state flow
- optional one-cycle backpressure absorption through skid support

---

## 2) Problem Statement

In a decoupled interface, producer and consumer operate independently:
- the producer decides when data is available (`valid`)
- the consumer decides when it can accept data (`ready`)

The register slice sits between them and must safely absorb the mismatch.

This is not just a storage register. It is a **flow-control element**.

The design must answer:
- when can input be accepted?
- when must output remain stable?
- when can data move out?
- can a new beat replace an old beat in the same cycle?
- if skid exists, when is second-entry storage allowed to capture?

---

## 3) Interface Specification

### Clock / reset
- `clk`   : synchronous clock
- `rst_n` : active-low reset

### Upstream interface
- `in_valid`
- `in_ready`
- `in_data[DATA_W-1:0]`

### Downstream interface
- `out_valid`
- `out_ready`
- `out_data[DATA_W-1:0]`

### Parameters
- `DATA_W`  : payload width
- `SKID_EN` : 0 = baseline slice, 1 = skid-capable slice

---

## 4) Functional Meaning of Signals

### `in_valid`
Producer is presenting a meaningful payload on `in_data`.

### `in_ready`
Slice can accept a payload this cycle.

### `out_valid`
Slice currently presents a meaningful payload to downstream.

### `out_ready`
Consumer can accept a payload this cycle.

### Input handshake
A new beat enters when:
```text
in_valid && in_ready
```

### Output handshake
A stored/presented beat leaves when:
```text
out_valid && out_ready
```

---

## 5) Baseline Slice State Model

For the baseline design, the state can be modeled with:
- `full_q` : 1 when the stage holds a valid entry
- `data_q` : stored payload

### Observable mapping
- `out_valid = full_q`
- `out_data  = data_q`

The main design challenge is computing `in_ready` correctly while maintaining stable state during stalls.

---

## 6) Behavioral Cases

### Case 1 - Empty stage, no incoming beat
- `full_q = 0`
- no state change
- `in_ready` should be asserted because the stage has space

### Case 2 - Empty stage, incoming beat
- input handshake occurs
- capture `in_data`
- set `full_q = 1`
- transaction becomes available to downstream after registration behavior

### Case 3 - Full stage, downstream stalled
- `full_q = 1`
- `out_ready = 0`
- no output handshake
- no overwrite allowed
- `out_valid` and `out_data` must remain stable

### Case 4 - Full stage, downstream consumes, no refill
- output handshake occurs
- stage becomes empty

### Case 5 - Full stage, downstream consumes, upstream refills same cycle
- output handshake occurs
- input handshake also occurs
- stage stays full
- old payload is considered transferred out
- new payload becomes stored/current payload

This is the throughput-critical case.

---

## 7) Ready Logic Intuition

The slice can generally accept input when either:
- it is currently empty, or
- it will be freed this cycle because downstream consumes current data

A common conceptual form is:
```text
in_ready = !full_q || out_ready
```

This reflects an important microarchitectural idea:
- when the current entry is being consumed, the stage can immediately refill

However, final implementation style may vary depending on how you code combinational versus sequential logic and whether skid mode is enabled.

---

## 8) Throughput and Latency

### Latency
A one-stage register slice generally adds one stage of latency.

### Throughput
When upstream keeps `in_valid=1` and downstream keeps `out_ready=1`, the slice should sustain:
- **1 transfer per cycle** after filling/steady-state begins

### Why simultaneous consume + refill matters
If the design unnecessarily empties before refilling, throughput degrades.
If it supports consume-and-refill correctly, it maintains streaming throughput.

---

## 9) Bubble Semantics

A bubble means the stage is empty for a cycle or more.

Bubbles can be introduced by:
- no incoming valid beat
- downstream draining data while upstream does not refill
- reset

The design must handle bubble creation and later refill without producing ghost output activity.

---

## 10) Stall Semantics

A stall occurs when:
- the stage is holding valid data
- downstream is not ready

Required stall properties:
- data must remain unchanged
- valid must remain asserted
- no new input acceptance unless the design explicitly supports extra buffering (skid)

In the baseline design, a full stalled stage effectively blocks upstream.

---

## 11) Ordering Guarantee

This block is FIFO-like in ordering even if it only holds one beat.

It must preserve:
- acceptance order
- delivery order
- one-to-one mapping between accepted and delivered beats

No transaction may:
- disappear
- appear twice
- overtake another

---

## 12) Skid Buffer Motivation

A skid-capable slice extends buffering by one extra entry.

### Reason
Sometimes downstream `ready` deassertion cannot be reflected upstream soon enough, or timing/performance reasons favor keeping input acceptance open for one more beat.

### Effect
The design can temporarily hold:
- main stage entry
- skid entry

### Result
One-cycle backpressure mismatch can be absorbed without data loss.

---

## 13) Skid State Model (Conceptual)

When `SKID_EN=1`, additional state typically includes:
- `skid_valid_q`
- `skid_data_q`

Possible occupancy states:
- empty
- main only
- main + skid

The exact implementation can vary, but key rules remain:
- main entry is oldest
- skid entry is younger
- release order must remain preserved

---

## 14) Skid Behavioral Cases

### Skid capture case
If main entry is blocked from leaving and one more input beat must be preserved, skid can capture it.

### Skid drain case
When downstream resumes, the main entry leaves first, then skid content advances into service order.

### Prohibited behavior
- capturing more than one extra beat without capacity
- replacing older beat with newer beat
- presenting skid data before main data

---

## 15) Reset Behavior

Reset should place the design into a known empty state.

### After reset
- `out_valid = 0`
- stage occupancy = empty
- stored data may be reset for readability, but functional requirement is mainly that `valid` is cleared
- `in_ready` should reflect the stage can accept new work once reset is released

### Reset during traffic
If reset occurs while entries exist:
- outstanding buffered contents are discarded unless you intentionally define otherwise
- output must return to empty-state behavior
- post-reset operation must restart cleanly

---

## 16) Assertions Worth Adding

### Stability under stall
If `out_valid && !out_ready`, then on the next cycle:
- `out_valid` stays high
- `out_data` stays unchanged

### No output handshake without valid
Disallow false transfer accounting when `out_valid=0`.

### No acceptance without readiness
Internal scoreboarding should never count input transfers unless `in_valid && in_ready`.

### Eventual ordering correctness
Usually validated with scoreboard in simulation rather than a single simple assertion.

### Optional skid occupancy checks
Prevent illegal `skid_valid_q` combinations or overwrite scenarios.

---

## 17) Suggested Internal Debug Signals

For easier waveform review, expose or observe these internal signals in simulation:
- `full_q`
- `data_q`
- `accept_in`
- `accept_out`
- `skid_valid_q` *(if enabled)*
- `skid_data_q` *(if enabled)*
- occupancy indicator *(optional TB-derived signal)*

These make it much easier to prove behavior than looking only at top-level I/O.

---

## 18) Corner Cases to Think About

### Empty + out_ready toggles
Downstream readiness may toggle even when no valid data exists. That must not cause false transfers.

### Full + in_valid remains high during stall
Producer may continue requesting. The stage must either block or safely absorb depending on mode.

### Consume + refill with same data value
Do not confuse equal payload values with duplication correctness. Use transaction counts/scoreboard, not only wave appearance.

### Reset near transfer edge
Ensure testbench clearly defines sampling order and expected post-reset behavior.

### Repeated identical payloads
A good TB should intentionally send duplicate numeric values at different times to prove counting/order logic rather than relying on unique values only.

---

## 19) Recommended Verification Architecture

Use a self-checking TB with three layers:

### Layer A - Directed scenarios
Handcrafted cases for reset, stall, bubble, and simultaneous consume/refill.

### Layer B - Scoreboard
Queue accepted inputs and compare delivered outputs.

### Layer C - Assertions
Add protocol safety checks for hold, illegal movement, and optional skid constraints.

This combination is much stronger than waveform-only inspection.

---

## 20) Performance Expectations

### Baseline slice
- 1-cycle storage stage
- 1 beat/cycle throughput in steady-state
- no extra elasticity beyond main stage

### Skid slice
- same functional interface
- more robust under short backpressure events
- higher implementation complexity

---

## 21) Coding Recommendations

- Keep state machine implicit through occupancy bits instead of large explicit FSM if not needed
- Separate combinational next-state logic from sequential updates cleanly
- Avoid accidental combinational loops between `ready` and `valid`
- Keep RTL readable first, clever second
- Name handshake events explicitly in code, for example:
  - `take_in`
  - `take_out`

That makes debug easier.

---

## 22) Common Design Bugs

Watch for these:

1. `out_data` changes while stalled  
2. `out_valid` drops during stall  
3. input accepted even though stage has no capacity  
4. same-cycle consume/refill incorrectly empties stage  
5. duplicated output after refill  
6. skipped transaction during ready toggling  
7. skid entry overwrite  
8. wrong ordering between main and skid entries  
9. reset leaves stale valid asserted  
10. TB mistakes a presented value for a transferred value

---

## 23) Design Completion Criteria

The design is considered closed when:
- all directed tests pass
- random throttling tests pass
- scoreboard shows no mismatch, no drop, no duplicate
- stall stability is proven in simulation and assertion checks
- optional skid mode also closes if implemented
- wave evidence clearly shows the key handshake behaviors

---

## 24) Final Design Intent Statement

This block is a foundational microarchitectural primitive for controlled transaction movement inside synchronous systems. Its purpose is not merely to register data, but to correctly manage the contract between producer and consumer under all combinations of availability and backpressure.
