# External consumer fixture

Templates for `tools/validate_external_consumer.ps1`, the phase-6 check that
AliKit works from outside its own repository.

The harness copies these templates into a generated directory (default:
`%TEMP%\alikit-external-consumer`), performs the source copy, builds both
projects, and runs their native smokes. The templates themselves are not built
from this repository; they are ordinary consumer applications and use only
public Odin packages.

## Path 1: `path1_packages`

Imports complete packages through the AliKit collection:

- `alikit:dialog`
- `alikit:menu`
- `alikit:radio_group`
- `alikit:progress`
- `alikit:notices`
- `alikit:selection`

`main.odin` composes a dialog containing a parts-composed radio group and an
anchored Menu popup, plus a progress part, a runtime toast, and an author-owned
selection strip built directly on `alikit:selection`.

Build:

```powershell
odin build path1_packages `
    -collection:alicorn=<alicorn> `
    -collection:alikit=<alicorn-kit> `
    -out:bin/external_consumer_path1.exe
```

Add the pinned AccessKit compiler arguments from
`<alicorn>/.deps/odin-accesskit/tools/bootstrap.ps1` for the native host.

## Path 2: `path2_copy`

Consumes the source closures for all 14 catalog components. The harness copies
the `sources` listed by each component's `copy` recipe in `components.json`
into sibling packages under `path2_copy/vendor/`, then applies the declared
`importRewrites`. `Copy_Package_Proof` references public component types so
Odin compiles every copied package. The app also composes copied Radio Group
parts and a copied Menu popup. The build needs only the Alicorn collection:

```powershell
odin build path2_copy -collection:alicorn=<alicorn> -out:bin/external_consumer_path2.exe
```

The manifest recipe includes every AliKit dependency needed by the copied
source. Copying a component file alone may not compile; keep its full declared
source closure together.

## Smoke assertions

Both applications run with `--smoke`. The harness asserts:

- exit code 0;
- the application's `idle true` line;
- the native host's `SDL application PASS`;
- no stabilization-limit hits and no repeated rebuild loop (one first-frame
  rebuild is allowed when a runtime toast is posted after the first frame).
