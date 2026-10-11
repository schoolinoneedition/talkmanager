# Talk Manager

A lightweight, light-first control panel for the Talk Discord community. The included `index.html` runs without a build step and opens as a clearly labelled local demo. Dashboard figures and member rows are sample data; campaign drafts stay in browser memory and no messages are sent.

## Current capabilities

- Responsive application shell and navigation for the requested management areas.
- Demo overview with explicitly labelled sample figures and connection diagnostics.
- Local campaign draft creation, editing, duplication, search, status filtering, and copy workflow; drafts persist in this browser's local storage.
- Member-list layout with sample rows; privileged actions are intentionally unavailable until a secure Discord backend exists.
- Social integration setup matrix; no fake connected accounts or publishing claims.
- Supabase schema migration and environment-variable template for later integration.

The demo does **not** authenticate users, sync data with Supabase, connect to Discord, schedule jobs, or publish posts. Draft persistence is local to the current browser only. Do not use it as a live management console until OAuth, server-side authorization, and bot services have been configured and reviewed.

## Run locally

Open `index.html` in a browser, or serve the folder with any static HTTP server. No dependencies are needed for the frontend demo.

## Deploy

### GitHub Pages

Publish the contents of this folder as a static site. This provides the frontend demo only; no secrets are needed or supported in GitHub Pages.

### Vercel

Import the repository and deploy the project root as a static site. The included `vercel.json` supplies basic security headers. Serverless endpoints may be added for short OAuth exchanges or authorized API requests, but a Vercel function is not a persistent Discord Gateway process.

## Configure services later

1. Create a Supabase project and review `supabase/migrations/0001_initial.sql` before applying it.
2. Configure the values in `.env.example` in your deployment's secret environment. Never commit a populated `.env`.
3. Create a Discord application, configure exact OAuth redirect URLs, and create a bot with only the intents and permissions required by enabled features. Keep client secrets and bot tokens in server-side secrets.
4. Implement OAuth state validation, secure sessions, and authorization checks on every management endpoint. Verify the invoking user's guild membership and Discord permissions from trusted API data; never accept a guild ID or role claim as authorization.
5. Run the Discord Gateway bot and scheduled worker as a separate persistent service. A free host may sleep or impose runtime limits, so scheduled delivery may be delayed; verify the host's current limits before relying on it.
6. Add provider-specific OAuth/publishing adapters only where the account type and provider permissions allow it. Otherwise retain the labeled manual-copy path.

### Environment variables

See `.env.example`. Frontend values may include only the Supabase project URL and publishable/anon key. `SUPABASE_SERVICE_ROLE_KEY`, Discord bot tokens, OAuth client secrets, signing keys, and provider tokens are server-only and must never be exposed to browser JavaScript.

## Data and security notes

- The initial SQL is additive and does not drop existing objects.
- RLS is enabled on application tables. Policies require membership in the corresponding server; the first trusted owner membership must be provisioned through a verified server-side setup flow.
- Provider credentials are deliberately not stored in public tables. Store encrypted tokens in a private server-side vault/secret store and expose only non-sensitive connection metadata to the client.
- Campaign scheduling and audit data are persistent only after a backend is implemented. Add idempotency keys and safe retry handling to job execution.
- Privacy-conscious click attribution should store aggregate campaign events where possible, define retention, and avoid unnecessary personal identifiers.

## Project map

```text
index.html                 Static demo frontend
supabase/migrations/       Reviewed, additive SQL schema
.env.example               Placeholder configuration only
.gitignore                 Local secret/build exclusions
vercel.json                Static deployment security headers
```

## ZIP

The companion `Talk-Manager.zip` contains the complete project source and configuration template. It excludes real secrets, dependencies, and build output.
