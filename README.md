# Talk Manager

Talk Manager is a browser dashboard backed by Supabase Auth and Postgres. It does not seed sample metrics or campaign rows. Until a project is configured and a Discord server membership is provisioned, the dashboard shows setup and empty states.

## Connect a Supabase project

1. Create or select a Supabase project.
2. Apply `supabase/migrations/0001_initial.sql` from the SQL Editor after reviewing it.
3. Put the project URL and **publishable** key from the Supabase Connect dialog in `config.js` and deploy the updated file. This shares the same project connection with every visitor. Until configured globally, a browser can enter its own connection on the setup screen for private testing.
4. Sign in with a Supabase Auth account. Configure allowed redirect URLs and email confirmation in Supabase Auth for your deployment domain.
5. Provision a `server_memberships` row only from a trusted setup flow that verifies the user's Discord identity and permissions. Do not let a browser create its own owner membership.

The project URL and publishable key are public client values. All access still depends on Row Level Security. Never enter or publish a Supabase secret/service-role key in Talk Manager.

## Current live features

- Supabase email/password sign-in and account registration.
- Server memberships and server names read from Supabase.
- Campaign lists and draft create, edit, and delete operations stored in Supabase.
- Real empty states when there are no servers or campaigns.

No Discord bot worker, moderation actions, analytics, scheduled job, or social publishing provider is active. Those features require server-side services and must remain unavailable until implemented. The browser never receives a Discord bot token.

## Discord bot deployment

The bot token should be added only as a server-side environment secret on the host running the persistent Discord Gateway worker. Do not send the token in chat, add it to this repository, or paste it into the browser dashboard. A worker must verify guild membership and Discord permissions, provision server membership records, and implement authorized endpoints before privileged dashboard actions can be enabled. Supabase service-role credentials must also remain server-side.

GitHub Pages can host the static dashboard, while the Discord bot and scheduled worker need a persistent backend host. Supabase Auth's allowed redirect URLs must include the deployed site URL.

## Configuration

`config.js` holds the shared browser connection values. `.env.example` lists server-only configuration names for a future bot worker; those secrets are not read by the browser.

## Project map

```text
index.html                 Supabase-authenticated dashboard
supabase/migrations/       Initial schema and row-level security policies
.env.example               Configuration names only; no credentials
vercel.json                Static deployment security headers
```
