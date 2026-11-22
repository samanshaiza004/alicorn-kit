---
title: Compatibility and pinning
description: The exact Alicorn and AccessKit revisions AliKit targets, what the source-level contract means, and how to update the pair deliberately.
---

AliKit is source-level Odin that imports Alicorn's public packages. It does not vendor Alicorn,
copy private runtime storage, or provide a compatibility shim for a different revision. The
repository records the exact upstream revisions in
[`dependencies.lock.json`](https://github.com/samanshaiza004/alicorn-kit/blob/main/dependencies.lock.json).

## Current pin

| Dependency | Repository | Revision |
| --- | --- | --- |
| Alicorn | `https://github.com/Carnival-Science/Alicorn.git` | `47c9d4a7cd1f637876190fec899daeeac00a30ae` (`master`) |
| AccessKit binding | `https://github.com/samanshaiza004/odin-accesskit.git` | `e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b` |

The native captures in this catalog were produced from the examples built against that Alicorn
revision with the SDL_GPU Direct3D 12 backend on Windows.

## What "source-level" means

- There is no binary AliKit artifact, versioned runtime, or package manager registration.
- The API may change with Alicorn. Pin both projects together and update deliberately.
- A component may be copied into an application. The copy is application code and may change
  drawing, layout, or behavior; the original tests are the reference contract.
- AliKit never imports an application and Alicorn never imports AliKit. The dependency direction
  is one-way.

## Updating the pin

1. Update `dependencies.lock.json` and the Alicorn checkout under `alicorn/`.
2. Update the AccessKit binding pin to the revision Alicorn already requires.
3. Run `./tools/test.ps1 -Odin odin` on Windows. It checks the models, retained component
   behavior, every native example, theme contracts, the `.Roving_List` and `.Modal_Dialog`
   pattern checks, and a copied-source build.
4. Rebuild the examples and re-capture the catalog with
   `./tools/capture_catalog.ps1 -BinDir out -OutDir website/public/captures`.
5. Update `components.json` and this table with the new revision.

Headless tests do not validate operating-system IME candidate windows, physical screen-reader
sessions, or pixels. Native smoke runs cover SDL_GPU startup and one submitted frame; use the
platform validation tools when a change touches host input, text, or rendering.
