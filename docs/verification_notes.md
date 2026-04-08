# Verification Notes - Valid/Ready Pipeline Register Slice

---

## 1) Verification Goal

Prove that the valid/ready register slice:
- accepts input only when capacity exists
- presents output only when data is stored
- preserves payload ordering exactly
- holds stable under downstream stalls
- supports back-to-back throughput without loss
- handles bubble creation/removal correctly
- optionally absorbs one-cycle backpressure in skid mode
- resets cleanly and recovers correctly

This verification plan is intentionally written at an **advanced** level so you can execute it gradually and still know the final closure target from day one.

---

## 2) DUT Assumptions

Assume a DUT interface similar to:
- `clk`
- `rst_n`
- `in_valid`
- `in_ready`
- `in_data[DATA_W-1:0]`
- `out_valid`
- `out_ready`
- `out_data[DATA_W-1:0]`
- optional internal visibility: `full_q`, `data_q`, `skid_valid_q`, `skid_data_q`

---

## 3) Verification Method

### Directed checking
Run carefully staged deterministic scenarios.

### Scoreboard checking
Maintain an expected queue:
- push on `in_valid && in_ready`
- pop+compare on `out_valid && out_ready`

### Assertion checking
Protocol safety assertions should supplement scoreboard checks.

### Waveform evidence
Capture screenshots for major behavioral categories.

---

## 4) Pass Criteria

A testcase passes only if all below are true:
- no TB fatal/error/mismatch
- no scoreboard mismatch
- transfer count matches expectations
- no assertion failures
- wave behavior matches intended scenario

---

## 5) Global Checks Used Across Many Tests

These checks should be reused in multiple scenarios:

1. **No ghost output**  
   No output transaction is counted unless `out_valid && out_ready`.

2. **No ghost input acceptance**  
   No input transaction is counted unless `in_valid && in_ready`.

3. **Order preserved**  
   Outputs match accepted-input order exactly.

4. **No drop**  
   Every accepted input eventually exits unless a reset explicitly flushes it.

5. **No duplicate**  
   No accepted beat exits more than once.

6. **Payload stability under stall**  
   If `out_valid=1` and `out_ready=0`, then output payload and validity remain stable.

---

## 6) Testcase Index

### Baseline functional tests
- TC01 Reset Default State
- TC02 First Accept Into Empty Slice
- TC03 First Output Transfer
- TC04 Hold Under Downstream Stall
- TC05 Drain To Empty
- TC06 Bubble Then Refill
- TC07 Back-to-Back Throughput
- TC08 Alternating Input Valid
- TC09 Alternating Output Ready
- TC10 Simultaneous Consume And Refill
- TC11 Long Burst Transfer
- TC12 Output Idle Behavior While Empty
- TC13 Input Blocking When Full And Stalled
- TC14 Repeated Same Payload Values
- TC15 Corner Data Patterns

### Robustness / stress tests
- TC16 Random Valid/Ready Throttling
- TC17 Long Stall With Persistent Upstream Requests
- TC18 Random Burst Length Sweep
- TC19 Reset During Held Valid
- TC20 Reset During Streaming Traffic
- TC21 Recovery Immediately After Reset
- TC22 Transfer Count Accounting
- TC23 Assertion Stress Run

### Optional skid-mode tests
- TC24 Skid Disabled Reference Behavior
- TC25 Skid Single Extra Capture
- TC26 Skid Hold And Drain Ordering
- TC27 Skid With Repeated Backpressure Pulses
- TC28 Skid Random Traffic Stress

---

## 7) Detailed Testcases

---

### TC01 Reset Default State

**Purpose**  
Verify DUT powers up or resets into a clean empty state.

**Stimulus**  
- drive `rst_n=0`
- keep `in_valid=0`
- set `out_ready` to either 0 or 1; both should be harmless during reset
- release reset after several clocks

**Checks**  
- `out_valid = 0` during/after reset until data is accepted
- no output transfer occurs
- internal occupancy is empty (`full_q=0` if visible)
- `in_ready` indicates capacity after reset release
- optional debug data registers may reset to known value for readability

