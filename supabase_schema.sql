-- ============================================================================
-- AssembleAI — Production & Future-Proof Supabase PostgreSQL Database Schema
-- ============================================================================
-- Instructions:
-- 1. Log in to your Supabase Dashboard: https://supabase.com/dashboard
-- 2. Select your project -> SQL Editor -> "+ New query"
-- 3. Paste this complete script and click "Run"
--
-- This script is completely IDEMPOTENT: it safely drops existing policies/triggers
-- before creating them, so you can re-run it anytime without errors.
-- ============================================================================

-- Enable standard UUID generator
create extension if not exists "uuid-ossp";

-- ============================================================================
-- 0. Reusable Helper Functions (Updated At Triggers & User Self-Deletion)
-- ============================================================================

-- Auto-update updated_at timestamp on any table modification
create or replace function public.handle_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

-- Secure self-deletion RPC for Apple App Store Guideline 5.1.1(v) compliance
create or replace function public.delete_user_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
    if auth.uid() is null then
        raise exception 'Not authenticated';
    end if;
    delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_user_account() from public;
revoke all on function public.delete_user_account() from anon;
grant execute on function public.delete_user_account() to authenticated;

-- ============================================================================
-- 1. Profiles Table (1:1 with Supabase auth.users)
-- ============================================================================
create table if not exists public.profiles (
    id uuid references auth.users(id) on delete cascade primary key,
    full_name text,
    email text,
    avatar_url text,
    avatar_symbol text default 'person.crop.circle.fill',
    avatar_color_hex text default '#0A84FF',
    bio text default '',
    preferences jsonb default '{}'::jsonb,
    experience_level text default 'Beginner',
    total_assembly_minutes integer default 0,
    completed_sessions_count integer default 0,
    is_admin boolean default false not null,
    created_at timestamptz default now() not null,
    updated_at timestamptz default now() not null
);

-- Ensure all columns exist idempotently if the table was created previously (prevents ERROR 42703)
alter table public.profiles add column if not exists full_name text;
alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists avatar_symbol text default 'person.crop.circle.fill';
alter table public.profiles add column if not exists avatar_color_hex text default '#0A84FF';
alter table public.profiles add column if not exists bio text default '';
alter table public.profiles add column if not exists preferences jsonb default '{}'::jsonb;
alter table public.profiles add column if not exists experience_level text default 'Beginner';
alter table public.profiles add column if not exists total_assembly_minutes integer default 0;
alter table public.profiles add column if not exists completed_sessions_count integer default 0;
alter table public.profiles add column if not exists is_admin boolean default false not null;
alter table public.profiles add column if not exists created_at timestamptz default now() not null;
alter table public.profiles add column if not exists updated_at timestamptz default now() not null;

-- Helper function to check if current user is an App Owner / Administrator
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
as $$
    select coalesce(
        (select is_admin from public.profiles where id = auth.uid()),
        false
    );
$$;

grant execute on function public.is_admin() to authenticated;

alter table public.profiles enable row level security;

drop policy if exists "Users can view own profile" on public.profiles;
drop policy if exists "Users can view profiles" on public.profiles;
create policy "Users can view profiles"
    on public.profiles for select
    using (auth.uid() = id or auth.role() = 'authenticated');

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
    on public.profiles for insert
    with check (auth.uid() = id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
    on public.profiles for update
    using (auth.uid() = id)
    with check (
        auth.uid() = id
        and (
            -- Prevent vertical privilege escalation: regular users cannot set is_admin = true
            is_admin = false or public.is_admin()
        )
    );

-- Trigger to automatically create a public profile on auth.users signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
    insert into public.profiles (
        id, 
        full_name, 
        email, 
        avatar_url, 
        avatar_symbol, 
        avatar_color_hex, 
        is_admin
    )
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
        new.email,
        new.raw_user_meta_data->>'avatar_url',
        coalesce(new.raw_user_meta_data->>'avatar_symbol', 'person.crop.circle.fill'),
        coalesce(new.raw_user_meta_data->>'avatar_color_hex', '#0A84FF'),
        false
    )
    on conflict (id) do update set
        full_name = coalesce(excluded.full_name, public.profiles.full_name),
        email = coalesce(excluded.email, public.profiles.email),
        updated_at = now();
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user();

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
    before update on public.profiles
    for each row execute procedure public.handle_updated_at();

