# Commands

## Environment
Server: Nobel  
Shell for tool setup: `csh` / `tcsh`  
Primary simulator: XSim (Vivado 2019.2)  
Wave viewer: XSim GUI  

## Recommended repo name
`rtl-valid-ready-pipeline-slice`

## Example repo location
`/home/vsudhanvi/rtl-valid-ready-pipeline-slice`

---

## 1) Tool setup on Nobel

### Enter csh/tcsh first
```csh
csh
source /import/scripts/cadtools_new.cshrc
rehash
```

### Confirm tools
```csh
which xvlog
which xelab
which xsim
python3 --version
```

---

## 2) Go to repo
```csh
cd /home/vsudhanvi/rtl-valid-ready-pipeline-slice
pwd
ls
```

---

## 3) Git basics

### Check branch and status
```csh
git rev-parse --abbrev-ref HEAD
git status
git log --oneline -n 5
```

### Add and commit docs/RTL changes
```csh
git add README.md docs rtl tb tests.yaml
git commit -m "Add Stage 2 valid-ready register slice docs and initial structure"
```

### Push
```csh
git push origin <branch-name>
```

---

## 4) Smoke run

### Main smoke command
```csh
python3 -m scripts.run --tool xsim --suite smoke --test vr_slice --waves
```

### If your test registration name differs
Examples:
```csh
python3 -m scripts.run --tool xsim --suite smoke --test regslice --waves
python3 -m scripts.run --tool xsim --suite smoke --test valid_ready_slice --waves
```

---

## 5) Regression run

### Full suite
```csh
python3 -m scripts.run --tool xsim --suite regress --test vr_slice --waves
```

### If using a dedicated regression wrapper
```csh
python3 -m scripts.regress --tool xsim --suite regress
```

---

## 6) Find latest report folder
```csh
set latest=`ls -td reports/run_* | head -1`
echo $latest
```

---

## 7) Inspect generated artifacts
```csh
find $latest -maxdepth 2 -type f | sort
```

---

## 8) Scan log for testcase summary and failures
```csh
grep -nE "TC[0-9][0-9]|PASS|FAIL|ERROR|MISMATCH|ASSERT" $latest/xsim.log
```

### Show last 80 log lines
```csh
tail -80 $latest/xsim.log
```

---

## 9) Find waveform database
```csh
find $latest -name "*.wdb"
```

---

## 10) Open waveform GUI
```csh
xsim $latest/work.sim.wdb &
```

### Alternative explicit GUI form
```csh
xsim $latest/work.sim.wdb -gui &
```

---

## 11) Check GUI / DISPLAY
```csh
echo $DISPLAY
ps -u $USER | grep xsim | grep -v grep
```

---

## 12) Save curated waveform config

After arranging signals in GUI, save the `.wcfg` into your repo evidence folder.

Suggested path:
```text
evidence/waveforms/vr_slice_debug.wcfg
```

---

## 13) Suggested screenshot evidence folder
```csh
mkdir -p evidence/screenshots
mkdir -p evidence/waveforms
mkdir -p evidence/logs
```

---

## 14) Copy selected logs into curated evidence
```csh
cp $latest/xsim.log evidence/logs/
```

### If you want testcase-specific naming later
```csh
cp $latest/xsim.log evidence/logs/tc04_hold_under_stall.log
```

---

## 15) Search for your important scenarios in log
```csh
grep -n "TC04 Hold Under Downstream Stall" $latest/xsim.log
grep -n "TC10 Simultaneous Consume And Refill" $latest/xsim.log
grep -n "TC25 Skid Single Extra Capture" $latest/xsim.log
```

---

## 16) Rerun after code change
```csh
git status
python3 -m scripts.run --tool xsim --suite smoke --test vr_slice --waves
set latest=`ls -td reports/run_* | head -1`
grep -nE "PASS|FAIL|ERROR|MISMATCH|ASSERT" $latest/xsim.log
```

---

## 17) Cleanly inspect report directories
```csh
ls reports
ls -td reports/run_* | head
```

---

## 18) Optional manual compile flow (debug only)

Use only if you want direct XSim debugging outside wrapper flow.

```csh
mkdir -p reports/manual_debug
xvlog -sv rtl/vr_slice.sv tb/vr_slice_integrated_tb.sv
xelab vr_slice_integrated_tb -s vr_slice_dbg
xsim vr_slice_dbg -gui
```

Note: keep the Python wrapper as the official project flow for reproducibility.

---

## 19) Useful file checks

### Show docs
```csh
ls docs
sed -n '1,120p' docs/design_notes.md
sed -n '1,120p' docs/verification_notes.md
```

### Show test registration
```csh
sed -n '1,200p' tests.yaml
```

---

## 20) Check for accidental generated junk before commit
```csh
find . -maxdepth 2 \( -name "*.jou" -o -name "*.pb" -o -name "xsim.dir" -o -name "*.wdb" \)
```

---

## 21) Example curated commit flow
```csh
git add README.md docs/design_notes.md docs/verification_notes.md docs/commands.md
git add rtl tb tests.yaml
git add evidence/waveforms/*.wcfg
git add evidence/screenshots/*.png
git add evidence/logs/*.log
git status
git commit -m "Stage 2 docs, RTL, and initial verification evidence"
```

---

## 22) Branch creation for Stage 2
```csh
git checkout -b stage2-valid-ready-slice
```

---

## 23) Clone Stage 0 backbone into new Stage 2 repo

### On server
```csh
cd /home/vsudhanvi
git clone <your-stage0-repo-url> rtl-valid-ready-pipeline-slice
cd rtl-valid-ready-pipeline-slice
```

### Remove old project-specific RTL/TB if needed and keep backbone infra
```csh
rm -rf rtl/*
rm -rf tb/*
```

Then add Stage 2 files.

---

## 24) Quick daily restart sequence
```csh
csh
source /import/scripts/cadtools_new.cshrc
rehash
cd /home/vsudhanvi/rtl-valid-ready-pipeline-slice
git status
python3 -m scripts.run --tool xsim --suite smoke --test vr_slice --waves
set latest=`ls -td reports/run_* | head -1`
grep -nE "PASS|FAIL|ERROR|MISMATCH|ASSERT" $latest/xsim.log
```

---

## 25) Notes

- use XSim as the stable baseline because that is already proven in your flow
- keep Python wrapper execution as the official path
- save only curated evidence, not all generated runs, unless intentionally needed
- update this file with your real testcase names once the TB is finalized
