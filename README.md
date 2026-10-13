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

## Contact form

The "Start a conversation" form inserts into a Supabase `contact_requests` table (insert-only for the public key). A database trigger emails each request through Resend, with the visitor as reply-to.

1. Run `supabase/migrations/001_contact_requests.sql` in the Supabase SQL Editor.
2. Create the three Vault secrets listed in that file (Resend API key, notify-to, notify-from).
3. Put the project URL and publishable key in `src/config.ts` and `.github/workflows/supabase-keepalive.yml`.
