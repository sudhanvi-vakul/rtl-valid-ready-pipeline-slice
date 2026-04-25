# Debug Notes - Stage 2 Valid/Ready Slice

This file records the major debug steps taken while stabilizing and hardening the Stage 2 valid/ready slice.  
It focuses on what went wrong, what was changed, why the change mattered, and what the outcome was.

---

## Entry 1 - Transfer count mismatch exposed a verification weakness

**Issue**  
During integrated test execution, `TC22 Transfer Count Accounting` failed with a count mismatch:
- accepted count mismatch
- produced count mismatch
- expected value was lower than the observed value

**What this suggested**  
The failure did not immediately point to a broken DUT datapath.  
It suggested that the DUT behavior and the testbench accounting were not aligned, especially in handshake-heavy scenarios where multiple transfers could occur across different cycles.

**Change made**  
The initial debug effort focused on the transfer-count accounting path rather than changing the DUT blindly.

**Was it enough?**  
No.  
The failure pattern showed that the underlying source of over-counting had not been fully removed.

---

## Entry 2 - Repeated failure showed the issue was not isolated enough

**Issue**  
The same class of mismatch appeared again after the first correction attempt.

**What this suggested**  
This pointed to one or more structural verification issues:
- counters were not being reset cleanly per testcase
- counting may have been based on signal visibility rather than true handshakes
- shared integrated testbench state may have been leaking across scenarios

**Change made**  
The debug focus shifted from only fixing the observed numbers to fixing how transfers were counted and how testcase-local state was isolated.

**Why this mattered**  
That changed the effort from a local patch into a methodology correction.

**Was it enough?**  
Not yet.  
But it was the correct debugging direction.

---

## Entry 3 - Handshake-based accounting became the main correction

**Issue**  
The mismatch magnitude suggested that the testbench was very likely counting more events than it should.

**Change made**  
The checking model was tightened around true handshake events:
- input-side counting only on accept
- output-side counting only on produce
- testcase-local expectations cleared between scenarios
- expected data comparison tied only to real output transfers

**Why this mattered**  
For a valid/ready block, the handshake is the only reliable transaction boundary.  
Anything weaker can inflate counts and make a good DUT look wrong.

**Outcome**  
This improved trust in the scoreboard and the transfer accounting, although additional cleanup was still needed before the baseline run fully stabilized.

---

## Entry 4 - The integrated testbench itself became part of the debug problem

**Issue**  
Because the project was relying heavily on one broad integrated testbench, debug became harder than it should have been:
- many scenarios shared the same infrastructure
- counters and scoreboard state could affect later checks
- isolating one failing behavior took longer than necessary

**What this suggested**  
The project needed stronger testcase separation and clearer verification structure, not just local fixes.

**Change made**  
The verification strategy was reframed:
- keep the integrated TB for broad regression value
- stop treating it as the only verification vehicle
- move toward separate directed groups and dedicated wrappers

This directly motivated later additions such as:
- directed testcase grouping
- dedicated skid-focused runs
- clearer assertion-based checking
- width-focused sanity support
- debug/occupancy visibility support

**Outcome**  
This was a structural improvement that made later debug and closure much easier to reason about.

---

## Entry 5 - Simultaneous consume-and-refill behavior was strengthened explicitly

**Issue**  
At one stage, it became clear that simultaneous consume-and-refill behavior was not being checked strongly enough.

For a valid/ready slice, it is important to prove correct behavior when:
- one beat is consumed
- another beat is accepted in the same cycle or immediate transfer window
- no bubble, duplication, or loss is introduced

**Change made**  
The verification flow was strengthened with an explicit dedicated testcase for simultaneous consume-and-refill behavior.

**Why this mattered**  
This is a core expectation for a pipeline slice.  
It should be proven directly rather than assumed from simpler fill-and-drain runs.

**Outcome**  
The project gained stronger protocol coverage and a more realistic flow-control verification story.

---

## Entry 6 - Baseline smoke recovery was prioritized before further expansion

**Issue**  
After the earlier count-accounting failures, the key question became whether the project could return to a clean and stable baseline run.

**Change made**  
The immediate priority became restoring a reliable smoke path before layering additional advanced verification features.

**Result**  
The smoke test passed.

**Interpretation**  
This showed that the baseline implementation was stable enough to move forward.

**Was it final closure?**  
No.  
This was baseline recovery, not full advanced closure.

---

## Entry 7 - Skid-path verification became a major hardening step

**Issue**  
Once the baseline slice behavior stabilized, the next challenge was verifying the optional skid path thoroughly.

The project would not be strong enough with only:
- simple empty and drain checks
- basic forward movement
- non-skid baseline behavior

**Change made**  
Verification was extended to cover:
- skid-disabled reference behavior
- single extra capture in skid mode
- hold and drain ordering through the skid path
- repeated backpressure pulses
- random skid stress
- skid-on versus skid-off comparison scenarios

**Why this mattered**  
The skid path is where flow-control corner cases become more subtle:
- extra storage
- ordering preservation
- stall interaction
- occupancy interpretation

**Outcome**  
This made the project much more robust and much more representative of real protocol verification work.

---

## Entry 8 - Assertions, debug visibility, and width-focused checks improved reuse

**Issue**  
Waveform review and directed tests were useful, but they were not enough by themselves for a reusable and explainable verification flow.

**Change made**  
The project was hardened with:
- assertion-based checking for protocol correctness
- optional debug visibility for accept, produce, hold, skid-active, and occupancy behavior
- width-focused sanity support and dedicated width-oriented checks

**Why this mattered**  
These changes improved both debug quality and project explainability:
- assertions helped catch protocol mistakes earlier
- debug signals made internal behavior easier to validate
- width-focused checks reduced the risk of relying only on one default configuration

**Outcome**  
The project moved from merely working toward being reusable, explainable, and portfolio-ready.

---

## Entry 9 - Final debug lesson

The main smoke-test issue was not just a random failing testcase.  
It exposed a deeper lesson:

A flow-control block can look functionally correct in waveforms and still fail if transaction accounting, testcase isolation, and verification structure are weak.

The final outcome of the debug cycle was:
- baseline smoke restored
- handshake-based accounting validated
- testcase isolation improved
- simultaneous transfer coverage strengthened
- skid-path verification deepened
- assertions and debug visibility added
- Stage 2 moved from "working" toward "reusable"

---

## Short status summary

| Phase | Main Observation | Change | Outcome |
|---|---|---|---|
| Initial debug | TC22 transfer-count mismatch exposed weak testcase-local accounting | Investigated transfer counting and scoreboard behavior | Not enough |
| Second pass | Failure repeated, showing event counting was still not isolated correctly | Tightened counting around true handshake events only | Better direction |
| Verification review | One broad integrated TB made scenario isolation and debug slower | Shifted toward clearer directed groups and cleaner testcase separation | Good structural decision |
| Functional coverage gap | Simultaneous consume-and-refill behavior was not being checked explicitly enough | Strengthened coverage with a dedicated testcase | Protocol coverage improved |
| Baseline recovery | Main goal became restoring a clean stable path before further upgrades | Prioritized cleanup and stabilization of the smoke path | Smoke passed |
| Flow-control hardening | Baseline checks were not enough to justify skid behavior confidently | Expanded verification to include skid-disabled reference, skid capture, ordering, and backpressure scenarios | More industrial verification story |
| Hardening phase | Project was working, but not yet reusable or explainable enough | Added assertions, debug visibility, and width-focused checks | Ready for advanced closure |
| Post-recovery | Project stable again after the main debug cycle | Planned structured advanced verification instead of ad hoc patching | Ready for next phase |