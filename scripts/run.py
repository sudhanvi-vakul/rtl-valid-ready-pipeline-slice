import argparse
import time
import yaml
from pathlib import Path

from scripts.adapters.xsim import run_xsim


def _normalize_defines(raw):
    if raw is None:
        return []

    if isinstance(raw, dict):
        out = []
        for k, v in raw.items():
            if v is None or v is True:
                out.append(str(k))
            else:
                out.append("{}={}".format(k, v))
        return out

    if isinstance(raw, list):
        return [str(x) for x in raw]

    return [str(raw)]


def _normalize_plusargs(raw):
    if raw is None:
        return []

    if isinstance(raw, dict):
        out = []
        for k, v in raw.items():
            if v is None or v is True:
                out.append(str(k).lstrip("+"))
            else:
                out.append("{}={}".format(str(k).lstrip("+"), v))
        return out

    if isinstance(raw, list):
        return [str(x).lstrip("+") for x in raw]

    return [str(raw).lstrip("+")]


def _collect_sources(selected):
    sources = selected.get("sources")
    if sources:
        return list(sources)

    out = []

    for key in ["rtl", "tb", "files"]:
        value = selected.get(key)
        if not value:
            continue

        if isinstance(value, list):
            out.extend(str(x) for x in value)
        else:
            out.append(str(value))

    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tool", default="xsim", choices=["xsim"])
    ap.add_argument("--suite", default="smoke")
    ap.add_argument("--test", required=True)
    ap.add_argument("--waves", action="store_true")
    args = ap.parse_args()

    with open("tests.yaml", "r") as f:
        cfg = yaml.safe_load(f) or {}

    tests = cfg.get(args.suite, [])
    selected = None
    for t in tests:
        if t.get("name") == args.test:
            selected = t
            break

    if selected is None:
        raise SystemExit(
            "Test '{}' not found in suite '{}'".format(args.test, args.suite)
        )

    top = selected.get("top", "{}_tb".format(args.test))
    sources = _collect_sources(selected)
    if not sources:
        raise SystemExit(
            "Test '{}' is missing sources in tests.yaml "
            "(supported keys: sources, rtl, tb, files)".format(args.test)
        )

    defines = _normalize_defines(selected.get("defines"))
    plusargs = _normalize_plusargs(selected.get("plusargs"))

    run_id = time.strftime("run_%Y%m%d_%H%M%S")
    outdir = Path("reports") / run_id
    outdir.mkdir(parents=True, exist_ok=True)

    run_info = {
        "run_id": run_id,
        "suite": args.suite,
        "test": args.test,
        "tool": args.tool,
        "top": top,
        "waves": args.waves,
        "sources": sources,
        "defines": defines,
        "plusargs": plusargs,
    }

    (outdir / "run_info.yaml").write_text(
        yaml.safe_dump(run_info, sort_keys=False),
        encoding="utf-8",
    )

    if args.tool == "xsim":
        run_xsim(
            top=top,
            sources=sources,
            outdir=str(outdir),
            waves=args.waves,
            defines=defines,
            plusargs=plusargs,
        )

    print("[ok] reports saved to {}".format(outdir))


if __name__ == "__main__":
    main()