-- ============================================================================
-- 2. Projects Table
-- ============================================================================
create table if not exists public.projects (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid references auth.users(id) on delete cascade,
    title text not null,
    description text default '',
    difficulty text default 'Beginner',
    estimated_minutes integer default 30,
    thumbnail_path text,
    category text default 'General Assembly',
    is_public boolean default true,
    sync_state text default 'synced',
    created_at timestamptz default now() not null,
    updated_at timestamptz default now() not null
);

-- Idempotent column upgrades for projects
alter table public.projects add column if not exists owner_id uuid references auth.users(id) on delete cascade;
alter table public.projects add column if not exists title text;
alter table public.projects add column if not exists description text default '';
alter table public.projects add column if not exists difficulty text default 'Beginner';
alter table public.projects add column if not exists estimated_minutes integer default 30;
alter table public.projects add column if not exists thumbnail_path text;
alter table public.projects add column if not exists category text default 'General Assembly';
alter table public.projects add column if not exists is_public boolean default true;
alter table public.projects add column if not exists sync_state text default 'synced';
alter table public.projects add column if not exists created_at timestamptz default now() not null;
alter table public.projects add column if not exists updated_at timestamptz default now() not null;

alter table public.projects enable row level security;

drop policy if exists "Users can view own or public projects" on public.projects;
create policy "Users can view own or public projects"
    on public.projects for select
    using (auth.uid() = owner_id or is_public = true or owner_id is null);

drop policy if exists "Admins can insert projects" on public.projects;
drop policy if exists "Users can insert own projects" on public.projects;
create policy "Users can insert own projects"
    on public.projects for insert
    with check (auth.uid() = owner_id or public.is_admin());

drop policy if exists "Admins can update projects" on public.projects;
drop policy if exists "Users can update own projects" on public.projects;
create policy "Users can update own projects"
    on public.projects for update
    using (auth.uid() = owner_id or public.is_admin());

drop policy if exists "Admins can delete projects" on public.projects;
drop policy if exists "Users can delete own projects" on public.projects;
create policy "Users can delete own projects"
    on public.projects for delete
    using (auth.uid() = owner_id or public.is_admin());

drop trigger if exists set_projects_updated_at on public.projects;
create trigger set_projects_updated_at
    before update on public.projects
    for each row execute procedure public.handle_updated_at();

-- ============================================================================
-- 3. Assembly Steps Table
-- ============================================================================
create table if not exists public.assembly_steps (
    id uuid primary key default gen_random_uuid(),
    project_id uuid references public.projects(id) on delete cascade not null,
    step_order integer not null,
    title text not null,
    instruction text default '',
    expected_state text default '{}',
    expected_duration_minutes integer default 2,
    common_mistakes jsonb default '[]'::jsonb,
    created_at timestamptz default now() not null,
    updated_at timestamptz default now() not null
);

-- Idempotent column upgrades for assembly_steps
alter table public.assembly_steps add column if not exists project_id uuid references public.projects(id) on delete cascade;
alter table public.assembly_steps add column if not exists step_order integer;
alter table public.assembly_steps add column if not exists title text;
alter table public.assembly_steps add column if not exists instruction text default '';
alter table public.assembly_steps add column if not exists expected_state text default '{}';
alter table public.assembly_steps add column if not exists expected_duration_minutes integer default 2;
alter table public.assembly_steps add column if not exists common_mistakes jsonb default '[]'::jsonb;
alter table public.assembly_steps add column if not exists created_at timestamptz default now() not null;
alter table public.assembly_steps add column if not exists updated_at timestamptz default now() not null;

alter table public.assembly_steps enable row level security;

drop policy if exists "Users can view steps of accessible projects" on public.assembly_steps;
create policy "Users can view steps of accessible projects"
    on public.assembly_steps for select
    using (
        exists (
            select 1 from public.projects
            where projects.id = assembly_steps.project_id
            and (projects.owner_id = auth.uid() or projects.is_public = true or projects.owner_id is null)
        )
    );

