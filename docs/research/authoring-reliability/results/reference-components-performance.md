# Command Palette and Dialog matched component probe

This comparison asks whether the authoring-quality changes introduced a
measurable cost in the shared Command Palette and Dialog presentation paths.
It compiles the same benchmark source at both AliKit revisions and holds the
runtime, bindings, Odin compiler, workload, optimization, viewport, and run
order constant.

| Item | Baseline | Candidate |
| --- | --- | --- |
| AliKit | `fded57a94e6a2c5bf44d8b980befe5a260ff5ed5` | `95fc8af9ac0296be195d72828fba8a3a9a53ff7e` |
| Alicorn | `4e0862f368cb638b7aece0bad9dd82cae0c3d8c4` | Same |
| AccessKit binding | `e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b` | Same |
| Odin | `dev-2026-11:9a6991685` | Same |
| Build | `-o:speed` | Same |

The [benchmark source](../../../../benchmarks/reference_components/main.odin)
describes a stock three-item Command Palette and a modal Dialog with a title,
description, Cancel, and Save actions. Each case uses a 1280 × 800 TestUI
viewport, three warmups, a 2 s virtual settling advance, 101 idle probes, and
1,001 forced descriptions. Five fresh processes per revision and component
run in alternating revision order. The [paired runner](../../../../benchmarks/reference_components/run_paired.py)
records each process's TestUI turn timings, Alicorn stage timings, process CPU
time, and peak RSS. The full samples are in the
[raw capture](reference-components-performance-comparison-raw.json).

The table reports the median of five process-level percentiles. Description
percentiles are from the 1,001 timed TestUI turns within each process. RSS is
the median process peak, not retained heap size or long-session memory.

| Component | Description p50 (µs), baseline → candidate | p95 (µs) | p99 (µs) | Process CPU (ms) | Peak RSS (MB) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Command Palette | 42 → 45 | 100 → 106 | 152 → 188 | 77.88 → 84.40 | 12.337 → 12.337 |
| Dialog | 13 → 13 | 19 → 18 | 54 → 60 | 40.81 → 40.50 | 11.960 → 11.960 |

These measurements do not establish a material performance or memory
regression. Palette p50 differs by 3 µs in this minimal scene; its per-process
p50 ranges overlap (31–54 µs baseline, 31–50 µs candidate), as do the broad
p95/p99 ranges. Dialog p50 and p95 are effectively unchanged. The five-launch
CPU and RSS medians are small and inconsistent across the two components.
The 101 idle probes passed in every process with zero retained work, runtime
invalidation, or frame demand.

This is a headless component-pipeline probe, not a native GPU benchmark or a
benchmark of the complete workspace and destructive-confirmation reference
applications. The very short turn timings are sensitive to host scheduling;
the tail spread makes small percentage differences unreliable. It does not
measure input-to-display latency, native idle CPU/wakeups, persistent heap
growth, energy, or physical DPI. Treat it as a local non-regression check, not
a broad performance claim.

The implementation delta is narrow: `command_palette` adds a public `Match`
alias, and the shared palette result surface now grows to fill its row; the
Dialog implementation file is unchanged between these revisions. This probe
includes the palette row-width correction but does not isolate its cost.

## Reproduction

With the exact dependencies listed above checked out locally, copy the current
benchmark source into a clean `fded57a` snapshot, then build both revisions
with the same Alicorn and AccessKit collections:

```sh
mkdir -p /private/tmp/alikit-fded57a-reference-components
git archive fded57a94e6a2c5bf44d8b980befe5a260ff5ed5 \
  | tar -x -C /private/tmp/alikit-fded57a-reference-components
mkdir -p /private/tmp/alikit-fded57a-reference-components/benchmarks/reference_components
cp benchmarks/reference_components/main.odin \
  /private/tmp/alikit-fded57a-reference-components/benchmarks/reference_components/main.odin

cd /private/tmp/alikit-fded57a-reference-components
odin build benchmarks/reference_components -o:speed \
  -collection:alicorn=/path/to/alicorn \
  -collection:alikit=/private/tmp/alikit-fded57a-reference-components \
  -collection:accesskit=/path/to/odin-accesskit \
  -collection:accesskit_c=/path/to/accesskit-c/lib/macos/arm64/static \
  -out:/private/tmp/alikit_reference_components_baseline

cd /path/to/alicorn-kit
odin build benchmarks/reference_components -o:speed \
  -collection:alicorn=/path/to/alicorn \
  -collection:alikit=. \
  -collection:accesskit=/path/to/odin-accesskit \
  -collection:accesskit_c=/path/to/accesskit-c/lib/macos/arm64/static \
  -out:/private/tmp/alikit_reference_components_candidate

python3 benchmarks/reference_components/run_paired.py \
  --baseline /private/tmp/alikit_reference_components_baseline \
  --candidate /private/tmp/alikit_reference_components_candidate \
  --candidate-revision 95fc8af9ac0296be195d72828fba8a3a9a53ff7e \
  --runs 5 \
  --output docs/research/authoring-reliability/results/reference-components-performance-comparison-raw.json
```

`run_paired.py` uses Python's per-child `resource` accounting for process CPU
and peak RSS; peak-RSS units are bytes on macOS. Replace the dependency paths
with checkouts at the listed revisions.
