import argparse
import re
import yaml
from pathlib import Path
from datetime import datetime


PASS_RE = re.compile(r"\b(TB PASS|PASS|\[PASS\])\b", re.IGNORECASE)
FAIL_RE = re.compile(r"\b(TB FAIL|FAIL|ERROR|MISMATCH|ASSERT|FATAL)\b", re.IGNORECASE)


def read_yaml(path):
    if path.exists():
        return yaml.safe_load(path.read_text(encoding="utf-8", errors="ignore")) or {}
    return {}


def classify_log(log_text):
    if FAIL_RE.search(log_text):
        return "FAIL"
    if PASS_RE.search(log_text):
        return "PASS"
    return "UNKNOWN"


def get_test_name(run_dir):
    run_info = read_yaml(run_dir / "run_info.yaml")
    if run_info.get("test"):
        return run_info["test"]

    results = read_yaml(run_dir / "results.yaml")
    if results.get("test"):
        return results["test"]

    # Fallback if no metadata file exists
    return run_dir.name


def summarize_reports(reports_dir):
    reports_dir = Path(reports_dir)
    rows = []

    # Summarize every folder inside reports/ whose name starts with "run"
    for run_dir in sorted(reports_dir.glob("run*")):
        if not run_dir.is_dir():
            continue

        log_path = run_dir / "xsim.log"
        if not log_path.exists():
            continue

        log_text = log_path.read_text(encoding="utf-8", errors="ignore")
        test_name = get_test_name(run_dir)
        status = classify_log(log_text)

        rows.append(
            {
                "test": test_name,
                "status": status,
                "run_dir": str(run_dir).replace("\\", "/"),
                "log": str(log_path).replace("\\", "/"),
            }
        )

    return rows


def write_markdown(rows, out_path):
    total = len(rows)
    passed = sum(1 for r in rows if r["status"] == "PASS")
    failed = sum(1 for r in rows if r["status"] == "FAIL")
    unknown = sum(1 for r in rows if r["status"] == "UNKNOWN")

    lines = []
    lines.append("# Consolidated Regression Summary")
    lines.append("")
    lines.append(f"Generated: {datetime.now().isoformat(timespec='seconds')}")
    lines.append("")
    lines.append("## Totals")
    lines.append("")
    lines.append(f"- Total run folders summarized: {total}")
    lines.append(f"- Passed: {passed}")
    lines.append(f"- Failed: {failed}")
    lines.append(f"- Unknown: {unknown}")
    lines.append("")
    lines.append("## Results")
    lines.append("")
    lines.append("| Test | Status | Run Directory | Log |")
    lines.append("|---|---|---|---|")

    for r in rows:
        lines.append(
            f"| {r['test']} | {r['status']} | `{r['run_dir']}` | `{r['log']}` |"
        )

    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reports-dir", default="reports")
    ap.add_argument("--out", default="reports/regression_summary.md")
    ap.add_argument("--yaml-out", default="reports/regression_summary.yaml")
    args = ap.parse_args()

    rows = summarize_reports(args.reports_dir)

    out_path = Path(args.out)
    yaml_out_path = Path(args.yaml_out)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    yaml_out_path.parent.mkdir(parents=True, exist_ok=True)

    write_markdown(rows, out_path)

    yaml_out_path.write_text(
        yaml.safe_dump({"results": rows}, sort_keys=False),
        encoding="utf-8",
    )

    print(f"[ok] wrote {out_path}")
    print(f"[ok] wrote {yaml_out_path}")

    if not rows:
        print("[warn] no run folders with xsim.log found")

    failed = [r for r in rows if r["status"] == "FAIL"]
    if failed:
        print("[fail] failing runs detected:")
        for r in failed:
            print(f"  - {r['test']} : {r['run_dir']}")


if __name__ == "__main__":
    main()