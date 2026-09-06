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
    is_admin boolean default false not null,
    created_at timestamptz default now() not null,
    updated_at timestamptz default now() not null
);

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
create policy "Users can view own profile"
    on public.profiles for select
    using (auth.uid() = id);

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
    insert into public.profiles (id, full_name, email, avatar_url, is_admin)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
        new.email,
        new.raw_user_meta_data->>'avatar_url',
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
    is_public boolean default true,
    sync_state text default 'synced',
    created_at timestamptz default now() not null,
    updated_at timestamptz default now() not null
);

alter table public.projects enable row level security;

drop policy if exists "Users can view own or public projects" on public.projects;
create policy "Users can view own or public projects"
    on public.projects for select
    using (auth.uid() = owner_id or is_public = true or owner_id is null);

drop policy if exists "Users can insert own projects" on public.projects;
drop policy if exists "Admins can insert projects" on public.projects;
create policy "Admins can insert projects"
    on public.projects for insert
    with check (public.is_admin());

drop policy if exists "Users can update own projects" on public.projects;
drop policy if exists "Admins can update projects" on public.projects;
create policy "Admins can update projects"
    on public.projects for update
    using (public.is_admin());

drop policy if exists "Users can delete own projects" on public.projects;
drop policy if exists "Admins can delete projects" on public.projects;
create policy "Admins can delete projects"
    on public.projects for delete
    using (public.is_admin());

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
    created_at timestamptz default now() not null,
    updated_at timestamptz default now() not null
);

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

drop policy if exists "Users can manage steps of own projects" on public.assembly_steps;
drop policy if exists "Admins can manage assembly steps" on public.assembly_steps;
create policy "Admins can manage assembly steps"
    on public.assembly_steps for all
    using (public.is_admin());

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
    created_at timestamptz default now() not null
);

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

drop policy if exists "Users can manage components of own projects" on public.components;
drop policy if exists "Admins can manage components" on public.components;
create policy "Admins can manage components"
    on public.components for all
    using (public.is_admin());

-- ============================================================================
-- 5. Assembly Sessions Table
-- ============================================================================
create table if not exists public.assembly_sessions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null,
    project_id uuid references public.projects(id) on delete cascade not null,
    status text not null default 'in_progress',
    current_step_index integer default 0,
    current_step_order integer default 1,
    attempts integer default 0,
    errors integer default 0,
    started_at timestamptz default now() not null,
    ended_at timestamptz,
    created_at timestamptz default now() not null,
    updated_at timestamptz default now() not null
);

alter table public.assembly_sessions enable row level security;

drop policy if exists "Users can view own assembly sessions" on public.assembly_sessions;
create policy "Users can view own assembly sessions"
    on public.assembly_sessions for select
    using (auth.uid() = user_id);

drop policy if exists "Users can insert own assembly sessions" on public.assembly_sessions;
create policy "Users can insert own assembly sessions"
    on public.assembly_sessions for insert
    with check (auth.uid() = user_id);

drop policy if exists "Users can update own assembly sessions" on public.assembly_sessions;
create policy "Users can update own assembly sessions"
    on public.assembly_sessions for update
    using (auth.uid() = user_id);

drop policy if exists "Users can delete own assembly sessions" on public.assembly_sessions;
create policy "Users can delete own assembly sessions"
    on public.assembly_sessions for delete
    using (auth.uid() = user_id);

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
            and assembly_sessions.user_id = auth.uid()
        )
    );

drop policy if exists "Users can insert attempts of own sessions" on public.attempts;
create policy "Users can insert attempts of own sessions"
    on public.attempts for insert
    with check (
        exists (
            select 1 from public.assembly_sessions
            where assembly_sessions.id = attempts.session_id
            and assembly_sessions.user_id = auth.uid()
        )
    );

-- ============================================================================
-- 7. High-Performance Indexes
-- ============================================================================
create index if not exists idx_projects_owner on public.projects(owner_id);
create index if not exists idx_projects_updated_at on public.projects(updated_at desc);
create index if not exists idx_steps_project on public.assembly_steps(project_id, step_order);
create index if not exists idx_components_project on public.components(project_id);
create index if not exists idx_sessions_user_project on public.assembly_sessions(user_id, project_id);
create index if not exists idx_sessions_updated_at on public.assembly_sessions(updated_at desc);
create index if not exists idx_attempts_session on public.attempts(session_id);

-- ============================================================================
-- 8. Realtime Replication Publication
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
end $$;

-- ============================================================================
-- 9. Storage Buckets & Policies (Project Assets & Camera Frames)
-- ============================================================================
insert into storage.buckets (id, name, public)
values 
    ('project-assets', 'project-assets', false),
    ('verification-snapshots', 'verification-snapshots', false)
on conflict (id) do update set public = false;

drop policy if exists "Users can view own or authenticated project assets" on storage.objects;
create policy "Users can view own or authenticated project assets"
    on storage.objects for select
    using (bucket_id = 'project-assets' and auth.role() = 'authenticated');

drop policy if exists "Authenticated users can upload project assets" on storage.objects;
drop policy if exists "Authenticated users can upload project assets" on storage.objects;
drop policy if exists "Admins can upload project assets" on storage.objects;
create policy "Admins can upload project assets"
    on storage.objects for insert
    with check (bucket_id = 'project-assets' and public.is_admin());

drop policy if exists "Users can update own project assets" on storage.objects;
drop policy if exists "Admins can update project assets" on storage.objects;
create policy "Admins can update project assets"
    on storage.objects for update
    using (bucket_id = 'project-assets' and public.is_admin());

drop policy if exists "Users can delete own project assets" on storage.objects;
drop policy if exists "Admins can delete project assets" on storage.objects;
create policy "Admins can delete project assets"
    on storage.objects for delete
    using (bucket_id = 'project-assets' and public.is_admin());

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
