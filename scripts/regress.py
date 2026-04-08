import argparse
import time
import yaml
import subprocess
import sys
from pathlib import Path


def _run(cmd, cwd=None):
    return subprocess.run(
        cmd,
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tool", default="xsim", choices=["xsim"])
    ap.add_argument("--suite", default="smoke")
    ap.add_argument("--waves", action="store_true")
    args = ap.parse_args()

    with open("tests.yaml", "r") as f:
        cfg = yaml.safe_load(f) or {}

    tests = cfg.get(args.suite, [])
    if not tests:
        raise SystemExit("No tests found for suite '{}'".format(args.suite))

    run_id = time.strftime("run_%Y%m%d_%H%M%S")
    outroot = Path("reports") / run_id
    (outroot / "logs").mkdir(parents=True, exist_ok=True)

    results = []

    for t in tests:
        name = t["name"]
        log = outroot / "logs" / "{}.log".format(name)

        cmd = [
            sys.executable,
            "-m",
            "scripts.run",
            "--tool",
            args.tool,
            "--suite",
            args.suite,
            "--test",
            name,
        ]
        if args.waves:
            cmd.append("--waves")

        r = _run(cmd)

        text = ""
        if r.stdout:
            text += r.stdout
        if r.stderr:
            if text and not text.endswith("\n"):
                text += "\n"
            text += r.stderr

        log.write_text(text, encoding="utf-8", errors="ignore")

        results.append(
            {
                "name": name,
                "rc": r.returncode,
                "log": str(log).replace("\\", "/"),
            }
        )

    (outroot / "results.yaml").write_text(
        yaml.safe_dump(
            {
                "run_id": run_id,
                "suite": args.suite,
                "tool": args.tool,
                "results": results,
            },
            sort_keys=False,
        ),
        encoding="utf-8",
    )

    print("[ok] regress finished: {}".format(outroot))


if __name__ == "__main__":
    main()
