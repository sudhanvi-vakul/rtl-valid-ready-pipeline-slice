# Debug Notes - Stage 2 Valid/Ready Slice

This file records the main debug steps taken while bringing the Stage 2 valid/ready slice to a clean smoke-test pass.  
It is intentionally short and focused on what changed, whether the change helped, and what was done next.

---

## Entry 1 - Transfer count mismatch observed

**Issue**  
During integrated test execution, `TC22 Transfer Count Accounting` failed with a count mismatch:
- accepted count mismatch
- produced count mismatch
- expected value was lower than the observed value

**What this suggested**  
The DUT behavior and the testbench accounting were not aligned.  
The likely problem area was transaction counting during handshake-heavy scenarios, especially when transfers happened across multiple cycles without properly isolating testcase-local state.

**Change made**  
The first correction effort focused on the transfer-count accounting path rather than changing the whole DUT immediately.

**Was it enough?**  
No. The issue was reduced conceptually, but the failure pattern showed the problem was not fully resolved yet.

---

## Entry 2 - Repeated mismatch showed the issue was not isolated enough

**Issue**  
The same class of failure appeared again, which meant the first fix did not completely remove the source of over-counting.

**What this suggested**  
This pointed to one of these possibilities:
- counters not being reset cleanly per testcase
- counting on signal visibility rather than real handshake events
- shared integrated testbench state leaking across scenarios

**Change made**  
The debug focus shifted from only "fix the number" to "fix how events are counted and isolated."  
That was an important direction change.

**Was it okay?**  
No. Even though the test still failed at that stage, this was the correct debugging direction I guess.

---

## Entry 3 - Handshake accounting was treated as the main debug target

**Issue**  
The mismatch magnitude indicated that the testbench was very likely counting more transfer events than it should.

**Change made**  
The counting method was tightened around actual handshake conditions:
- input side should count only on accept
- output side should count only on produce
- testcase-local expectations should not inherit stale values from earlier scenarios

**Why this mattered**  
For a valid/ready block, the only trustworthy event boundary is the handshake itself.  
Anything weaker than that can inflate counts.

**Was it enough?**  
It moved the debug in the right direction, but further cleanup was still needed before the smoke run closed.

---

## Entry 4 - Integrated testbench structure became part of the problem statement

**Issue**  
Because the project was using one broad integrated testbench, debug became harder:
- many scenarios were sharing infrastructure
- counters and state could affect later checks
- isolating one failing behavior took longer than it should

**Change made**  
Instead of treating the integrated testbench as the only solution, it was re-framed as:
- useful for broad regression coverage
- not ideal as the only verification vehicle

This directly motivated the advanced-version plan:
- separate directed tests
- dedicated skid regression
- clearer assertion-based checking
- width-specific sanity runs

**Was this change okay?**  
Yes. This was a structural improvement, not just a local patch.

---

## Entry 5 - Smoke-test path stabilized

**Issue**  
After the earlier count-accounting failures, the main question was whether the project could return to a clean baseline run.

**Change made**  
The debug effort prioritized getting the smoke path stable again before layering more advanced features.

**Result**  
The smoke test passed.

**Interpretation**  
This confirmed that the current baseline implementation was stable enough to move forward.

**Was it final closure?**  
Not full advanced closure.  
It was a good baseline pass, and after that the next step became hardening the design rather than basic rescue.

---

## Entry 6 - What changed after smoke passed

Once smoke passed, the next decisions were no longer emergency fixes.  
They became design-quality upgrades:
- add separate directed tests instead of relying only on one integrated TB
- add handshake stability assertions
- add skid-enabled regression
- add `DATA_W` sweep support
- add optional occupancy/debug visibility

These were not added because the project was broken.  
They were added because the debug experience showed exactly where the design and verification flow needed to become more reusable and more industrial.

---

## Entry 7 - Final debug conclusion

The main smoke-test issue was not just a random failure.  
It exposed an important lesson:

A flow-control block can look functionally correct in waveforms and still fail if transaction accounting and testcase isolation are weak.

The final outcome was:
- baseline smoke restored
- debug direction validated
- advanced verification improvements justified
- Stage 2 ready to move from "working" to "reusable"

---

## Short status summary

| Phase | Main Observation | Change | Outcome |
|---|---|---|---|
| Initial debug | TC22 count mismatch | Investigated transfer counting | Not enough |
| Second pass | Failure repeated | Focus shifted to handshake-based counting | Better direction |
| TB review | Integrated TB made isolation harder | Planned directed-test split | Good structural decision |
| Baseline recovery | Smoke path prioritized | Cleanup and stabilization | Smoke passed |
| Post-recovery | Project stable again | Planned advanced enhancements | Ready for next phase |
