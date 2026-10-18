#!/usr/bin/env python3
"""Compare the native pinned MiSTer decoder with the staged Gamebub decoder.

This is the first narrow upstream oracle. It covers cartridge ownership and
bank addressing, including the October $3E fix, not whole-engine parity.
"""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess


ROOT = Path(__file__).resolve().parents[1]


def verify_hash(path: Path, expected: str) -> None:
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f"{path}: expected SHA-256 {expected}, got {actual}")


def main() -> None:
    ghdl = os.environ.get("GHDL") or shutil.which("ghdl")
    if not ghdl:
        raise SystemExit("GHDL missing; set GHDL or run in the documented test container")
    manifest = json.loads((ROOT / "manifests/sources.json").read_text())
    if manifest["revision"] != "8443a0d19a88aff7a5900011bccf386daf146945":
        raise SystemExit("oracle requires the reviewed October 2026 MiSTer pin")
    entry = next(f for f in manifest["files"] if f["upstream"] == "rtl/memory_decode.vhd")
    pristine = ROOT / "vendor/sms_mister" / entry["upstream"]
    staged = ROOT / entry["staged"]
    verify_hash(pristine, entry["sha256"])
    verify_hash(staged, entry["staged_sha256"])

    base = ROOT / "build/ghdl-memory-decode-oracle"
    native_dir, staged_dir = base / "upstream", base / "staged"
    for directory in (native_dir, staged_dir):
        directory.mkdir(parents=True, exist_ok=True)
        for work_file in directory.glob("*-obj*.cf"):
            work_file.unlink()
    common = ["--std=08", "-fsynopsys", "-frelaxed-rules"]
    subprocess.run(
        [ghdl, "-a", *common, "--work=upstream", f"--workdir={native_dir}", str(pristine)],
        check=True, cwd=ROOT,
    )
    search = f"-P{native_dir}"
    subprocess.run(
        [ghdl, "-a", *common, f"--workdir={staged_dir}", search,
         str(staged), str(ROOT / "tests/tb_memory_decode_oracle.vhdl")],
        check=True, cwd=ROOT,
    )
    subprocess.run(
        [ghdl, "-r", *common, f"--workdir={staged_dir}", search,
         "tb_memory_decode_oracle", "--assert-level=error"],
        check=True, cwd=ROOT,
    )


if __name__ == "__main__":
    main()
