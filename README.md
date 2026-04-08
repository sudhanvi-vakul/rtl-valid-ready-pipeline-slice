# RTL Productivity + CI/CD Toolkit

A small Stage 0 backbone for RTL projects.  
This repository provides a repeatable structure for smoke runs, regressions, log capture, triage, and summary generation using Vivado XSIM as the baseline simulator.

## Purpose

The goal of this repository is to stop treating RTL work like loose files and shell history.  
Instead, it creates a reusable execution flow with:

- a predictable repo structure
- one-command smoke runs
- saved logs and wave databases
- regression entry points
- triage classification
- summary report generation

This repo is intended to serve as the **Stage 0 backbone** for later RTL projects such as CDC/reset, NSoC integration, low-power layering, and accelerator integration.

## Current status

Implemented today:

- baseline simulator flow using **Vivado 2019.2 XSIM**
- smoke test execution through `scripts.run`
- regression execution through `scripts.regress`
- saved artifacts under `reports/run_<timestamp>/`
- triage generation through `scripts.triage`
- markdown summary generation through `scripts.report`

Current smoke design:

- `rtl/hello.sv`
- `tb/hello_tb.sv`

## Repository structure

```text
rtl-productivity-cicd-toolkit/
├── README.md
├── requirements.txt
├── tests.yaml
├── rtl/
├── tb/
├── scripts/
│   ├── run.py
│   ├── regress.py
│   ├── triage.py
│   ├── report.py
│   └── adapters/
├── docs/
├── reports/
├── evidence/
├── tests/
├── tools/
└── ci/