drop policy if exists "Admins can manage assembly steps" on public.assembly_steps;
drop policy if exists "Users can manage steps of own projects" on public.assembly_steps;
create policy "Users can manage steps of own projects"
    on public.assembly_steps for all
    using (
        exists (
            select 1 from public.projects
            where projects.id = assembly_steps.project_id
            and (projects.owner_id = auth.uid() or public.is_admin())
        )
    );

drop trigger if exists set_assembly_steps_updated_at on public.assembly_steps;
create trigger set_assembly_steps_updated_at
    before update on public.assembly_steps
    for each row execute procedure public.handle_updated_at();

-- ============================================================================
-- 4. Components Table
-- ============================================================================
create table if not exists public.components (
    id uuid primary key default gen_random_uuid(),
    project_id uuid references public.projects(id) on delete cascade not null,
    name text not null,
    type text not null,
    description text default '',
    metadata text default '{}',
    part_id text,
    is_required boolean default true,
    quantity integer default 1,
    created_at timestamptz default now() not null,
    updated_at timestamptz default now() not null
);

-- Idempotent column upgrades for components
alter table public.components add column if not exists project_id uuid references public.projects(id) on delete cascade;
alter table public.components add column if not exists name text;
alter table public.components add column if not exists type text;
alter table public.components add column if not exists description text default '';
alter table public.components add column if not exists metadata text default '{}';
alter table public.components add column if not exists part_id text;
alter table public.components add column if not exists is_required boolean default true;
alter table public.components add column if not exists quantity integer default 1;
alter table public.components add column if not exists created_at timestamptz default now() not null;
alter table public.components add column if not exists updated_at timestamptz default now() not null;

alter table public.components enable row level security;

drop policy if exists "Users can view components of accessible projects" on public.components;
create policy "Users can view components of accessible projects"
    on public.components for select
    using (
        exists (
            select 1 from public.projects
            where projects.id = components.project_id
            and (projects.owner_id = auth.uid() or projects.is_public = true or projects.owner_id is null)
        )
    );

drop policy if exists "Admins can manage components" on public.components;
drop policy if exists "Users can manage components of own projects" on public.components;
create policy "Users can manage components of own projects"
    on public.components for all
    using (
        exists (
            select 1 from public.projects
            where projects.id = components.project_id
            and (projects.owner_id = auth.uid() or public.is_admin())
        )
    );

-- ============================================================================
-- 5. Assembly Sessions Table
-- ============================================================================
create table if not exists public.assembly_sessions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade,
    project_id uuid references public.projects(id) on delete cascade not null,
    project_title text default '',
    status text not null default 'in_progress',
    current_step_index integer default 0,
    current_step_order integer default 1,
    completed_steps integer[] default '{}',
    attempts integer default 0,
    errors integer default 0,
    sync_state text default 'synced',
    started_at timestamptz default now() not null,
    ended_at timestamptz,
    created_at timestamptz default now() not null,
    updated_at timestamptz default now() not null
);

-- Idempotent column upgrades for assembly_sessions
alter table public.assembly_sessions add column if not exists user_id uuid references auth.users(id) on delete cascade;
alter table public.assembly_sessions alter column user_id drop not null;
alter table public.assembly_sessions add column if not exists project_title text default '';
alter table public.assembly_sessions add column if not exists completed_steps integer[] default '{}';
alter table public.assembly_sessions add column if not exists sync_state text default 'synced';
alter table public.assembly_sessions add column if not exists current_step_order integer default 1;
alter table public.assembly_sessions add column if not exists current_step_index integer default 0;

alter table public.assembly_sessions enable row level security;

drop policy if exists "Users can view own assembly sessions" on public.assembly_sessions;
create policy "Users can view own assembly sessions"
    on public.assembly_sessions for select
    using (auth.uid() = user_id or user_id is null);

drop policy if exists "Users can insert own assembly sessions" on public.assembly_sessions;
create policy "Users can insert own assembly sessions"
    on public.assembly_sessions for insert
    with check (auth.uid() = user_id or user_id is null);

drop policy if exists "Users can update own assembly sessions" on public.assembly_sessions;
create policy "Users can update own assembly sessions"
    on public.assembly_sessions for update
    using (auth.uid() = user_id or user_id is null);

drop policy if exists "Users can delete own assembly sessions" on public.assembly_sessions;
create policy "Users can delete own assembly sessions"
    on public.assembly_sessions for delete
    using (auth.uid() = user_id or user_id is null);

