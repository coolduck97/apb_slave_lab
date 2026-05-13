#!/usr/bin/env python3
"""Small Icarus Verilog runner for the APB master/slave lab."""

from __future__ import annotations

import argparse
import datetime as dt
import subprocess
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent
DEFAULT_BUILD_DIR = PROJECT_ROOT / "build"
DEFAULT_LOG_FILE = PROJECT_ROOT / "sim.log"
DEFAULT_WAVE_FILE = PROJECT_ROOT / "wave.vcd"


def find_sim_files() -> list[Path]:
    """Collect all Verilog/SystemVerilog files needed for simulation."""
    search_dirs = [PROJECT_ROOT / "rtl", PROJECT_ROOT / "tb"]
    suffixes = {".v", ".sv"}
    sim_files: list[Path] = []

    for search_dir in search_dirs:
        if not search_dir.is_dir():
            continue
        for path in sorted(search_dir.rglob("*")):
            if path.is_file() and path.suffix in suffixes:
                sim_files.append(path)

    return sim_files


def run_command(command: list[str], log_file: Path) -> int:
    """Run a command, print output to the terminal, and save it to the log."""
    with log_file.open("a", encoding="utf-8") as log:
        log.write(f"\n$ {' '.join(command)}\n")
        log.flush()

        process = subprocess.Popen(
            command,
            cwd=PROJECT_ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )

        assert process.stdout is not None
        for line in process.stdout:
            print(line, end="")
            log.write(line)

        return process.wait()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compile and run the APB master/slave RTL simulation."
    )
    parser.add_argument(
        "--wave",
        action="store_true",
        help="Generate a VCD waveform file.",
    )
    parser.add_argument(
        "--wave-file",
        type=Path,
        default=DEFAULT_WAVE_FILE,
        help="Waveform output path. Default: wave.vcd",
    )
    parser.add_argument(
        "--log",
        type=Path,
        default=DEFAULT_LOG_FILE,
        help="Simulation log path. Default: sim.log",
    )
    parser.add_argument(
        "--build-dir",
        type=Path,
        default=DEFAULT_BUILD_DIR,
        help="Directory for compiled simulation output. Default: build",
    )
    parser.add_argument(
        "--top",
        default="tb_apb_interface",
        help="Top testbench module name. Default: tb_apb_interface",
    )
    parser.add_argument(
        "--clean",
        action="store_true",
        help="Remove old simv, log, and wave outputs before running.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    build_dir = args.build_dir.resolve()
    log_file = args.log.resolve()
    wave_file = args.wave_file.resolve()
    simv_file = build_dir / "simv"

    if args.clean:
        for old_file in [simv_file, log_file, wave_file]:
            if old_file.exists():
                old_file.unlink()

    build_dir.mkdir(parents=True, exist_ok=True)
    log_file.parent.mkdir(parents=True, exist_ok=True)
    if args.wave:
        wave_file.parent.mkdir(parents=True, exist_ok=True)

    sim_files = find_sim_files()
    if not sim_files:
        print("FAIL: no RTL or testbench files found in rtl/ and tb/")
        return 1

    timestamp = dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with log_file.open("w", encoding="utf-8") as log:
        log.write("APB master/slave simulation log\n")
        log.write(f"Started: {timestamp}\n")
        log.write("Files:\n")
        for path in sim_files:
            log.write(f"  {path.relative_to(PROJECT_ROOT)}\n")

    print("== APB master/slave simulation ==")
    print(f"Log file : {log_file.relative_to(PROJECT_ROOT)}")
    print(f"Wave     : {'on' if args.wave else 'off'}")
    print("Files:")
    for path in sim_files:
        print(f"  {path.relative_to(PROJECT_ROOT)}")

    compile_cmd = [
        "iverilog",
        "-g2012",
        "-s",
        args.top,
        "-o",
        str(simv_file),
        *[str(path) for path in sim_files],
    ]

    print("\n[1/2] Compiling RTL and testbench...")
    compile_result = run_command(compile_cmd, log_file)
    if compile_result != 0:
        print("FAIL: compile failed")
        return compile_result

    run_cmd = ["vvp", str(simv_file)]
    if args.wave:
        run_cmd.append("+WAVE")
        run_cmd.append(f"+WAVE_FILE={wave_file}")

    print("\n[2/2] Running simulation...")
    sim_result = run_command(run_cmd, log_file)
    if sim_result != 0:
        print("FAIL: simulation failed")
        return sim_result

    print("\nSimulation complete.")
    print(f"Generated log: {log_file.relative_to(PROJECT_ROOT)}")
    if args.wave:
        print(f"Generated wave: {wave_file.relative_to(PROJECT_ROOT)}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
