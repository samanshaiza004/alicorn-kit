# AliKit catalog website

The first AliKit component catalog: native captures, copyable Odin source, ownership and input
contracts, test coverage, theme roles, API references, and known limits.

## Choice and rationale

We chose **Astro + Starlight** rather than a hand-written static HTML/CSS catalog.

- The catalog is intended to grow into the P1 component documentation surface. Starlight already
  provides navigation, search, accessible page chrome, dark/light themes, and a Markdown/MDX
  content pipeline, so adding a component is a content change rather than a layout project.
- It mirrors the structure of Alicorn's own `website/` (Astro + Starlight, `src/content/docs`,
  custom CSS), so the two projects can share conventions and eventually cross-link cleanly.
- The build is static. There is no server, no JavaScript recreation of a component, and no runtime
  dependency on the Alicorn repo. `npm run build` emits `dist/` for any static host.

The cost is a Node build toolchain and a dependency lockfile. That is acceptable for a docs site
that will gain P1 pages; a plain static site would have been smaller but would have reimplemented
navigation, search, and page chrome.

## Native captures

The PNGs under `public/captures/` are genuine SDL_GPU windows captured with `PrintWindow`
(`PW_RENDERFULLCONTENT`) after the real examples were launched and, where needed, driven through
their ordinary controls. They are not screenshots of a web recreation.

Rebuild the examples and re-capture:

```powershell
# From the repository root, with the pinned Alicorn checkout at ./alicorn
./tools/test.ps1 -Odin odin
./tools/capture_catalog.ps1 -BinDir out -OutDir website/public/captures
```

The capture script uses the SDL_GPU Direct3D 12 backend on Windows. Captures are pinned to the
Alicorn revision in `dependencies.lock.json`; update them when the pin changes.

## Develop and build

```powershell
cd website
npm ci
npm run dev      # http://localhost:4321
npm run build    # static output in dist/
npm run preview
```

`npm run build` first copies the repository-root `components.json` into `public/components.json`
so the registry download and the catalog cannot drift.

## GitHub Pages

`.github/workflows/pages.yml` builds and deploys the site with the standard
`configure-pages` / `upload-pages-artifact` / `deploy-pages` actions. It runs on pushes to `main`
and manual dispatch. The workflow derives the Astro `base` from the Pages API, so it works for a
project site under `/<repo>/` or a custom domain; `PUBLIC_BASE_PATH` and `PUBLIC_SITE_URL` are
build-time only.

**Pages is not enabled by this change.** A repository administrator must choose GitHub Pages as
the deployment source (GitHub Actions) in repository settings and run the workflow. Until then,
the site is verified locally with `npm run build` and the link checker.

## Content map

- `src/content/docs/index.mdx` — catalog landing page and grid.
- `src/content/docs/components.mdx` — package catalog and ownership overview.
- `src/content/docs/components/*.mdx` — one page per component, in the consistent order:
  preview, responsibility split, copyable implementation, parts, styling/theme, keyboard and
  accessibility, conformance tests, API, limits, compatibility, source map.
- `src/content/docs/compatibility.md` — the Alicorn/AccessKit pin and update procedure.
- `src/content/docs/manifest.mdx` — the machine-readable registry seed.
- `public/captures/` — native PNGs.

Interactive WebGPU previews are a later catalog step. The v1 preview is the native capture plus
the copyable source; the site intentionally does not recreate a component in JavaScript.
