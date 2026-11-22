// Copy the repository-root component registry beside the static site so the
// catalog's download link and the machine-readable seed cannot drift.
import { copyFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const source = join(here, '..', '..', 'components.json');
const target = join(here, '..', 'public', 'components.json');
mkdirSync(dirname(target), { recursive: true });
copyFileSync(source, target);
console.log(`components.json -> ${target}`);
