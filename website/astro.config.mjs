// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

const repository = 'https://github.com/samanshaiza004/alicorn-kit';

export default defineConfig({
  site: process.env.PUBLIC_SITE_URL || undefined,
  base: process.env.PUBLIC_BASE_PATH || undefined,
  trailingSlash: 'ignore',
  build: { format: 'directory' },
  server: { port: Number(process.env.PORT) || 4321 },
  integrations: [
    starlight({
      title: 'AliKit',
      description:
        'Reusable, source-level Odin components for Alicorn. Native previews, copyable source, explicit contracts.',
      tagline: 'Bring the parts that fit. Keep your application policy.',
      favicon: '/favicon.svg',
      customCss: ['./src/styles/catalog.css'],
      editLink: { baseUrl: repository + '/edit/codex/website-catalog/website/' },
      lastUpdated: false,
      pagination: true,
      credits: false,
      disable404Route: true,
      social: [{ icon: 'github', label: 'GitHub', href: repository }],
      sidebar: [
        { label: 'Start here', items: [{ slug: '' }, { slug: 'components' }] },
        {
          label: 'Components',
          items: [
            { slug: 'components/command-palette' },
            { slug: 'components/tree-view' },
            { slug: 'components/icon-picker' },
            { slug: 'components/palette-parts' },
            { slug: 'components/radio-group' },
            { slug: 'components/progress' },
            { slug: 'components/notices' },
            { slug: 'components/sidebar' },
            { slug: 'components/table' },
          ],
        },
        { label: 'Reference', items: [{ slug: 'manifest' }, { slug: 'compatibility' }] },
      ],
      head: [
        { tag: 'meta', attrs: { name: 'theme-color', content: '#0e1017' } },
      ],
    }),
  ],
});
