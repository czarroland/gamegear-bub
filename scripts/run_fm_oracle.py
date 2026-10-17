#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Reproduce a native VM2413 smoke trace without vendoring its restricted source.

The pinned MiSTer checkout must already exist locally. All copied/modified
VM2413 files, compiler products, and the trace stay under ignored build/.
This checks one keyed tone only; it is not FM parity or redistribution clearance.
"""

import argparse
import csv
import hashlib
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_TRACE_SHA256 = "5f930230e6a62c83708ec97ab97d7a39e77175d16a9cab346fda8df6d7513f6b"
SAMPLE = re.compile(r"\(report note\): sample\s+(\d+)\s+(\d+)")


def run(command, log=None):
    result = subprocess.run([str(part) for part in command], cwd=ROOT,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, check=False)
    if log is not None:
        log.write(result.stdout)
    if result.returncode:
        raise RuntimeError(f"{' '.join(map(str, command))} failed:\n{result.stdout[-4000:]}")
    return result.stdout


def complete_cases(source):
    """Add default arms required by GHDL to the pinned legacy VHDL."""
    output, stack = [], []
    for line in source.splitlines(keepends=True):
        if re.match(r"^\s*case\b.*\bis\s*$", line, re.I):
            stack.append(False)
        elif re.match(r"^\s*when\s+others\b", line, re.I) and stack:
            stack[-1] = True
        elif re.match(r"^\s*end\s+case\s*;", line, re.I) and stack:
            if not stack.pop():
                output.append(re.match(r"^\s*", line).group() + "    when others => null;\n")
        output.append(line)
    if stack:
        raise ValueError("Unclosed VM2413 case statement")
    return "".join(output)


def prepare(source_dir, stage):
    qip = (source_dir / "OPLL.qip").read_text(encoding="utf-8")
    files = re.findall(r"\[file join \$::quartus\(qip_path\) ([\w.]+) \]", qip)
    if len(files) != 19 or len(set(files)) != 19 or "opll.vhd" not in files or "vm2413.vhd" not in files:
        raise ValueError("Pinned OPLL.qip did not list exactly 19 distinct VM2413 sources")
    stage.mkdir(parents=True, exist_ok=True)
    for name in files:
        original = (source_dir / name).read_bytes()
        source = original.decode("latin1")
        # Simulator-only compatibility changes. Never edit the source checkout.
        source = re.sub(r"\bRelease\b", "EgRelease", source, flags=re.I)
        source = source.replace("0 to 18-1", "0 to 17").replace("0 to 9-1", "0 to 8")
        source = source.replace("VOICE_ID_TYPE'range", "0 to 37")
        if name == "controller.vhd":
            source = source.replace("ch_type'range", "0 to 8")
            source = source.replace(
                "                                end if;\n                        end case;",
                "                                end if;\n                            when others => null;\n                        end case;",
                1,
            )
        source = complete_cases(source)
        components = re.findall(r"^\s*component\s+([a-z_0-9]+)", source, re.I | re.M)
        if components and name != "vm2413.vhd":
            bindings = "".join(f"    for all : {component} use entity work.{component}(rtl);\n"
                               for component in components)
            begin = list(re.finditer(r"^begin\b", source, re.M))[-1]
            source = source[:begin.start()] + bindings + source[begin.start():]
        (stage / name).write_bytes(source.encode("latin1"))
    # The Quartus file list is not a VHDL analysis order. Explicit GHDL
    # bindings require the referenced entity to have been analyzed first.
    by_entity = {Path(name).stem.lower(): name for name in files}
    dependencies = {}
    for name in files:
        text = (stage / name).read_text(encoding="latin1")
        referenced = re.findall(r"for all : \w+ use entity work\.(\w+)\(rtl\)", text, re.I)
        dependencies[name] = {by_entity[entity.lower()] for entity in referenced
                              if entity.lower() in by_entity and by_entity[entity.lower()] != name}
        if name != "vm2413.vhd":
            dependencies[name].add("vm2413.vhd")
    order = []
    while dependencies:
        ready = next((name for name in files if name in dependencies and
                      dependencies[name].issubset(order)), None)
        if ready is None:
            raise ValueError(f"VM2413 analysis dependencies are cyclic: {dependencies}")
        order.append(ready)
        del dependencies[ready]
    return order


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upstream", type=Path, default=ROOT / "build/upstream-sms")
    args = parser.parse_args()
    upstream = args.upstream.resolve()
    source_dir = upstream / "rtl/VM2413"
    manifest = json.loads((ROOT / "manifests/fm_oracle_sources.json").read_text())
    expected = {"OPLL.qip": manifest["qip_sha256"], **manifest["files"]}
    for name, digest in expected.items():
        path = source_dir / name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise SystemExit(f"Pinned MiSTer VM2413 source missing or changed: {path}")
    ghdl = os.environ.get("GHDL") or shutil.which("ghdl")
    if not ghdl:
        raise SystemExit("Missing GHDL; set GHDL or run in the documented test container")
    stage = ROOT / "build/fm-oracle-src"
    work = ROOT / "build/fm-oracle-ghdl"
    if stage.exists():
        shutil.rmtree(stage)
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    order = prepare(source_dir, stage)
    flags = [ghdl, "--std=93", "-fsynopsys", "-fexplicit", "-C", f"--workdir={work}"]
    log_path = ROOT / "build/fm-oracle.log"
    with log_path.open("w") as log:
        for name in order:
            run([ghdl, "-a", *flags[1:], stage / name], log)
        run([ghdl, "-a", *flags[1:], ROOT / "tests/tb_fm_oracle.vhdl"], log)
        run([ghdl, "-e", *flags[1:], "tb_fm_oracle"], log)
        simulation = run([ghdl, "-r", *flags[1:], "tb_fm_oracle", "--stop-time=110us"], log)
    samples = [(int(cycle), int(value)) for cycle, value in SAMPLE.findall(simulation)]
    if len(samples) != 125 or len(set(cycle for cycle, _ in samples)) != 125:
        raise RuntimeError(f"Expected 125 unique FM samples, found {len(samples)}")
    trace = ROOT / "build/fm-oracle.csv"
    with trace.open("w", newline="") as output:
        writer = csv.writer(output, lineterminator="\n")
        writer.writerow(["cycle", "mixout_unsigned"])
        writer.writerows(samples)
    digest = hashlib.sha256(trace.read_bytes()).hexdigest()
    if digest != EXPECTED_TRACE_SHA256:
        raise RuntimeError(f"FM reference trace changed: {digest}; expected {EXPECTED_TRACE_SHA256}")
    print(f"PASS pinned VM2413 tone trace: {len(samples)} samples, SHA-256 {digest}")
    print(f"Private outputs: {trace}, {log_path}")


if __name__ == "__main__":
    main()
