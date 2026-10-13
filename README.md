# digitalhoneycomb.com

Astro site for Digital Honeycomb, built on the same structure as missional.io.

| Command           | Action                                  |
| :---------------- | :-------------------------------------- |
| `npm install`     | Install dependencies                    |
| `npm run dev`     | Dev server at `localhost:4321`          |
| `npm run build`   | Build to `./dist/`                      |
| `npm run preview` | Preview the production build locally    |

- Content: `src/pages/index.astro` (services and steps are arrays at the top).
- Contact address: `src/config.ts`.
- Icons: edit `public/favicon.svg`, then run `node scripts/make-icons.cjs`.
- Deploy: `.github/workflows/deploy.yml` publishes to GitHub Pages on push to `main`.