drop trigger if exists set_assembly_sessions_updated_at on public.assembly_sessions;
create trigger set_assembly_sessions_updated_at
    before update on public.assembly_sessions
    for each row execute procedure public.handle_updated_at();

-- ============================================================================
-- 6. Attempts Table (Step-level Verification Telemetry)
-- ============================================================================
create table if not exists public.attempts (
    id uuid primary key default gen_random_uuid(),
    session_id uuid references public.assembly_sessions(id) on delete cascade not null,
    step_id uuid references public.assembly_steps(id) on delete cascade not null,
    attempt_number integer not null default 1,
    status text not null default 'uncertain',
    confidence double precision default 0.0,
    detected_state text default '{}',
    explanation text default '',
    created_at timestamptz default now() not null
);

alter table public.attempts enable row level security;

drop policy if exists "Users can view attempts of own sessions" on public.attempts;
create policy "Users can view attempts of own sessions"
    on public.attempts for select
    using (
        exists (
            select 1 from public.assembly_sessions
            where assembly_sessions.id = attempts.session_id
            and (assembly_sessions.user_id = auth.uid() or assembly_sessions.user_id is null)
        )
    );

drop policy if exists "Users can insert attempts of own sessions" on public.attempts;
create policy "Users can insert attempts of own sessions"
    on public.attempts for insert
    with check (
        exists (
            select 1 from public.assembly_sessions
            where assembly_sessions.id = attempts.session_id
            and (assembly_sessions.user_id = auth.uid() or assembly_sessions.user_id is null)
        )
    );

-- ============================================================================
-- 7. Research Sessions Table (Autonomous Telemetry Benchmarks)
-- ============================================================================
create table if not exists public.research_sessions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete set null,
    session_id uuid not null,
    project_id text,
    mode text,
    visual_strategy text,
    strategy_name text,
    last_n_frames integer default 0,
    task_completion_seconds double precision default 0.0,
    completed_steps_count integer default 0,
    total_verification_attempts integer default 0,
    error_count integer default 0,
    uncertain_count integer default 0,
    total_correction_seconds double precision default 0.0,
    intervention_count integer default 0,
    user_question_count integer default 0,
    nominal_count integer default 0,
    e_pol_count integer default 0,
    e_sub_count integer default 0,
    e_off_count integer default 0,
    e_seat_count integer default 0,
    verification_accuracy_pct double precision default 0.0,
    avg_latency_ms double precision default 0.0,
    peak_memory_mb double precision default 0.0,
    device_model text,
    os_version text,
    raw_payload jsonb default '{}'::jsonb,
    started_at timestamptz default now() not null,
    ended_at timestamptz default now() not null,
    created_at timestamptz default now() not null
);

alter table public.research_sessions enable row level security;

drop policy if exists "Users can view own research sessions" on public.research_sessions;
create policy "Users can view own research sessions"
    on public.research_sessions for select
    using (auth.uid() = user_id or public.is_admin());

drop policy if exists "Anyone authenticated can insert research sessions" on public.research_sessions;
create policy "Anyone authenticated can insert research sessions"
    on public.research_sessions for insert
    with check (auth.role() = 'authenticated' or auth.role() = 'anon');

-- ============================================================================
-- 8. High-Performance Indexes
-- ============================================================================
create index if not exists idx_profiles_email on public.profiles(email);
create index if not exists idx_projects_owner on public.projects(owner_id);
create index if not exists idx_projects_updated_at on public.projects(updated_at desc);
create index if not exists idx_projects_public_updated on public.projects(is_public, updated_at desc);
create index if not exists idx_steps_project on public.assembly_steps(project_id, step_order);
create index if not exists idx_components_project on public.components(project_id);
create index if not exists idx_sessions_user_project on public.assembly_sessions(user_id, project_id);
create index if not exists idx_sessions_user_status on public.assembly_sessions(user_id, status);
create index if not exists idx_sessions_updated_at on public.assembly_sessions(updated_at desc);
create index if not exists idx_attempts_session on public.attempts(session_id);
create index if not exists idx_research_sessions_session on public.research_sessions(session_id);
create index if not exists idx_research_sessions_user on public.research_sessions(user_id, created_at desc);

