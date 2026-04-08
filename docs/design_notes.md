# Design Notes - Valid/Ready Pipeline Register Slice

---

## 1) Design Objective

I am building a reusable synchronous pipeline element that transfers payloads using a `valid/ready` handshake while preserving:
- functional correctness
- ordering
- stable behavior under stall
- back-to-back throughput in steady-state flow
- optional one-beat skid capture

The goal is to make this block reusable later, not just pass a single project milestone.

---

## 2) Interface

### Clock / reset
- `clk`
- `rst_n`

### Upstream side
- `in_valid`
- `in_ready`
- `in_data[DATA_W-1:0]`

### Downstream side
- `out_valid`
- `out_ready`
- `out_data[DATA_W-1:0]`

### Parameters
- `DATA_W`
- `SKID_EN`

### Optional debug visibility
Depending on how I expose or observe internals in simulation, useful signals are:
- `dbg_accept`
- `dbg_produce`
- `dbg_hold`
- `dbg_skid_active`
- `dbg_occupancy`

---

## 3) Handshake Meaning

### Input handshake
A new beat is accepted when:

```text
in_valid && in_ready
```

### Output handshake
A beat leaves the slice when:

```text
out_valid && out_ready
```

These two events drive the important behaviors of the block:
- fill
- hold
- drain
- consume-and-refill
- optional skid capture

---

## 4) Baseline State Model

In the baseline version, the slice behaves like a one-entry buffer.

Useful internal concepts:
- `full_q` : main stage holds valid data
- `data_q` : stored payload

Observable behavior:
- `out_valid` reflects whether the stage is full
- `out_data` reflects the stored payload

The key challenge is not storage by itself.  
The key challenge is controlling acceptance and stability correctly.

---

## 5) Main Behaviors

### Empty
When the slice is empty:
- `out_valid = 0`
- it should be ready to accept data

### Fill
When the slice is empty and input handshake occurs:
- payload is captured
- the stage becomes full

### Hold
When the slice is full and downstream is not ready:
- current payload must remain stable
- `out_valid` must remain asserted
- no overwrite is allowed in baseline mode

### Drain
When the slice is full and downstream handshakes:
- current payload leaves
- the stage becomes empty if no refill occurs

### Consume and refill in the same cycle
When a stored beat is consumed and a new beat is accepted in the same cycle:
- the old beat is counted as transferred out
- the new beat immediately becomes the next resident beat
- the stage remains occupied

This is the most important throughput case.

---

## 6) Ready Logic Intuition

At a high level, the slice can accept input when:
- it is empty, or
- it will be freed by an output handshake in the same cycle

Conceptually this is why a form like the below is common:

```text
in_ready = !full_q || out_ready
```

The exact coding style can vary, but the intent is the same:
- do not block legal same-cycle refill
- do not accept data when no capacity exists

---

## 7) Bubble and Stall Semantics

### Bubble
A bubble means the stage is empty for one or more cycles.

Bubbles come from:
- no incoming valid beat
- a drain without refill
- reset

### Stall
A stall means:
- the stage holds valid data
- downstream is not ready

Required stall behavior:
- hold payload stable
- hold `out_valid` stable
- block illegal overwrite
- preserve transfer accounting

---

## 8) Ordering Guarantee

Even though this is a small block, it still has to preserve FIFO-style ordering.

That means:
- no drop
- no duplicate
- no reorder

The sequence of delivered beats must match the sequence of accepted beats exactly.

---

## 9) Skid Mode

When `SKID_EN=1`, the slice can temporarily absorb one extra beat under backpressure.

Useful internal concepts in skid mode:
- main stage entry
- skid entry

Conceptual occupancy becomes:
- `0` = empty
- `1` = main stage full
- `2` = main stage + skid full

Rules I want to preserve:
- main entry is older than skid entry
- skid capture is limited to one extra beat
- drain order must remain correct
- skid must never overwrite existing valid data illegally

Skid mode adds elasticity, but it should not change the ordering contract.

---

## 10) Reset Intent

After reset:
- the slice returns to empty state
- `out_valid = 0`
- no old payload should still appear as a valid transaction
- the block should be ready to accept new traffic after reset release

If reset happens during traffic:
- buffered contents are flushed
- post-reset operation should restart cleanly

---

## 11) Debug and Visibility Signals

For waveform review, I want visibility into the behaviors that matter rather than only top-level I/O.

Useful things to observe:
- acceptance event
- production event
- hold condition
- skid active state
- occupancy

These are debug aids only.  
They should not change functional behavior.

## 12) Current Closure Scope

The original baseline verification plan for this block stopped at **28 tests**.

For the advanced version I am actually implementing, I want the closure target to be **32 tests**. The extra four checks are tied directly to the enhancements I am adding now:
- a focused sanity run at `DATA_W=8`
- a focused sanity run at `DATA_W=32`
- a debug / occupancy consistency check
- a shared-scenario comparison between skid-disabled and skid-enabled behavior

I like this split because it reflects the real implementation path:
- **TC01-TC28** cover the baseline plus skid-directed behavior
- **TC29-TC32** close the advanced additions that make the block more reusable

---

## 13) Assertions I Want

The most important assertions for this block are:

### Hold valid under stall
If the block is presenting valid data and downstream is not ready, `out_valid` must remain asserted on the next cycle unless reset intervenes.

### Hold data under stall
If the block is stalled, `out_data` must remain unchanged unless reset intervenes.

### Clean reset behavior
After reset, the block must return to empty-state behavior.

### Optional legality checks
If skid and occupancy visibility are implemented, illegal states should be disallowed.

---

## 14) Common Failure Modes

These are the main bugs I want to guard against:
1. `out_valid` drops during stall
2. `out_data` changes during stall
3. input accepted when no capacity exists
4. same-cycle consume/refill handled incorrectly
5. dropped or duplicated transfer
6. skid overwrite
7. wrong drain order between main and skid
8. stale valid after reset

---

## 15) Design Closure Intent

I consider the design direction correct when it demonstrates:
- clean baseline slice behavior
- stable stall handling
- back-to-back throughput support
- clean reset recovery
- optional skid capture and drain
- usable debug visibility
- assertion-backed protocol stability

This project matters because it gives me a reusable handshake block that I can carry into later pipeline and subsystem work.
