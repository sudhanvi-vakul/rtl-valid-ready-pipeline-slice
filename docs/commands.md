# Commands

## Environment
Server: Nobel  
Shell for tool setup: `csh` / `tcsh`  
Primary simulator: XSim (Vivado 2019.2)  
Wave viewer: XSim GUI  

## Example repo location
`/home/vsudhanvi/rtl-valid-ready-pipeline-slice`

---

## Tool setup on Nobel

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

## Go to repo
```csh
cd /home/vsudhanvi/rtl-valid-ready-pipeline-slice
pwd
ls
```

---

## Initialize this project from your local template repo

```bat
cd C:\Users\sudha\Documents
robocopy rtl-productivity-cicd-toolkit rtl-valid-ready-pipeline-slice /E
cd rtl-valid-ready-pipeline-slice
```

### If you want a fresh git history after copying
Run these from the parent folder first:

```bat
cd C:\Users\sudha\Documents
rmdir /S /Q rtl-valid-ready-pipeline-slice\.git
cd rtl-valid-ready-pipeline-slice
git init
git add .
git commit -m "Initialize valid-ready pipeline register slice project"
git branch -M main
git remote add origin https://github.com/sudhanvi-vakul/rtl-valid-ready-pipeline-slice.git
```

### If the GitHub repo already contains starter content
```bat
git push -u origin main --force-with-lease
```

---

## Smoke run

### Main smoke command
```csh
python3 -m scripts.run --tool xsim --suite smoke --test vr_slice --waves
```
---

## Regression run

### Full suite
```csh
python3 -m scripts.run --tool xsim --suite regress --test vr_slice --waves
```

### If using a dedicated regression wrapper
```csh
python3 -m scripts.regress --tool xsim --suite regress
```

---

## Scan log for testcase summary and failures
```csh
grep -nE "TC[0-9][0-9]|PASS|FAIL|ERROR|MISMATCH|ASSERT" $latest/xsim.log
```

---


## Open waveform GUI
```csh
xsim $latest/work.sim.wdb &
```

### Alternative explicit GUI form
```csh
xsim $latest/work.sim.wdb -gui &
```

---


## Copy selected logs into curated evidence
```csh
cp $latest/xsim.log evidence/logs/
```

### If you want testcase-specific naming later
```csh
cp $latest/xsim.log evidence/logs/tc04_hold_under_stall.log
```

---

## Search for important scenarios in the log
```csh
grep -n "TC04 Hold Under Downstream Stall" $latest/xsim.log
grep -n "TC10 Simultaneous Consume And Refill" $latest/xsim.log
grep -n "TC25 Skid Single Extra Capture" $latest/xsim.log
```

---

## Rerun after a code change
```csh
git status
python3 -m scripts.run --tool xsim --suite smoke --test vr_slice --waves
set latest=`ls -td reports/run_* | head -1`
grep -nE "PASS|FAIL|ERROR|MISMATCH|ASSERT" $latest/xsim.log
```

---


## Optional manual compile flow (debug only)

Use this only when you want direct XSim debugging outside the wrapper flow.

```csh
mkdir -p reports/manual_debug
xvlog -sv rtl/vr_slice.sv tb/vr_slice_integrated_tb.sv
xelab vr_slice_integrated_tb -s vr_slice_dbg
xsim vr_slice_dbg -gui
```

Note: keep the Python wrapper as the official project flow for reproducibility.

---

