-- ============================================================================
-- AssembleAI — Production & Future-Proof Supabase PostgreSQL Database Schema
-- ============================================================================
-- Instructions:
-- 1. Log in to your Supabase Dashboard: https://supabase.com/dashboard
-- 2. Select project (e.g. gbbsttpnmvfplmbumguq) -> SQL Editor -> "+ New query"
-- 3. Paste this complete script and click "Run"
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
returns void as $$
begin
    delete from auth.users where id = auth.uid();
end;
$$ language plpgsql security definer;

-- ============================================================================
-- 1. Profiles Table (1:1 with Supabase auth.users)
-- ============================================================================
create table if not exists public.profiles (
    id uuid references auth.users(id) on delete cascade primary key,
    full_name text,
    email text,
    avatar_url text,
    created_at timestamptz default now() not null,
    updated_at timestamptz default now() not null
);

alter table public.profiles enable row level security;

create policy "Users can view own profile"
    on public.profiles for select
    using (auth.uid() = id);

create policy "Users can update own profile"
    on public.profiles for update
    using (auth.uid() = id);

-- Trigger to automatically create a public profile on auth.users signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
    insert into public.profiles (id, full_name, email, avatar_url)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
        new.email,
        new.raw_user_meta_data->>'avatar_url'
    )
    on conflict (id) do update set
        full_name = coalesce(excluded.full_name, public.profiles.full_name),
        email = coalesce(excluded.email, public.profiles.email),
        updated_at = now();
    return new;
end;
$$ language plpgsql security definer;

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
    is_public boolean default false,
    sync_state text default 'synced',
    created_at timestamptz default now() not null,
    updated_at timestamptz default now() not null
);

alter table public.projects enable row level security;

create policy "Users can view own or public projects"
    on public.projects for select
    using (auth.uid() = owner_id or is_public = true or owner_id is null);

create policy "Users can insert own projects"
    on public.projects for insert
    with check (auth.uid() = owner_id);

create policy "Users can update own projects"
    on public.projects for update
    using (auth.uid() = owner_id);

create policy "Users can delete own projects"
    on public.projects for delete
    using (auth.uid() = owner_id);

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

create policy "Users can view steps of accessible projects"
    on public.assembly_steps for select
    using (
        exists (
            select 1 from public.projects
            where projects.id = assembly_steps.project_id
            and (projects.owner_id = auth.uid() or projects.is_public = true or projects.owner_id is null)
        )
    );

create policy "Users can manage steps of own projects"
    on public.assembly_steps for all
    using (
        exists (
            select 1 from public.projects
            where projects.id = assembly_steps.project_id
            and projects.owner_id = auth.uid()
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
    created_at timestamptz default now() not null
);

alter table public.components enable row level security;

create policy "Users can view components of accessible projects"
    on public.components for select
    using (
        exists (
            select 1 from public.projects
            where projects.id = components.project_id
            and (projects.owner_id = auth.uid() or projects.is_public = true or projects.owner_id is null)
        )
    );

create policy "Users can manage components of own projects"
    on public.components for all
    using (
        exists (
            select 1 from public.projects
            where projects.id = components.project_id
            and projects.owner_id = auth.uid()
        )
    );

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

create policy "Users can view own assembly sessions"
    on public.assembly_sessions for select
    using (auth.uid() = user_id);

create policy "Users can insert own assembly sessions"
    on public.assembly_sessions for insert
    with check (auth.uid() = user_id);

create policy "Users can update own assembly sessions"
    on public.assembly_sessions for update
    using (auth.uid() = user_id);

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

create policy "Users can view attempts of own sessions"
    on public.attempts for select
    using (
        exists (
            select 1 from public.assembly_sessions
            where assembly_sessions.id = attempts.session_id
            and assembly_sessions.user_id = auth.uid()
        )
    );

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
alter publication supabase_realtime add table public.projects;
alter publication supabase_realtime add table public.assembly_sessions;

-- ============================================================================
-- 9. Storage Buckets & Policies (Project Assets & Camera Frames)
-- ============================================================================
insert into storage.buckets (id, name, public)
values 
    ('project-assets', 'project-assets', true),
    ('verification-snapshots', 'verification-snapshots', false)
on conflict (id) do nothing;

create policy "Public can view project-assets"
    on storage.objects for select
    using (bucket_id = 'project-assets');

create policy "Authenticated users can upload project assets"
    on storage.objects for insert
    with check (bucket_id = 'project-assets' and auth.role() = 'authenticated');

create policy "Users can view own verification snapshots"
    on storage.objects for select
    using (bucket_id = 'verification-snapshots' and auth.uid() = owner);

create policy "Users can upload own verification snapshots"
    on storage.objects for insert
    with check (bucket_id = 'verification-snapshots' and auth.uid() = owner);
