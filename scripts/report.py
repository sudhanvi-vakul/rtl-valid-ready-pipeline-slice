import argparse, yaml
from pathlib import Path
from datetime import datetime

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dir", help="reports/run_<id>")
    args = ap.parse_args()

    run_dir = Path(args.run_dir)
    results_path = run_dir / "results.yaml"
    triage_path = run_dir / "triage.yaml"

    if not results_path.exists():
        raise SystemExit(f"Missing {results_path}")
    if not triage_path.exists():
        raise SystemExit(f"Missing {triage_path}")

    results = yaml.safe_load(results_path.read_text()) or {}
    triage = yaml.safe_load(triage_path.read_text()) or {}
    tri = {x["test"]: x for x in triage.get("triage", [])}

    lines = []
    lines.append(f"# Regression Summary — {results.get('run_id','')}")
    lines.append("")
    lines.append(f"- Date: {datetime.now().isoformat(timespec='seconds')}")
    lines.append(f"- Tool: {results.get('tool','')}")
    lines.append(f"- Suite: {results.get('suite','')}")
    lines.append("")
    lines.append("| Test | Return Code | Classification | Log |")
    lines.append("|---|---:|---|---|")

    for r in results.get("results", []):
        name = r["name"]
        rc = r["rc"]
        cls = tri.get(name, {}).get("classification", "UNKNOWN")
        log = r["log"]
        lines.append(f"| {name} | {rc} | {cls} | `{log}` |")

    out = run_dir / "summary.md"
    out.write_text("\n".join(lines) + "\n")
    print(f"[ok] wrote {out}")

if __name__ == "__main__":
    main()