**Waveform focus**  
Capture reset assertion and release with empty-state outputs.

**Expected Result**  
PASS

---

### TC02 First Accept Into Empty Slice

**Purpose**  
Verify first transaction is accepted correctly when the slice is empty.

**Stimulus**  
- after reset, drive one valid payload
- hold `out_ready=0` or delay consumer readiness so storage action is visible

**Checks**  
- input transfer only occurs when `in_valid && in_ready`
- payload is captured correctly
- `out_valid` asserts after capture behavior consistent with design timing
- stored payload matches expected value

**Waveform focus**  
Show empty-to-full transition.

**Expected Result**  
PASS

---

### TC03 First Output Transfer

**Purpose**  
Verify a stored transaction is delivered correctly to downstream.

**Stimulus**  
- preload one payload into DUT
- later assert `out_ready=1`

**Checks**  
- `out_valid` is high while transaction is pending
- output transfer occurs exactly once on handshake
- delivered payload matches first accepted payload
- stage becomes empty afterward if no refill occurs

**Waveform focus**  
Show accepted input beat and later delivered output beat.

**Expected Result**  
PASS

---

### TC04 Hold Under Downstream Stall

**Purpose**  
Prove payload and validity remain stable when consumer stalls.

**Stimulus**  
- accept one payload into DUT
- keep `out_ready=0` for multiple cycles

**Checks**  
- `out_valid` remains asserted for the entire stall interval
- `out_data` remains constant for the entire stall interval
- no unexpected output handshakes occur
- no overwrite occurs from additional input attempts in baseline mode

**Waveform focus**  
This is one of the most important screenshots.

**Expected Result**  
PASS

---

### TC05 Drain To Empty

**Purpose**  
Verify DUT returns to empty state after final pending transaction is consumed.

**Stimulus**  
- store one payload
- later allow downstream transfer
- keep upstream invalid afterwards

**Checks**  
- one and only one output transaction occurs
- `out_valid` deasserts after drain
- stage returns to empty occupancy
- no extra stale payload remains visible as a valid transaction

**Expected Result**  
PASS

---

### TC06 Bubble Then Refill

**Purpose**  
Verify empty interval (bubble) is handled cleanly before a later refill.

**Stimulus**  
- drain DUT to empty
- leave `in_valid=0` for several cycles
- then inject a new payload

**Checks**  
- no output activity during bubble
- no ghost output payloads during empty interval
- new payload is later accepted/delivered correctly

**Waveform focus**  
Show empty interval clearly between two real transactions.

**Expected Result**  
PASS

---

### TC07 Back-to-Back Throughput

**Purpose**  
Verify one-beat-per-cycle streaming behavior in steady state.

**Stimulus**  
- keep `in_valid=1` for a burst of multiple cycles
- keep `out_ready=1`
- drive a sequence of distinct payloads

**Checks**  
- input handshakes occur continuously once flow is established
- output handshakes occur continuously with correct ordering
- no dropped cycle due to incorrect consume/refill handling
- sequence integrity preserved

**Waveform focus**  
Capture 5 to 10 consecutive successful transfers.

**Expected Result**  
PASS

---

### TC08 Alternating Input Valid

**Purpose**  
Verify correct behavior with bubble injection from producer side.

**Stimulus**  
- toggle `in_valid` as 1,0,1,0,... while `out_ready=1`
- present meaningful payload only on valid cycles

**Checks**  
- only valid cycles are accepted
- bubbles are reflected correctly downstream
- accepted payload order remains correct

**Expected Result**  
PASS

---

### TC09 Alternating Output Ready

**Purpose**  
Verify correct behavior with repeated downstream backpressure pulses.

**Stimulus**  
- drive continuous or semi-continuous input valid
- toggle `out_ready` as 1,0,1,0,...

**Checks**  
- output transfers occur only on ready=1 cycles when valid is present
- payload is stable during ready=0 cycles
- order preserved across intermittent draining

**Waveform focus**  
Excellent screenshot candidate for backpressure behavior.

**Expected Result**  
PASS

---

### TC10 Simultaneous Consume And Refill

**Purpose**  
Verify same-cycle output consumption and input refill is handled correctly.

