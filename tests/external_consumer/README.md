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

Consumes copied Radio Group and Menu packages. The harness copies:

- `radio_group/radio_group.odin`
- `menu/menu.odin`
- `selection/selection.odin`
- `theme_contract/contract.odin`

into `path2_copy/vendor/` as sibling packages and rewrites both component
packages' imports:

```odin
import sel "../selection"
import tc "../theme_contract"
```

`main.odin` composes the copied radio parts with an author-owned two-line row
and uses the copied Menu package for an anchored action popup. The build needs
only the Alicorn collection:

```powershell
odin build path2_copy -collection:alicorn=<alicorn> -out:bin/external_consumer_path2.exe
```

Copying either component file alone does not compile. `components.json` records
the source and rewrite recipe under `components[].copy` for audited components.

## Smoke assertions

Both applications run with `--smoke`. The harness asserts:

- exit code 0;
- the application's `idle true` line;
- the native host's `SDL application PASS`;
- no stabilization-limit hits and no repeated rebuild loop (one first-frame
  rebuild is allowed when a runtime toast is posted after the first frame).
