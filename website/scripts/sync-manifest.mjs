// Copy the repository-root component registry beside the static site so the
// catalog's download link and the machine-readable seed cannot drift.
import { copyFileSync, mkdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const source = join(here, '..', '..', 'components.json');
const target = join(here, '..', 'public', 'components.json');
const registry = JSON.parse(readFileSync(source, 'utf8'));
mkdirSync(dirname(target), { recursive: true });
copyFileSync(source, target);
console.log(`components.json -> ${target}`);

// The catalog uses authored layout targets as design references. Keep one
// canonical copy in docs/research and stage the images beside the static site.
// These are illustrations, not screenshots of Alicorn output.
const referenceNames = registry.components.map((component) => component.id);
const referenceSource = join(
  here,
  '..',
  '..',
  'docs',
  'research',
  'authoring-reliability',
  'references',
);
const referenceTarget = join(here, '..', 'public', 'reference-previews');
mkdirSync(referenceTarget, { recursive: true });
for (const name of referenceNames) {
  const from = join(referenceSource, `${name}.svg`);
  const to = join(referenceTarget, `${name}.svg`);
  copyFileSync(from, to);
  console.log(`${name}.svg -> ${to}`);
}