**Stimulus**  
- keep one payload resident in DUT
- on a cycle where `out_ready=1`, also drive a new valid input beat

**Checks**  
- old payload exits exactly once
- new payload enters the stage without introducing a throughput bubble
- stage stays occupied after the cycle
- no duplicate or skipped data

**Waveform focus**  
This is a key microarchitecture proof point.

**Expected Result**  
PASS

---

### TC11 Long Burst Transfer

**Purpose**  
Verify stability and accounting over a longer continuous transfer window.

**Stimulus**  
- send 16, 32, or more payloads with `out_ready=1`
- use incrementing sequence numbers

**Checks**  
- all sequence numbers arrive in order
- transfer counts match exactly
- no late mismatch after many cycles

**Expected Result**  
PASS

---

### TC12 Output Idle Behavior While Empty

**Purpose**  
Prove the slice does not pretend to hold valid data when empty.

**Stimulus**  
- keep DUT empty
- toggle `out_ready`
- keep `in_valid=0`

**Checks**  
- `out_valid=0` throughout
- no output handshakes counted
- `out_data` may be don't-care functionally, but no transfer should be inferred

**Expected Result**  
PASS

---

### TC13 Input Blocking When Full And Stalled

**Purpose**  
Verify baseline slice does not accept new data when no capacity exists.

**Stimulus**  
- fill DUT with one payload
- hold `out_ready=0`
- keep `in_valid=1` with another payload request for several cycles

**Checks**  
- second payload is not accepted in baseline mode
- first payload remains intact
- `in_ready` reflects blocked capacity condition

**Waveform focus**  
Use this to demonstrate upstream backpressure.

**Expected Result**  
PASS

---

### TC14 Repeated Same Payload Values

**Purpose**  
Ensure scoreboard and DUT do not rely on unique-value assumptions.

**Stimulus**  
- send identical numeric payload values on multiple separate handshakes

**Checks**  
- transaction counting is still correct
- no false duplication or suppression due to equal payload values

**Expected Result**  
PASS

---

### TC15 Corner Data Patterns

**Purpose**  
Verify payload storage for important bit patterns.

**Stimulus**  
Use values such as:
- all zeros
- all ones
- alternating `1010...`
- alternating `0101...`
- MSB-only set
- LSB-only set
- random values

**Checks**  
- each accepted pattern is delivered unchanged

**Expected Result**  
PASS

---

### TC16 Random Valid/Ready Throttling

**Purpose**  
Stress the protocol under many mixed producer/consumer timing combinations.

**Stimulus**  
- randomly toggle `in_valid`
- randomly toggle `out_ready`
- generate random payloads when valid is asserted
- run for hundreds of cycles

**Checks**  
- scoreboard remains clean
- no assertions fire
- counts remain balanced at end of drain

**Expected Result**  
PASS

---

### TC17 Long Stall With Persistent Upstream Requests

**Purpose**  
Stress hold semantics during extended stall windows.

**Stimulus**  
- load one payload
- hold `out_ready=0` for long interval
- keep upstream requesting additional traffic

**Checks**  
- baseline mode blocks additional acceptance
- resident payload remains stable for full stall interval
- once ready returns, pending resident payload exits first

**Expected Result**  
PASS

---

### TC18 Random Burst Length Sweep

**Purpose**  
Check sequence correctness across varying traffic burst lengths.

**Stimulus**  
- generate bursts of lengths 1, 2, 3, 4, 8, 16 with random gaps and random ready throttling

**Checks**  
- all bursts preserve ordering
- no count mismatch between accepted and delivered traffic

**Expected Result**  
PASS

---

### TC19 Reset During Held Valid

**Purpose**  
Verify reset cleanly flushes a resident transaction.

**Stimulus**  
- store a payload
- keep `out_ready=0`
- assert reset while payload is held

**Checks**  
- state returns to empty/reset condition
- previously held payload is discarded by reset semantics
- after release, DUT resumes normal operation cleanly

**Waveform focus**  
Important screenshot if you want strong reset-robustness evidence.

**Expected Result**  
PASS

---