-- ============================================================================
-- 9. Realtime Replication Publication
-- ============================================================================
do $$
begin
    if not exists (
        select 1 from pg_publication_tables 
        where pubname = 'supabase_realtime' 
        and schemaname = 'public' 
        and tablename = 'projects'
    ) then
        alter publication supabase_realtime add table public.projects;
    end if;

    if not exists (
        select 1 from pg_publication_tables 
        where pubname = 'supabase_realtime' 
        and schemaname = 'public' 
        and tablename = 'assembly_sessions'
    ) then
        alter publication supabase_realtime add table public.assembly_sessions;
    end if;

    if not exists (
        select 1 from pg_publication_tables 
        where pubname = 'supabase_realtime' 
        and schemaname = 'public' 
        and tablename = 'profiles'
    ) then
        alter publication supabase_realtime add table public.profiles;
    end if;
end $$;

-- ============================================================================
-- 10. Storage Buckets & Policies (Avatars, Project Assets & Verification)
-- ============================================================================
insert into storage.buckets (id, name, public)
values 
    ('avatars', 'avatars', true),
    ('project-assets', 'project-assets', false),
    ('verification-snapshots', 'verification-snapshots', false)
on conflict (id) do update set public = excluded.public;

-- Avatars bucket policies (public read, authenticated insert/update/delete)
drop policy if exists "Avatars are publicly accessible" on storage.objects;
create policy "Avatars are publicly accessible"
    on storage.objects for select
    using (bucket_id = 'avatars');

drop policy if exists "Users can upload their own avatar" on storage.objects;
create policy "Users can upload their own avatar"
    on storage.objects for insert
    with check (bucket_id = 'avatars' and auth.role() = 'authenticated');

drop policy if exists "Users can update their own avatar" on storage.objects;
create policy "Users can update their own avatar"
    on storage.objects for update
    using (bucket_id = 'avatars' and auth.role() = 'authenticated');

drop policy if exists "Users can delete their own avatar" on storage.objects;
create policy "Users can delete their own avatar"
    on storage.objects for delete
    using (bucket_id = 'avatars' and auth.role() = 'authenticated');

-- Project Assets bucket policies
drop policy if exists "Users can view own or authenticated project assets" on storage.objects;
create policy "Users can view own or authenticated project assets"
    on storage.objects for select
    using (bucket_id = 'project-assets' and auth.role() = 'authenticated');

drop policy if exists "Authenticated users can upload project assets" on storage.objects;
drop policy if exists "Admins can upload project assets" on storage.objects;
create policy "Admins can upload project assets"
    on storage.objects for insert
    with check (bucket_id = 'project-assets' and (public.is_admin() or auth.role() = 'authenticated'));

drop policy if exists "Users can update own project assets" on storage.objects;
drop policy if exists "Admins can update project assets" on storage.objects;
create policy "Admins can update project assets"
    on storage.objects for update
    using (bucket_id = 'project-assets' and (public.is_admin() or auth.role() = 'authenticated'));

drop policy if exists "Users can delete own project assets" on storage.objects;
drop policy if exists "Admins can delete project assets" on storage.objects;
create policy "Admins can delete project assets"
    on storage.objects for delete
    using (bucket_id = 'project-assets' and (public.is_admin() or auth.role() = 'authenticated'));

-- Verification Snapshots bucket policies
drop policy if exists "Users can view own verification snapshots" on storage.objects;
create policy "Users can view own verification snapshots"
    on storage.objects for select
    using (bucket_id = 'verification-snapshots' and auth.uid() = owner);

drop policy if exists "Users can upload own verification snapshots" on storage.objects;
create policy "Users can upload own verification snapshots"
    on storage.objects for insert
    with check (bucket_id = 'verification-snapshots' and auth.uid() = owner);

drop policy if exists "Users can update own verification snapshots" on storage.objects;
create policy "Users can update own verification snapshots"
    on storage.objects for update
    using (bucket_id = 'verification-snapshots' and auth.uid() = owner);

drop policy if exists "Users can delete own verification snapshots" on storage.objects;
create policy "Users can delete own verification snapshots"
    on storage.objects for delete
    using (bucket_id = 'verification-snapshots' and auth.uid() = owner);

