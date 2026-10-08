# Deploy CLINK

## Backend
1. Create a free Supabase project.
2. Open SQL Editor and run `supabase.sql`.
3. Go to Project Settings → API.
4. Copy Project URL and the public anon key.
5. Put them in `config.js`.

## Hosting
### Vercel
Import this GitHub repository. Framework preset: Other. No build command required.

### Netlify
Import this GitHub repository. Build command: blank. Publish directory: `.`.

## Production before launch
- Add Privacy Policy and Terms.
- Add visible Report/Block controls and moderation/admin tools.
- Add account deletion.
- Add anti-spam/rate limiting.
- Keep exact home addresses private.