### TC20 Reset During Streaming Traffic

**Purpose**  
Verify design behavior when reset interrupts an active sequence.

**Stimulus**  
- start continuous traffic
- assert reset mid-stream
- deassert reset and restart traffic

**Checks**  
- pre-reset accepted but not yet delivered beats are treated consistently with reset flush policy
- no post-reset stale data leakage
- new post-reset sequence begins cleanly

**Expected Result**  
PASS

---

### TC21 Recovery Immediately After Reset

**Purpose**  
Verify no dead cycle or stale blockage remains after reset release.

**Stimulus**  
- release reset
- present a valid payload immediately or within one cycle

**Checks**  
- DUT accepts and later delivers traffic normally
- `in_ready` reflects available capacity after reset

**Expected Result**  
PASS

---

### TC22 Transfer Count Accounting

**Purpose**  
Explicitly prove numerical accounting of accepted versus delivered transactions.

**Stimulus**  
- run a mixture of directed and random traffic

**Checks**  
Track:
- `accept_count`
- `deliver_count`
- scoreboard depth

At drain completion or test end after draining:
- `accept_count == deliver_count`
- scoreboard depth = 0

**Expected Result**  
PASS

---

### TC23 Assertion Stress Run

**Purpose**  
Use a long stress run mainly to validate protocol assertions.

**Stimulus**  
- long random traffic run
- aggressive toggling of valid/ready
- optional repeated resets if TB supports it clearly

**Checks**  
- no stability assertion failures
- no illegal occupancy/overwrite assertion failures
- no unexpected handshake accounting errors

**Expected Result**  
PASS

---

### TC24 Skid Disabled Reference Behavior

**Purpose**  
When `SKID_EN=0`, confirm DUT behaves exactly like baseline no-extra-buffer slice.

**Stimulus**  
- reuse TC13-style blocking scenario

**Checks**  
- no second beat accepted while main stage is full and stalled
- serves as reference comparison against skid-enabled behavior

**Expected Result**  
PASS

---

### TC25 Skid Single Extra Capture

**Purpose**  
Verify skid-enabled DUT can absorb one extra beat under backpressure.

**Stimulus**  
- enable `SKID_EN=1`
- main stage becomes full
- downstream stalls
- allow one additional input beat under intended skid capture condition

**Checks**  
- second payload is preserved in skid storage
- no overwrite of main entry
- no loss of the extra beat
- occupancy conceptually becomes two entries (main + skid)

**Waveform focus**  
Major screenshot candidate if you implement skid.

**Expected Result**  
PASS

---

### TC26 Skid Hold And Drain Ordering

**Purpose**  
Verify skid content drains in the correct order after stall release.

**Stimulus**  
- create one main entry and one skid entry
- later assert `out_ready=1`

**Checks**  
- main entry exits first
- skid entry exits second
- ordering exactly matches acceptance sequence

**Expected Result**  
PASS

---

### TC27 Skid With Repeated Backpressure Pulses

**Purpose**  
Stress skid transitions across multiple short stalls.

**Stimulus**  
- alternate downstream ready/stall while upstream continues sending

**Checks**  
- skid capture/release remains legal
- no duplicate or dropped payloads
- no illegal skid overwrite

**Expected Result**  
PASS

---

### TC28 Skid Random Traffic Stress

**Purpose**  
Close skid mode under randomized traffic.

**Stimulus**  
- `SKID_EN=1`
- long random valid/ready sequence
- random payloads

**Checks**  
- scoreboard clean
- skid assertions clean
- drain complete at end

**Expected Result**  
PASS

---

## 8) Assertion Recommendations

Recommended properties to add in TB or bind-style assertions:

### A1 - Hold valid on stall
If `out_valid && !out_ready`, then next cycle `out_valid` must remain 1 unless reset intervenes.

### A2 - Hold data on stall
If `out_valid && !out_ready`, then next cycle `out_data` must be unchanged unless reset intervenes.

### A3 - No output transfer without valid
A transfer count must never increment when `out_valid=0`.

### A4 - No scoreboard pop without handshake
Pop only on `out_valid && out_ready`.

