-- Talk Manager initial schema. Additive migration; review before applying.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.servers (
  id uuid primary key default gen_random_uuid(),
  discord_guild_id text not null unique,
  name text not null,
  icon_url text,
  connected_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.server_memberships (
  server_id uuid not null references public.servers(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  app_role text not null check (app_role in ('owner','administrator','moderator','campaign_manager','analyst')),
  created_at timestamptz not null default now(),
  primary key (server_id,user_id)
);

create table if not exists public.campaigns (
  id uuid primary key default gen_random_uuid(),
  server_id uuid not null references public.servers(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  title text not null check (length(title) between 1 and 120),
  status text not null default 'draft' check (status in ('draft','scheduled','publishing','published','partial','failed','cancelled')),
  body text not null default '',
  scheduled_at timestamptz,
  timezone text not null default 'UTC',
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (status <> 'scheduled' or scheduled_at is not null)
);
create index if not exists campaigns_server_status_schedule_idx on public.campaigns(server_id,status,scheduled_at);

create table if not exists public.campaign_targets (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  platform text not null,
  provider_account_ref text,
  content_override text,
  status text not null default 'pending' check (status in ('pending','scheduled','published','failed','manual')),
  provider_post_ref text,
  published_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  unique(campaign_id,platform,provider_account_ref)
);

create table if not exists public.automation_rules (
  id uuid primary key default gen_random_uuid(),
  server_id uuid not null references public.servers(id) on delete cascade,
  name text not null,
  trigger_type text not null,
  rule_config jsonb not null default '{}'::jsonb,
  enabled boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.automation_runs (
  id uuid primary key default gen_random_uuid(),
  server_id uuid not null references public.servers(id) on delete cascade,
  rule_id uuid references public.automation_rules(id) on delete set null,
  idempotency_key text not null,
  status text not null check(status in ('queued','running','succeeded','failed','skipped')),
  result_summary text,
  created_at timestamptz not null default now(),
  finished_at timestamptz,
  unique(server_id,idempotency_key)
);

create table if not exists public.moderation_cases (
  id uuid primary key default gen_random_uuid(),
  server_id uuid not null references public.servers(id) on delete cascade,
  subject_discord_id text not null,
  moderator_user_id uuid references auth.users(id) on delete set null,
  action text not null check(action in ('warning','timeout','untimeout','kick','ban','unban')),
  reason text not null default '',
  expires_at timestamptz,
  discord_audit_ref text,
  created_at timestamptz not null default now()
);
create index if not exists moderation_server_created_idx on public.moderation_cases(server_id,created_at desc);

create table if not exists public.welcome_settings (
  server_id uuid primary key references public.servers(id) on delete cascade,
  enabled boolean not null default false,
  channel_discord_id text,
  message_template text not null default '',
  leave_enabled boolean not null default false,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

create table if not exists public.giveaways (
  id uuid primary key default gen_random_uuid(),
  server_id uuid not null references public.servers(id) on delete cascade,
  title text not null,
  status text not null default 'draft' check(status in ('draft','open','closed','cancelled')),
  eligibility jsonb not null default '{}'::jsonb,
  winner_discord_ids text[] not null default '{}',
  seed_commitment text,
  ends_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_events (
  id bigint generated always as identity primary key,
  server_id uuid not null references public.servers(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  event_type text not null,
  target_ref text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists audit_server_created_idx on public.audit_events(server_id,created_at desc);

create table if not exists public.server_preferences (
  server_id uuid primary key references public.servers(id) on delete cascade,
  preferences jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- Keep the RLS helper out of exposed schemas. Its fixed empty search_path and
-- qualified object names prevent search_path substitution; auth.uid() scopes every lookup.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;
create or replace function private.has_server_role(p_server_id uuid, allowed text[])
returns boolean language sql stable security definer set search_path = ''
as $$
  select (select auth.uid()) is not null and exists(
    select 1 from public.server_memberships m
    where m.server_id=p_server_id and m.user_id=(select auth.uid()) and m.app_role=any(allowed)
  )
$$;
revoke all on function private.has_server_role(uuid,text[]) from public;
revoke all on function private.has_server_role(uuid,text[]) from anon, authenticated;
grant execute on function private.has_server_role(uuid,text[]) to authenticated;

-- Supabase projects created after the Data API exposure change require explicit
-- table grants. These grants only make requests possible; RLS below authorizes rows.
grant usage on schema public to authenticated;
grant select, insert, update, delete on
  public.profiles, public.servers, public.server_memberships, public.campaigns,
  public.campaign_targets, public.automation_rules, public.automation_runs,
  public.moderation_cases, public.welcome_settings, public.giveaways,
  public.audit_events, public.server_preferences
to authenticated;
grant usage, select on all sequences in schema public to authenticated;

alter table public.profiles enable row level security;
alter table public.servers enable row level security;
alter table public.server_memberships enable row level security;
alter table public.campaigns enable row level security;
alter table public.campaign_targets enable row level security;
alter table public.automation_rules enable row level security;
alter table public.automation_runs enable row level security;
alter table public.moderation_cases enable row level security;
alter table public.welcome_settings enable row level security;
alter table public.giveaways enable row level security;
alter table public.audit_events enable row level security;
alter table public.server_preferences enable row level security;

create policy profiles_self_read on public.profiles for select to authenticated using(id=auth.uid());
create policy profiles_self_update on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy servers_member_read on public.servers for select to authenticated using(private.has_server_role(id,array['owner','administrator','moderator','campaign_manager','analyst']));
create policy memberships_member_read on public.server_memberships for select to authenticated using(private.has_server_role(server_id,array['owner','administrator','moderator','campaign_manager','analyst']));
create policy memberships_admin_write on public.server_memberships for all to authenticated using(private.has_server_role(server_id,array['owner','administrator'])) with check(private.has_server_role(server_id,array['owner','administrator']));
create policy campaigns_member_read on public.campaigns for select to authenticated using(private.has_server_role(server_id,array['owner','administrator','moderator','campaign_manager','analyst']));
create policy campaigns_manager_write on public.campaigns for all to authenticated using(private.has_server_role(server_id,array['owner','administrator','campaign_manager'])) with check(private.has_server_role(server_id,array['owner','administrator','campaign_manager']));
create policy targets_member_read on public.campaign_targets for select to authenticated using(exists(select 1 from public.campaigns c where c.id=campaign_id and private.has_server_role(c.server_id,array['owner','administrator','moderator','campaign_manager','analyst'])));
create policy targets_manager_write on public.campaign_targets for all to authenticated using(exists(select 1 from public.campaigns c where c.id=campaign_id and private.has_server_role(c.server_id,array['owner','administrator','campaign_manager']))) with check(exists(select 1 from public.campaigns c where c.id=campaign_id and private.has_server_role(c.server_id,array['owner','administrator','campaign_manager'])));
create policy automation_member_read on public.automation_rules for select to authenticated using(private.has_server_role(server_id,array['owner','administrator','moderator','analyst']));
create policy automation_admin_write on public.automation_rules for all to authenticated using(private.has_server_role(server_id,array['owner','administrator'])) with check(private.has_server_role(server_id,array['owner','administrator']));
create policy runs_member_read on public.automation_runs for select to authenticated using(private.has_server_role(server_id,array['owner','administrator','moderator','analyst']));
create policy moderation_staff_read on public.moderation_cases for select to authenticated using(private.has_server_role(server_id,array['owner','administrator','moderator']));
create policy moderation_staff_write on public.moderation_cases for insert to authenticated with check(private.has_server_role(server_id,array['owner','administrator','moderator']));
create policy welcome_member_read on public.welcome_settings for select to authenticated using(private.has_server_role(server_id,array['owner','administrator','moderator']));
create policy welcome_admin_write on public.welcome_settings for all to authenticated using(private.has_server_role(server_id,array['owner','administrator'])) with check(private.has_server_role(server_id,array['owner','administrator']));
create policy giveaways_member_read on public.giveaways for select to authenticated using(private.has_server_role(server_id,array['owner','administrator','moderator','campaign_manager','analyst']));
create policy giveaways_manager_write on public.giveaways for all to authenticated using(private.has_server_role(server_id,array['owner','administrator','moderator','campaign_manager'])) with check(private.has_server_role(server_id,array['owner','administrator','moderator','campaign_manager']));
create policy audit_staff_read on public.audit_events for select to authenticated using(private.has_server_role(server_id,array['owner','administrator','moderator','analyst']));
create policy preferences_member_read on public.server_preferences for select to authenticated using(private.has_server_role(server_id,array['owner','administrator','moderator','campaign_manager','analyst']));
create policy preferences_admin_write on public.server_preferences for all to authenticated using(private.has_server_role(server_id,array['owner','administrator'])) with check(private.has_server_role(server_id,array['owner','administrator']));
