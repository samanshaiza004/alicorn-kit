# Condition D replication batch 2

Three independent trials completed on 2026-11-27, each under the same 15-minute
work budget. The trial source and logs are archived in the per-component
directories. Every final TestUI suite and app build passed, and they were
re-run from the archived sources before publication.

| Component | TestUI | Implementation passes | First successful build/test | App imports |
| --- | ---: | ---: | --- | --- |
| Command Palette | 2/2, all 12 size/scale cases | 2 | 02:51:55 UTC | `alicorn:runtime` for custom modal/semantics; `alicorn:ui`, AliKit palette packages |
| Dialog | 4/4, all 12 size/scale cases | 4 | 02:49:47 UTC | `alicorn:ui` + `alikit:dialog` |
| Data Grid | 3/3, all 12 size/scale cases | 4 | 02:54:26 UTC | `alicorn:runtime` for app-owned semantic request handling; `alicorn:ui`, `alikit:data_grid` |

All three app builds succeeded. The linker emitted the duplicate `-lobjc`
warning. Trials did not launch native windows. Native pixels, physical DPI, and
OS-level accessibility remain unverified.

## Staged source note

The trial inputs were staged from AliKit `5c1c0964` and Alicorn `4e0862f3`.
Existing examples, reports, screenshots, native test tools, test fixtures, and
all `*_test.odin` files were excluded. The public `alicorn:testui` API remained
available. Two generated no-op shims replaced dormant Alicorn native
validation dependencies, and one import in the staged native validation source
was redirected to a shim. These helpers are not called by the UI or TestUI
trials; no API or source under test was changed. Full dependency directories
were used only by the compiler and were not searched or inspected.

This batch verifies that a clean Condition D author can reproduce each target
using the cookbook and headless assertions. It does not compare conditions,
measure first-pass success against a historical baseline, or establish visual
match to the SVGs. The matched A/B/C/D trial protocol remains incomplete.
