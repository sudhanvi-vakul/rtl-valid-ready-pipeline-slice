import shutil
import subprocess
from pathlib import Path
from typing import List, Optional


def _run_logged(
    cmd: List[str],
    log_path: Path,
    cwd: Optional[Path] = None,
) -> None:
    print("[cmd]", " ".join(cmd))

    result = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )

    text = ""
    if result.stdout:
        text += result.stdout
    if result.stderr:
        if text and not text.endswith("\n"):
            text += "\n"
        text += result.stderr

    log_path.write_text(text, encoding="utf-8", errors="ignore")

    if result.returncode != 0:
        raise RuntimeError(
            "Command failed with return code {}. See log: {}".format(
                result.returncode, log_path
            )
        )


def run_xsim(
    top: str,
    sources: List[str],
    outdir: str,
    waves: bool = False,
    defines: Optional[List[str]] = None,
    plusargs: Optional[List[str]] = None,
) -> None:
    out = Path(outdir).resolve()
    out.mkdir(parents=True, exist_ok=True)

    repo = Path(__file__).resolve().parents[2]
    abs_sources = [str((repo / s).resolve()) for s in sources]

    xvlog = shutil.which("xvlog")
    xelab = shutil.which("xelab")
    xsim = shutil.which("xsim")

    if not (xvlog and xelab and xsim):
        raise RuntimeError(
            "XSIM not found (need xvlog/xelab/xsim in PATH). "
            "Source your Vivado/cadtools script first."
        )

    defines = defines or []
    plusargs = plusargs or []

    compile_log = out / "compile.log"
    elab_log = out / "elab.log"
    sim_log = out / "sim.log"
    tcl = out / "run.tcl"

    define_args = []
    for d in defines:
        define_args.extend(["-d", d])

    _run_logged(
        [xvlog, "-sv"] + define_args + abs_sources,
        log_path=compile_log,
        cwd=out,
    )

    _run_logged(
        [xelab, "-debug", "typical", top, "-snapshot", "work.sim"],
        log_path=elab_log,
        cwd=out,
    )

    if waves:
        tcl_contents = "log_wave -r /\nrun all\nquit\n"
    else:
        tcl_contents = "run all\nquit\n"

    tcl.write_text(tcl_contents, encoding="utf-8")

    sim_cmd = [
        xsim,
        "work.sim",
    ]

    for arg in plusargs:
        sim_cmd.extend(["--testplusarg", arg])

    sim_cmd.extend(
        [
            "-onfinish",
            "quit",
            "-onerror",
            "quit",
            "-tclbatch",
            str(tcl),
        ]
    )

    _run_logged(
        sim_cmd,
        log_path=sim_log,
        cwd=out,
    )
