import sys
import yaml
from pathlib import Path


def classify_result(rc, text):
    if rc == 0:
        return "PASS"

    t = text.upper()

    if "ASSERT" in t:
        return "ASSERTION_FAIL"
    if "ERROR:" in t:
        return "TOOL_ERROR"
    if "FATAL" in t:
        return "FATAL"
    if "FAIL" in t:
        return "TEST_FAIL"

    return "FAIL_UNKNOWN"


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python -m scripts.triage <run_dir>")

    run_dir = Path(sys.argv[1])
    results_yaml = run_dir / "results.yaml"

    if not results_yaml.exists():
        raise SystemExit("Missing {}".format(results_yaml))

    data = yaml.safe_load(results_yaml.read_text()) or {}
    results = data.get("results", [])

    triage = []

    for r in results:
        name = r.get("name", "unknown")
        rc = r.get("rc", 1)
        log_path = Path(r.get("log", ""))

        text = ""
        if log_path.exists():
            text = log_path.read_text(encoding="utf-8", errors="ignore")

        classification = classify_result(rc, text)

        triage.append(
            {
                "test": name,
                "classification": classification,
                "rc": rc,
                "log": str(log_path).replace("\\", "/"),
            }
        )

    out = {"triage": triage}
    out_path = run_dir / "triage.yaml"
    out_path.write_text(
        yaml.safe_dump(out, sort_keys=False),
        encoding="utf-8",
    )

    print("[ok] wrote {}".format(out_path))


if __name__ == "__main__":
    main()
