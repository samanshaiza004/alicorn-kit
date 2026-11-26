# AliKit catalog website

The AliKit component catalog: runnable Odin examples, copyable source, ownership and input
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

## Local visual checks

The documentation does not include screenshots of desktop applications. On Windows, the optional
capture script can still produce local SDL_GPU screenshots for visual review; they are written to
`out/catalog-captures/` by default and are not part of the website.

Rebuild the examples and re-capture:

```powershell
# From the repository root, with the pinned Alicorn checkout at ./alicorn
./tools/test.ps1 -Odin odin
./tools/capture_catalog.ps1 -BinDir out -OutDir out/catalog-captures
```

The capture script uses SDL_GPU Direct3D 12 on Windows and the exact Alicorn pin in
`dependencies.lock.json`.

## Develop and build

```powershell
cd website
npm ci
npm run dev      # http://localhost:4321
npm run build    # static output in dist/
npm run preview
```

The `predev`, `prestart`, and `prebuild` hooks copy the repository-root `components.json` into
`public/components.json` and stage the authored SVG design targets in
`public/reference-previews/`. The target SVGs stay canonical under
`docs/research/authoring-reliability/references/`; they are labeled as illustrations and are not
captures of desktop-app output.

## GitHub Pages

The standalone catalog site is **retired**. The catalog is published in the Alicorn documentation
site at <https://carnival-science.github.io/Alicorn/components/>, which syncs these pages and
`components.json` at a pinned revision.

When syncing pages that include `ReferencePreview`, also copy
`website/public/reference-previews/*.svg` to the documentation site's
`reference-previews/` path. These generated assets come from the canonical SVGs under
`docs/research/authoring-reliability/references/`.

`.github/workflows/pages.yml` now deploys only `website/redirect/`: an index page and a 404 page
that forward the old URL — including per-component paths, `manifest/`, and `compatibility/` — to
the consolidated site. The catalog source stays here because this repository remains the authoring
home for component documentation; update a page here and then re-sync the Alicorn site.

To preview the catalog locally, `npm run dev` still works. `npm run build` still emits the full
standalone site in `dist/`; it is simply no longer what Pages serves.

## Content map

- `src/content/docs/index.mdx` — catalog landing page and grid.
- `src/content/docs/components.mdx` — package catalog and ownership overview.
- `src/content/docs/components/*.mdx` — one page per component, in the consistent order:
  runnable example, responsibility split, copyable implementation, parts, styling/theme, keyboard and
  accessibility, conformance tests, API, limits, compatibility, source map.
- `src/content/docs/compatibility.md` — the Alicorn/AccessKit pin and update procedure.
- `src/content/docs/manifest.mdx` — the machine-readable registry seed.
The site publishes source examples and API contracts; it does not recreate components in
JavaScript or embed desktop screenshots.