### A5 - Optional occupancy legality
If internal occupancy tracking exists, disallow impossible states.

### A6 - Optional skid legality
Disallow skid overwrite while skid storage is already occupied.

---

## 9) Scoreboard Recommendation

Use a TB queue such as:
- push payload on accepted input
- compare and pop on delivered output

Also track:
- `accept_count`
- `deliver_count`
- max observed occupancy *(optional)*
- number of stall cycles *(optional)*

This will help you later if you want README metrics.

---

## 10) Waveform Signal List Recommendation

Top-level:
- `clk`
- `rst_n`
- `in_valid`
- `in_ready`
- `in_data`
- `out_valid`
- `out_ready`
- `out_data`

Useful internals if visible:
- `full_q`
- `data_q`
- `skid_valid_q`
- `skid_data_q`
- TB scoreboard depth
- TB accept counter
- TB deliver counter

---

## 11) Screenshot Plan

Recommended named screenshots for curated evidence:

1. `tc01_reset_default_state.png`  
2. `tc04_hold_under_stall.png`  
3. `tc06_bubble_then_refill.png`  
4. `tc07_back_to_back_throughput.png`  
5. `tc10_consume_and_refill_same_cycle.png`  
6. `tc13_input_blocking_when_full_stalled.png`  
7. `tc19_reset_during_held_valid.png`  
8. `tc25_skid_single_extra_capture.png` *(if skid enabled)*  
9. `tc26_skid_hold_and_drain_ordering.png` *(if skid enabled)*

---

## 12) Verification Status Summary Template

Use this in the file later when you begin execution:

| Testcase | Title | Status | Evidence | Notes |
|---|---|---|---|---|
| TC01 | Reset Default State | TODO |  |  |
| TC02 | First Accept Into Empty Slice | TODO |  |  |
| TC03 | First Output Transfer | TODO |  |  |
| TC04 | Hold Under Downstream Stall | TODO |  |  |
| TC05 | Drain To Empty | TODO |  |  |
| TC06 | Bubble Then Refill | TODO |  |  |
| TC07 | Back-to-Back Throughput | TODO |  |  |
| TC08 | Alternating Input Valid | TODO |  |  |
| TC09 | Alternating Output Ready | TODO |  |  |
| TC10 | Simultaneous Consume And Refill | TODO |  |  |
| TC11 | Long Burst Transfer | TODO |  |  |
| TC12 | Output Idle Behavior While Empty | TODO |  |  |
| TC13 | Input Blocking When Full And Stalled | TODO |  |  |
| TC14 | Repeated Same Payload Values | TODO |  |  |
| TC15 | Corner Data Patterns | TODO |  |  |
| TC16 | Random Valid/Ready Throttling | TODO |  |  |
| TC17 | Long Stall With Persistent Upstream Requests | TODO |  |  |
| TC18 | Random Burst Length Sweep | TODO |  |  |
| TC19 | Reset During Held Valid | TODO |  |  |
| TC20 | Reset During Streaming Traffic | TODO |  |  |
| TC21 | Recovery Immediately After Reset | TODO |  |  |
| TC22 | Transfer Count Accounting | TODO |  |  |
| TC23 | Assertion Stress Run | TODO |  |  |
| TC24 | Skid Disabled Reference Behavior | TODO |  |  |
| TC25 | Skid Single Extra Capture | TODO |  |  |
| TC26 | Skid Hold And Drain Ordering | TODO |  |  |
| TC27 | Skid With Repeated Backpressure Pulses | TODO |  |  |
| TC28 | Skid Random Traffic Stress | TODO |  |  |

---

## 13) Closure Criteria

Verification is considered complete when:
- all selected baseline tests pass
- scoreboard is clean across directed and random scenarios
- assertion set is clean
- required waveform screenshots are captured
- optional skid mode also closes if implemented
- README reflects actual verified feature set truthfully

---

## 14) Final Verification Intent Statement

The DUT should be proven not merely functional in easy cases, but robust against realistic pipeline effects: stalls, bubbles, same-cycle consume/refill, randomized throttling, reset interruption, and optional short-term elasticity through skid buffering.
