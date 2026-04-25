import argparse
import time
import yaml
import sys
from pathlib import Path

from scripts.run import _collect_sources, _normalize_defines, _normalize_plusargs
from scripts.adapters.xsim import run_xsim


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
    outroot.mkdir(parents=True, exist_ok=True)

    results = []
    aggregate_log = []

    for t in tests:
        name = t["name"]
        top = t.get("top", "{}_tb".format(name))
        sources = _collect_sources(t)
        defines = _normalize_defines(t.get("defines"))
        plusargs = _normalize_plusargs(t.get("plusargs"))

        test_outdir = outroot / name
        test_outdir.mkdir(parents=True, exist_ok=True)

        aggregate_log.append("============================================================")
        aggregate_log.append("[REGRESS] Running test: {}".format(name))
        aggregate_log.append("[REGRESS] Top: {}".format(top))
        aggregate_log.append("============================================================")

        rc = 0

        try:
            if args.tool == "xsim":
                run_xsim(
                    top=top,
                    sources=sources,
                    outdir=str(test_outdir),
                    waves=args.waves,
                    defines=defines,
                    plusargs=plusargs,
                )
        except SystemExit as e:
            rc = int(e.code) if isinstance(e.code, int) else 1
        except Exception as e:
            rc = 1
            aggregate_log.append("[ERROR] {} failed with exception: {}".format(name, e))

        test_log = test_outdir / "xsim.log"
        if test_log.exists():
            aggregate_log.append(test_log.read_text(encoding="utf-8", errors="ignore"))
        else:
            aggregate_log.append("[ERROR] Missing xsim.log for {}".format(name))
            rc = 1

        status = "PASS" if rc == 0 else "FAIL"
        aggregate_log.append("[{}] {}".format(status, name))

        results.append(
            {
                "name": name,
                "top": top,
                "rc": rc,
                "status": status,
                "outdir": str(test_outdir).replace("\\", "/"),
            }
        )

    failed = [r for r in results if r["rc"] != 0]

    (outroot / "results.yaml").write_text(
        yaml.safe_dump(
            {
                "run_id": run_id,
                "suite": args.suite,
                "tool": args.tool,
                "waves": args.waves,
                "results": results,
                "failed": failed,
            },
            sort_keys=False,
        ),
        encoding="utf-8",
    )

    (outroot / "xsim.log").write_text(
        "\n".join(aggregate_log),
        encoding="utf-8",
        errors="ignore",
    )

    print("[ok] regress finished: {}".format(outroot))

    if failed:
        print("[fail] {} test(s) failed".format(len(failed)))
        for r in failed:
            print("  - {}".format(r["name"]))
        sys.exit(1)

    print("[pass] all {} test(s) passed".format(len(results)))


if __name__ == "__main__":
    main()