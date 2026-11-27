#!/usr/bin/env python3
"""Run matched headless Data Grid probes for two AliKit revisions."""

import argparse
import hashlib
import json
import os
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
if sys.platform != "darwin":
    rss *= 1024
print(json.dumps({
    "returncode": p.returncode,
    "stdout": p.stdout,
    "stderr": p.stderr,
    "peak_rss_bytes": rss,
    "user_cpu_seconds": r.ru_utime,
    "system_cpu_seconds": r.ru_stime,
}))
"""


def parse_output(stdout):
    result = {}
    stage_rows = False
    for line in stdout.splitlines():
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "case":
            result["rows"] = int(parts[1])
            result["viewport"] = [int(parts[3]), int(parts[4])]
        elif parts[0] == "settled_idle_probes":
            result["settled_idle"] = {
                "probes": int(parts[1]),
                "retained_work": int(parts[3]),
                "frame_demand": parts[5] == "true",
            }
        elif parts[0] == "logical_row_semantic_entities":
            result["logical_row_semantic_entities"] = int(parts[1])
        elif parts[0] == "offscreen_row_semantic_entities":
            result["virtual_row_semantics"] = int(parts[1])
        elif parts[0] == "offscreen_row_label_bytes":
            result["virtual_row_label_bytes"] = int(parts[1])
        elif parts[0] == "description_median_ns":
            result.setdefault("description_ns", {})["p50"] = int(parts[1])
        elif parts[0] == "description_p95_ns":
            result.setdefault("description_ns", {})["p95"] = int(parts[1])
        elif parts[0] == "description_p99_ns":
            result.setdefault("description_ns", {})["p99"] = int(parts[1])
        elif parts[0] == "data_grid_callback_p50_ns":
            result.setdefault("data_grid_callback_ns", {})["p50"] = int(parts[1])
        elif parts[0] == "data_grid_callback_p95_ns":
            result.setdefault("data_grid_callback_ns", {})["p95"] = int(parts[1])
        elif parts[0] == "data_grid_callback_p99_ns":
            result.setdefault("data_grid_callback_ns", {})["p99"] = int(parts[1])
        elif parts[0] == "stage_timings_ns":
            result["runtime_stages_ns"] = {}
            stage_rows = True
        elif stage_rows and len(parts) == 4:
            result["runtime_stages_ns"][parts[0]] = {
                "p50": int(parts[1]),
                "p95": int(parts[2]),
                "p99": int(parts[3]),
            }
        elif parts[0] == "semantic_descriptions_per_frame_median":
            result["semantic_descriptions_per_frame_median"] = int(parts[1])
        elif parts[0] == "measure_nodes_examined":
            result["measure_nodes_examined"] = int(parts[1])
        elif parts[0] == "layout_nodes_visited":
            result["layout_nodes_visited"] = int(parts[1])
        elif parts[0] == "semantic_structure_changes":
            result["semantic_structure_changes"] = int(parts[1])
        elif parts[0] == "description_samples_ns":
            result["sorted_101_description_samples_ns"] = [int(value) for value in parts[1:]]
        elif parts[0] == "data_grid_callback_samples_ns":
            result["sorted_101_data_grid_callback_samples_ns"] = [int(value) for value in parts[1:]]
        elif parts[0] == "semantic_sync_samples_ns":
            result["sorted_101_semantic_sync_samples_ns"] = [int(value) for value in parts[1:]]

    if len(result.get("sorted_101_description_samples_ns", [])) != 101:
        raise RuntimeError("benchmark output is missing its 101 description samples")
    if len(result.get("sorted_101_data_grid_callback_samples_ns", [])) != 101:
        raise RuntimeError("benchmark output is missing its 101 Data Grid callback samples")
    if len(result.get("sorted_101_semantic_sync_samples_ns", [])) != 101:
        raise RuntimeError("benchmark output is missing its 101 Semantic_Sync samples")
    if not result.get("settled_idle"):
        raise RuntimeError("benchmark output is missing its settled-idle result")
    if result.get("logical_row_semantic_entities") != result.get("rows"):
        raise RuntimeError("benchmark did not publish every logical row")
    return result


def run_one(executable, row_count):
    completed = subprocess.run(
        [sys.executable, "-c", SAMPLE_RUNNER, executable, str(row_count)],
        capture_output=True,
        text=True,
        check=True,
    )
    process = json.loads(completed.stdout)
    if process["returncode"] != 0:
        raise RuntimeError(
            f"{row_count}-row probe failed ({process['returncode']}):\n"
            f"{process['stderr']}\n{process['stdout']}"
        )
    result = parse_output(process["stdout"])
    result["process_peak_rss_bytes"] = process["peak_rss_bytes"]
    result["process_user_cpu_seconds"] = process["user_cpu_seconds"]
    result["process_system_cpu_seconds"] = process["system_cpu_seconds"]
    if result["settled_idle"] != {
        "probes": 101,
        "retained_work": 0,
        "frame_demand": False,
    }:
        raise RuntimeError(f"{row_count}-row settled-idle gate failed: {result['settled_idle']}")
    return result


def read_dependency_lock():
    return json.loads(Path("dependencies.lock.json").read_text(encoding="utf-8"))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", required=True, help="baseline Data Grid benchmark executable")
    parser.add_argument("--candidate", required=True, help="candidate Data Grid benchmark executable")
    parser.add_argument("--baseline-revision", required=True)
    parser.add_argument("--candidate-revision", required=True)
    parser.add_argument("--runs", type=int, default=3, help="fresh processes per revision and row count")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    if args.runs < 1:
        parser.error("--runs must be at least 1")
    dependencies = read_dependency_lock()

    executables = {"baseline": args.baseline, "candidate": args.candidate}
    runs = []
    for row_count in (200, 10_000, 100_000):
        for launch in range(1, args.runs + 1):
            order = ("baseline", "candidate") if launch % 2 else ("candidate", "baseline")
            for revision in order:
                print(f"{row_count} rows: {revision} launch {launch}", flush=True)
                result = run_one(executables[revision], row_count)
                result.update({"revision": revision, "launch": launch})
                runs.append(result)

    capture = {
        "title": "AliKit Data Grid matched revision comparison",
        "date": date.today().isoformat(),
        "baseline": {
            "alikit_revision": args.baseline_revision,
            "description": "Before the authoring-quality reference work",
        },
        "candidate": {
            "alikit_revision": args.candidate_revision,
            "description": "Current AliKit source state",
        },
        "controlled_dependencies": {
            "alicorn_revision": dependencies["alicorn"]["revision"],
            "odin_accesskit_revision": dependencies["accesskit_binding"]["revision"],
            "odin": "dev-2026-11:9a6991685",
            "build": "release (-o:speed)",
        },
        "machine": f"{platform.platform()} ({platform.machine()})",
        "benchmark": {
            "source": "benchmarks/data_grid/main.odin",
            "source_sha256": hashlib.sha256(Path("benchmarks/data_grid/main.odin").read_bytes()).hexdigest(),
            "viewport": [1280, 800],
            "visible_rows": 12,
            "warmups_per_launch": 3,
            "samples_per_launch": 101,
            "launches_per_revision_and_row_count": args.runs,
            "row_counts": [200, 10_000, 100_000],
            "historical_revision_uses_identical_current_benchmark_source": True,
            "peak_rss_unit": "bytes (macOS resource.getrusage(RUSAGE_CHILDREN).ru_maxrss)",
            "sample_order": "Sorted values emitted by the benchmark; temporal order is not retained.",
            "measurement_boundary": "TestUI full-turn elapsed time, direct elapsed time around data_grid() inside the application description callback, and Alicorn runtime CPU stages; excludes native renderer, GPU, presentation, and external accessibility clients.",
            "dependency_control": "Both AliKit snapshots were compiled against the same current Alicorn and AccessKit revisions; this isolates AliKit source changes and does not compare each revision with its original lockfile stack.",
        },
        "runs": runs,
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as output:
        json.dump(capture, output, indent=2)
        output.write("\n")


if __name__ == "__main__":
    main()
