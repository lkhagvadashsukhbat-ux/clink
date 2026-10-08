# CLINK Official Web MVP

CLINK is a 21+ social web app for meeting people nearby, adding friends, chatting, and sharing a temporary "Tonight" status.

## Stack
- GitHub: source
- Supabase Free: auth, Postgres database, avatar storage, realtime chat
- Vercel or Netlify: free static hosting

## Setup
1. Create a Supabase project.
2. Run `supabase.sql` in Supabase SQL Editor.
3. Copy Project URL and the public anon key into `config.js`.
4. Deploy this repository on Vercel or Netlify.

Never put the Supabase service-role key in browser code.

## MVP features
- Email/password signup and login
- 21+ profile
- Profile photo upload
- Province / district discovery
- Friend requests and accept
- Friends-only realtime chat
- Tonight status (home/out, group size, 6-hour expiry)
- Block/report database foundation
- RLS security
