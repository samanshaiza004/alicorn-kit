#!/usr/bin/env python3
"""Run matched headless Command Palette and Dialog probes on macOS."""

import argparse
import hashlib
import json
import platform
import subprocess
import sys
from datetime import date
from pathlib import Path


SAMPLE_RUNNER = r"""
import json, resource, subprocess, sys
p = subprocess.run([sys.argv[1], sys.argv[2]], capture_output=True, text=True)
r = resource.getrusage(resource.RUSAGE_CHILDREN)
rss = r.ru_maxrss
if sys.platform != 'darwin':
    rss *= 1024
print(json.dumps({
    'returncode': p.returncode,
    'stdout': p.stdout,
    'stderr': p.stderr,
    'peak_rss_bytes': rss,
    'user_cpu_seconds': r.ru_utime,
    'system_cpu_seconds': r.ru_stime,
}))
"""


def parse_output(stdout):
    lines = stdout.splitlines()
    result = {}
    reading_stages = False
    for line in lines:
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "description_elapsed_ns_p50":
            result.setdefault("description_elapsed_ns", {})["p50"] = int(parts[1])
        elif parts[0] == "description_elapsed_ns_p95":
            result.setdefault("description_elapsed_ns", {})["p95"] = int(parts[1])
        elif parts[0] == "description_elapsed_ns_p99":
            result.setdefault("description_elapsed_ns", {})["p99"] = int(parts[1])
        elif parts[0] == "description_elapsed_samples_ns":
            result.setdefault("description_elapsed_ns", {})["sorted_samples_ns"] = [
                int(value) for value in parts[1:]
            ]
        elif parts[0] == "case":
            result["viewport"] = [int(parts[3]), int(parts[4])]
        elif parts[0] == "warmups":
            result["warmups"] = int(parts[1])
            result["samples"] = int(parts[3])
            result["settled_idle"] = {
                "probes": int(parts[5]),
                "retained_work": int(parts[7]),
                "frame_demand": parts[9] == "true",
            }
        elif parts[0] == "runtime_stage_ns_p50_p95_p99":
            result["runtime_stages_ns"] = {}
            reading_stages = True
        elif reading_stages and len(parts) == 4:
            result["runtime_stages_ns"][parts[0]] = {
                "p50": int(parts[1]),
                "p95": int(parts[2]),
                "p99": int(parts[3]),
            }
    samples = result.get("description_elapsed_ns", {}).get("sorted_samples_ns", [])
    if len(samples) != result.get("samples") or not result.get("settled_idle"):
        raise RuntimeError("benchmark output is incomplete or has the wrong sample count")
    return result


def run_one(executable, component):
    completed = subprocess.run(
        [sys.executable, "-c", SAMPLE_RUNNER, executable, component],
        capture_output=True,
        text=True,
        check=True,
    )
    process = json.loads(completed.stdout)
    if process["returncode"] != 0:
        raise RuntimeError(
            f"{component} probe failed ({process['returncode']}):\n"
            f"{process['stderr']}\n{process['stdout']}"
        )
    result = parse_output(process["stdout"])
    result["process_peak_rss_bytes"] = process["peak_rss_bytes"]
    result["process_user_cpu_seconds"] = process["user_cpu_seconds"]
    result["process_system_cpu_seconds"] = process["system_cpu_seconds"]
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", required=True, help="fded57a benchmark executable")
    parser.add_argument("--candidate", required=True, help="current benchmark executable")
    parser.add_argument("--baseline-revision", default="fded57a94e6a2c5bf44d8b980befe5a260ff5ed5")
    parser.add_argument("--candidate-revision", required=True)
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    if args.runs < 1:
        parser.error("--runs must be at least 1")

    revisions = {"baseline": args.baseline, "candidate": args.candidate}
    runs = []
    for component in ("command_palette", "dialog"):
        for launch in range(1, args.runs + 1):
            order = ("baseline", "candidate") if launch % 2 else ("candidate", "baseline")
            for revision in order:
                print(f"{component}: {revision} launch {launch}", flush=True)
                result = run_one(revisions[revision], component)
                result.update({"component": component, "revision": revision, "launch": launch})
                runs.append(result)

    capture = {
        "title": "AliKit Command Palette and Dialog matched component probe",
        "date": date.today().isoformat(),
        "baseline": {"revision": args.baseline_revision, "description": "AliKit before authoring-quality reference work"},
        "candidate": {"revision": args.candidate_revision, "description": "AliKit after authoring-quality reference work"},
        "controlled_dependencies": {
            "alicorn": "4e0862f368cb638b7aece0bad9dd82cae0c3d8c4",
            "accesskit_binding": "e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b",
            "odin": "dev-2026-11:9a6991685",
            "optimization": "-o:speed",
        },
        "machine": f"{platform.platform()} ({platform.machine()})",
        "benchmark": {
            "kind": "TestUI component-pipeline probe; not a native renderer or full reference-app benchmark",
            "source_sha256": hashlib.sha256(Path("benchmarks/reference_components/main.odin").read_bytes()).hexdigest(),
            "viewport": [1280, 800],
            "warmups": 3,
            "settling_advance_ns": 2_000_000_000,
            "settled_idle_probes": 101,
            "description_samples": 1001,
            "order": f"{args.runs} fresh processes per revision and component, alternating revision order",
            "command_palette": "stock controlled palette with three fixed items and its default query",
            "dialog": "composable modal with title, description, and Cancel/Save actions",
            "timing": "elapsed wall time around synchronous TestUI description turns; runtime stage timings are measured separately by Alicorn",
            "memory": "per-process peak resident set size reported by Python resource.getrusage(RUSAGE_CHILDREN); bytes on macOS",
        },
        "runs": runs,
    }
    with open(args.output, "w", encoding="utf-8") as output:
        json.dump(capture, output, indent=2)
        output.write("\n")


if __name__ == "__main__":
    main()
