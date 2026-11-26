# Command Palette and Dialog matched component probe

This comparison asks whether the authoring-quality changes introduced a
measurable cost in the shared Command Palette and Dialog presentation paths.
It compiles the same benchmark source at both AliKit revisions and holds the
runtime, bindings, Odin compiler, workload, optimization, viewport, and run
order constant.

| Item | Baseline | Candidate |
| --- | --- | --- |
| AliKit | `fded57a94e6a2c5bf44d8b980befe5a260ff5ed5` | `47223c7013ee8f92a3593b6ac99702ef505f2b6e` |
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
time, and peak RSS. This current-main capture uses five launches per revision
and component. The full samples are in the
[current raw capture](reference-components-performance-current-raw.json). The
earlier five-launch capture against intermediate candidate `95fc8af` remains
available in [its original raw file](reference-components-performance-comparison-raw.json).

The table reports the median of five process-level percentiles. Description
percentiles are from the 1,001 timed TestUI turns within each process. RSS is
the median process peak, not retained heap size or long-session memory.

| Component | Description p50 (µs), baseline → candidate | p95 (µs) | p99 (µs) | Process CPU (ms) | Peak RSS (MB) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Command Palette | 27 → 27 | 29 → 28 | 37 → 40 | 42.14 → 41.66 | 12.288 → 12.304 |
| Dialog | 10 → 10 | 11 → 10 | 11 → 11 | 24.18 → 24.39 | 11.928 → 11.944 |

These measurements do not establish a material performance or memory
regression. Command Palette p50 is 27 µs in both revisions; its per-process
ranges overlap for p50 (27–27 µs baseline, 26–30 µs candidate) and p95/p99.
Dialog p50 is 10 µs in both revisions, and its p95/p99 ranges overlap. The
five-launch CPU and RSS medians differ by at most about 1% for each component.
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
alias and semantic query-value adoption; the dialog implementation is
unchanged between these revisions. The stock palette workload does not send a
semantic query-value request, so the comparison measures its ordinary retained
description path rather than the new handler specifically. This probe includes
the palette row-width correction and does not isolate the cost of any one
change.

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
  --candidate-revision 47223c7013ee8f92a3593b6ac99702ef505f2b6e \
  --runs 5 \
  --output docs/research/authoring-reliability/results/reference-components-performance-current-raw.json
```

`run_paired.py` uses Python's per-child `resource` accounting for process CPU
and peak RSS; peak-RSS units are bytes on macOS. Replace the dependency paths
with checkouts at the listed revisions.
