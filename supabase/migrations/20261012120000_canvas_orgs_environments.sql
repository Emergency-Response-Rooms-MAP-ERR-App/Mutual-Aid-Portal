-- Canvas: organizations, environments, mounts, access requests/grants, disclosure
-- policies, workflow requests, and organization_id on the core record tables.
--
-- Reverse-engineered from production (lhwxovefpwxylulnptwo) on 2026-10-12, where it
-- was applied by hand around 2026-10-08 without a migration. Every statement is
-- idempotent, so this is a no-op on production and brings dev (khavbdocjufkyhwpiniw)
-- up to date.

begin;

-- ---------------------------------------------------------------------------
-- New tables
-- ---------------------------------------------------------------------------

create table if not exists public.organizations (
  id uuid default gen_random_uuid() not null,
  slug text not null,
  name text not null,
  org_type text not null,
  ops_partner_id uuid,
  is_default_owner boolean default false not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.mount_catalog (
  code text not null,
  name text not null,
  description text,
  nav_group text,
  route_href text,
  sort_order integer default 0 not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.workflow_templates (
  code text not null,
  name text not null,
  description text,
  mount_codes text[] default '{}'::text[] not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.environments (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  slug text not null,
  display_name text not null,
  logo_url text,
  header_title text,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.environment_mounts (
  id uuid default gen_random_uuid() not null,
  environment_id uuid not null,
  mount_code text not null,
  sort_order integer default 0 not null,
  config jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.organization_memberships (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  organization_id uuid not null,
  environment_id uuid not null,
  is_default boolean default true not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.access_requests (
  id uuid default gen_random_uuid() not null,
  requesting_organization_id uuid not null,
  target_organization_id uuid not null,
  requested_by uuid,
  resource_type text default 'err_project'::text not null,
  resource_id uuid,
  scope text default 'record'::text not null,
  reason text,
  status text default 'pending'::text not null,
  decided_by uuid,
  decided_at timestamp with time zone,
  decision_note text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  states text[]
);

create table if not exists public.access_grants (
  id uuid default gen_random_uuid() not null,
  requesting_organization_id uuid not null,
  target_organization_id uuid not null,
  resource_type text default 'err_project'::text not null,
  resource_id uuid,
  access_request_id uuid,
  granted_by uuid,
  granted_at timestamp with time zone default now() not null,
  states text[]
);

create table if not exists public.disclosure_policies (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  resource_type text default 'err_project'::text not null,
  advertise_existence boolean default true not null,
  disclose_content boolean default false not null,
  stage_filter text[],
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.workflow_requests (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  requested_by uuid,
  title text not null,
  body text,
  status text default 'requested'::text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.grants_grid_view_vault_demo (
  id uuid not null,
  grant_id text,
  project_name text,
  grant_start_date date,
  grant_end_date date,
  status text,
  project_id text,
  sum_activity_amount numeric,
  sum_transfer_fee_amount numeric,
  transfer_segment text,
  allocations text,
  activities text,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  donor_id uuid,
  max_workplan_sequence integer,
  sync_status text,
  last_pushed_at timestamp with time zone,
  sync_target text,
  partner_id uuid,
  partner_name_secret_id uuid,
  donor_name_secret_id uuid,
  total_transferred_amount_usd_secret_id uuid,
  airtable_record_id_secret_id uuid
);

-- ---------------------------------------------------------------------------
-- organization_id on existing tables
-- ---------------------------------------------------------------------------

alter table public.distribution_decision_master_sheet_1 add column if not exists organization_id uuid;
alter table public.err_program_report add column if not exists organization_id uuid;
alter table public.err_projects add column if not exists organization_id uuid;
alter table public.err_summary add column if not exists organization_id uuid;
alter table public.fsps add column if not exists organization_id uuid;
alter table public.fund_requests add column if not exists organization_id uuid;
alter table public.grants_grid_view add column if not exists organization_id uuid;
alter table public.mous add column if not exists organization_id uuid;

-- ---------------------------------------------------------------------------
-- Constraints (Postgres has no "add constraint if not exists")
-- ---------------------------------------------------------------------------

do $$
declare
  c record;
begin
  for c in
    select * from (values
      -- primary keys, unique, check
      ('organizations', 'organizations_pkey', 'primary key (id)'),
      ('organizations', 'organizations_slug_key', 'unique (slug)'),
      ('organizations', 'organizations_org_type_check', $c$check (org_type = any (array['processor'::text, 'coordinator'::text, 'demo'::text]))$c$),
      ('mount_catalog', 'mount_catalog_pkey', 'primary key (code)'),
      ('workflow_templates', 'workflow_templates_pkey', 'primary key (code)'),
      ('environments', 'environments_pkey', 'primary key (id)'),
      ('environments', 'environments_organization_id_slug_key', 'unique (organization_id, slug)'),
      ('environment_mounts', 'environment_mounts_pkey', 'primary key (id)'),
      ('environment_mounts', 'environment_mounts_environment_id_mount_code_key', 'unique (environment_id, mount_code)'),
      ('organization_memberships', 'organization_memberships_pkey', 'primary key (id)'),
      ('organization_memberships', 'organization_memberships_user_id_environment_id_key', 'unique (user_id, environment_id)'),
      ('access_requests', 'access_requests_pkey', 'primary key (id)'),
      ('access_requests', 'access_requests_resource_type_check', $c$check (resource_type = any (array['err_project'::text, 'f1'::text, 'decisions'::text, 'fund_requests'::text, 'mous'::text, 'f4'::text, 'f5'::text]))$c$),
      ('access_requests', 'access_requests_scope_check', $c$check (scope = any (array['record'::text, 'org_resource_type'::text]))$c$),
      ('access_requests', 'access_requests_status_check', $c$check (status = any (array['pending'::text, 'approved'::text, 'denied'::text, 'revoked'::text]))$c$),
      ('access_grants', 'access_grants_pkey', 'primary key (id)'),
      ('access_grants', 'access_grants_resource_type_check', $c$check (resource_type = any (array['err_project'::text, 'f1'::text, 'decisions'::text, 'fund_requests'::text, 'mous'::text, 'f4'::text, 'f5'::text]))$c$),
      ('disclosure_policies', 'disclosure_policies_pkey', 'primary key (id)'),
      ('disclosure_policies', 'disclosure_policies_organization_id_resource_type_key', 'unique (organization_id, resource_type)'),
      ('disclosure_policies', 'disclosure_policies_resource_type_check', $c$check (resource_type = any (array['err_project'::text, 'f1'::text, 'decisions'::text, 'fund_requests'::text, 'mous'::text, 'f4'::text, 'f5'::text]))$c$),
      ('workflow_requests', 'workflow_requests_pkey', 'primary key (id)'),
      ('workflow_requests', 'workflow_requests_status_check', $c$check (status = any (array['requested'::text, 'in_progress'::text, 'available'::text, 'declined'::text]))$c$),
      ('grants_grid_view_vault_demo', 'grants_grid_view_vault_demo_pkey', 'primary key (id)'),
      -- foreign keys
      ('organizations', 'organizations_ops_partner_id_fkey', 'foreign key (ops_partner_id) references public.ops_partners(id) on delete set null'),
      ('environments', 'environments_organization_id_fkey', 'foreign key (organization_id) references public.organizations(id) on delete cascade'),
      ('environment_mounts', 'environment_mounts_environment_id_fkey', 'foreign key (environment_id) references public.environments(id) on delete cascade'),
      ('environment_mounts', 'environment_mounts_mount_code_fkey', 'foreign key (mount_code) references public.mount_catalog(code) on delete cascade'),
      ('organization_memberships', 'organization_memberships_environment_id_fkey', 'foreign key (environment_id) references public.environments(id) on delete cascade'),
      ('organization_memberships', 'organization_memberships_organization_id_fkey', 'foreign key (organization_id) references public.organizations(id) on delete cascade'),
      ('organization_memberships', 'organization_memberships_user_id_fkey', 'foreign key (user_id) references public.users(id) on delete cascade'),
      ('access_requests', 'access_requests_decided_by_fkey', 'foreign key (decided_by) references public.users(id) on delete set null'),
      ('access_requests', 'access_requests_requested_by_fkey', 'foreign key (requested_by) references public.users(id) on delete set null'),
      ('access_requests', 'access_requests_requesting_organization_id_fkey', 'foreign key (requesting_organization_id) references public.organizations(id) on delete cascade'),
      ('access_requests', 'access_requests_target_organization_id_fkey', 'foreign key (target_organization_id) references public.organizations(id) on delete cascade'),
      ('access_grants', 'access_grants_access_request_id_fkey', 'foreign key (access_request_id) references public.access_requests(id) on delete set null'),
      ('access_grants', 'access_grants_granted_by_fkey', 'foreign key (granted_by) references public.users(id) on delete set null'),
      ('access_grants', 'access_grants_requesting_organization_id_fkey', 'foreign key (requesting_organization_id) references public.organizations(id) on delete cascade'),
      ('access_grants', 'access_grants_target_organization_id_fkey', 'foreign key (target_organization_id) references public.organizations(id) on delete cascade'),
      ('disclosure_policies', 'disclosure_policies_organization_id_fkey', 'foreign key (organization_id) references public.organizations(id) on delete cascade'),
      ('workflow_requests', 'workflow_requests_organization_id_fkey', 'foreign key (organization_id) references public.organizations(id) on delete cascade'),
      ('workflow_requests', 'workflow_requests_requested_by_fkey', 'foreign key (requested_by) references public.users(id) on delete set null'),
      ('distribution_decision_master_sheet_1', 'distribution_decision_master_sheet_1_organization_id_fkey', 'foreign key (organization_id) references public.organizations(id) on delete set null'),
      ('err_program_report', 'err_program_report_organization_id_fkey', 'foreign key (organization_id) references public.organizations(id) on delete set null'),
      ('err_projects', 'err_projects_organization_id_fkey', 'foreign key (organization_id) references public.organizations(id) on delete set null'),
      ('err_summary', 'err_summary_organization_id_fkey', 'foreign key (organization_id) references public.organizations(id) on delete set null'),
      ('fsps', 'fsps_organization_id_fkey', 'foreign key (organization_id) references public.organizations(id) on delete set null'),
      ('fund_requests', 'fund_requests_organization_id_fkey', 'foreign key (organization_id) references public.organizations(id) on delete set null'),
      ('grants_grid_view', 'grants_grid_view_organization_id_fkey', 'foreign key (organization_id) references public.organizations(id) on delete set null'),
      ('mous', 'mous_organization_id_fkey', 'foreign key (organization_id) references public.organizations(id) on delete set null')
    ) as v(tbl, name, def)
  loop
    if not exists (
      select 1 from pg_constraint
      where conname = c.name and conrelid = format('public.%I', c.tbl)::regclass
    ) then
      execute format('alter table public.%I add constraint %I %s', c.tbl, c.name, c.def);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

create unique index if not exists organizations_one_default_owner_uidx on public.organizations using btree (is_default_owner) where is_default_owner;
create unique index if not exists organizations_ops_partner_id_uidx on public.organizations using btree (ops_partner_id) where (ops_partner_id is not null);
create index if not exists organizations_org_type_idx on public.organizations using btree (org_type) where is_active;
create index if not exists environments_organization_id_idx on public.environments using btree (organization_id);
create index if not exists environment_mounts_environment_id_idx on public.environment_mounts using btree (environment_id);
create unique index if not exists organization_memberships_user_default_uidx on public.organization_memberships using btree (user_id) where is_default;
create index if not exists organization_memberships_environment_id_idx on public.organization_memberships using btree (environment_id);
create index if not exists organization_memberships_user_id_idx on public.organization_memberships using btree (user_id);
create index if not exists access_requests_requesting_idx on public.access_requests using btree (requesting_organization_id, created_at desc);
create index if not exists access_requests_target_status_idx on public.access_requests using btree (target_organization_id, status, created_at desc);
create unique index if not exists access_grants_record_unique_idx on public.access_grants using btree (requesting_organization_id, target_organization_id, resource_type, resource_id) where (resource_id is not null);
create unique index if not exists access_grants_type_unique_idx on public.access_grants using btree (requesting_organization_id, target_organization_id, resource_type) where (resource_id is null);
create index if not exists access_grants_requesting_resource_idx on public.access_grants using btree (requesting_organization_id, resource_type, resource_id);
create index if not exists disclosure_policies_organization_id_idx on public.disclosure_policies using btree (organization_id);
create index if not exists workflow_requests_organization_id_idx on public.workflow_requests using btree (organization_id, created_at desc);
create index if not exists distribution_decision_master_sheet_1_organization_id_idx on public.distribution_decision_master_sheet_1 using btree (organization_id);
create index if not exists err_program_report_organization_id_idx on public.err_program_report using btree (organization_id);
create index if not exists err_projects_organization_id_idx on public.err_projects using btree (organization_id);
create index if not exists err_summary_organization_id_idx on public.err_summary using btree (organization_id);
create index if not exists fsps_organization_id_idx on public.fsps using btree (organization_id);
create index if not exists fund_requests_organization_id_idx on public.fund_requests using btree (organization_id);
create index if not exists grants_grid_view_organization_id_idx on public.grants_grid_view using btree (organization_id);
create index if not exists mous_organization_id_idx on public.mous using btree (organization_id);

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table public.organizations enable row level security;
alter table public.mount_catalog enable row level security;
alter table public.workflow_templates enable row level security;
alter table public.environments enable row level security;
alter table public.environment_mounts enable row level security;
alter table public.organization_memberships enable row level security;
alter table public.access_requests enable row level security;
alter table public.access_grants enable row level security;
alter table public.disclosure_policies enable row level security;
alter table public.workflow_requests enable row level security;
alter table public.grants_grid_view_vault_demo enable row level security;

drop policy if exists organizations_select_authenticated on public.organizations;
create policy organizations_select_authenticated on public.organizations
  for select to authenticated using (true);

drop policy if exists mount_catalog_select_authenticated on public.mount_catalog;
create policy mount_catalog_select_authenticated on public.mount_catalog
  for select to authenticated using (true);

drop policy if exists workflow_templates_select_authenticated on public.workflow_templates;
create policy workflow_templates_select_authenticated on public.workflow_templates
  for select to authenticated using (true);

drop policy if exists environments_select_authenticated on public.environments;
create policy environments_select_authenticated on public.environments
  for select to authenticated using (true);

drop policy if exists environment_mounts_select_authenticated on public.environment_mounts;
create policy environment_mounts_select_authenticated on public.environment_mounts
  for select to authenticated using (true);

drop policy if exists environment_mounts_write_authenticated on public.environment_mounts;
create policy environment_mounts_write_authenticated on public.environment_mounts
  for all to authenticated using (true) with check (true);

drop policy if exists organization_memberships_select_own on public.organization_memberships;
create policy organization_memberships_select_own on public.organization_memberships
  for select to authenticated
  using (user_id in (select u.id from public.users u where u.auth_user_id = auth.uid()));

drop policy if exists access_requests_select_authenticated on public.access_requests;
create policy access_requests_select_authenticated on public.access_requests
  for select to authenticated using (true);

drop policy if exists access_requests_write_authenticated on public.access_requests;
create policy access_requests_write_authenticated on public.access_requests
  for all to authenticated using (true) with check (true);

drop policy if exists access_grants_select_authenticated on public.access_grants;
create policy access_grants_select_authenticated on public.access_grants
  for select to authenticated using (true);

drop policy if exists access_grants_write_authenticated on public.access_grants;
create policy access_grants_write_authenticated on public.access_grants
  for all to authenticated using (true) with check (true);

drop policy if exists disclosure_policies_select_authenticated on public.disclosure_policies;
create policy disclosure_policies_select_authenticated on public.disclosure_policies
  for select to authenticated using (true);

drop policy if exists disclosure_policies_write_authenticated on public.disclosure_policies;
create policy disclosure_policies_write_authenticated on public.disclosure_policies
  for all to authenticated using (true) with check (true);

drop policy if exists workflow_requests_insert_authenticated on public.workflow_requests;
create policy workflow_requests_insert_authenticated on public.workflow_requests
  for insert to authenticated with check (true);

drop policy if exists workflow_requests_select_authenticated on public.workflow_requests;
create policy workflow_requests_select_authenticated on public.workflow_requests
  for select to authenticated using (true);

grant all on public.organizations, public.mount_catalog, public.workflow_templates,
  public.environments, public.environment_mounts, public.organization_memberships,
  public.access_requests, public.access_grants, public.disclosure_policies,
  public.workflow_requests, public.grants_grid_view_vault_demo
  to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Reference data (same IDs as production so environments line up)
-- ---------------------------------------------------------------------------

insert into public.organizations (id, slug, name, org_type, is_default_owner) values
  ('8425b7c2-70ad-4054-890b-84d669de4f4f', 'localization_hub', 'Localization Hub', 'processor', true),
  ('bbb2a578-642b-4064-bfe9-f6fcddcaa946', 'lcc', 'LCC', 'coordinator', false),
  ('c50f542b-8b99-4275-9fbf-657bb4d0fcb3', 'demo_empty', 'Demo Empty Org', 'processor', false)
on conflict do nothing;

insert into public.mount_catalog (code, name, description, nav_group, route_href, sort_order) values
  ('environment_home', 'Environment home', 'Catalog, templates, and workflow requests', 'system', '/err-portal/environment', 0),
  ('access_inbox', 'Access requests', 'Inbox for processor orgs to approve or deny access requests', 'system', '/err-portal/access-requests', 5),
  ('grant_decisions', 'Decisions', 'Grant distribution decisions', 'grant_management', '/err-portal/grant-management/decisions', 10),
  ('grant_grants', 'Grants', 'Grants grid', 'grant_management', '/err-portal/grant-management/grants', 20),
  ('grant_allocation', 'Allocation Management', 'Allocation management', 'grant_management', '/err-portal/grant-management/allocation-management', 30),
  ('f1_workplans', 'F1 Work Plans', 'F1 work plans', 'f_system', '/err-portal/f1-work-plans', 40),
  ('f2_approvals', 'F2 Approvals', 'F2 approvals', 'f_system', '/err-portal/f2-approvals', 50),
  ('f3_mous', 'F3 MOUs', 'F3 MOUs', 'f_system', '/err-portal/f3-mous', 60),
  ('f4_f5_reporting', 'F4 & F5 Reporting', 'F4 and F5 reporting', 'f_system', '/err-portal/f4-f5-reporting', 70),
  ('report_tracker', 'Report Tracker', 'Report tracker', 'reporting', '/err-portal/report-tracker', 80),
  ('oversight', 'Oversight', 'Coordinator view of disclosed and withheld processor projects', 'reporting', '/err-portal/oversight', 85),
  ('project_management', 'Project Management', 'Project management', 'reporting', '/err-portal/project-management', 90),
  ('dashboard', 'Dashboard', 'Dashboard', 'reporting', '/err-portal/dashboard', 100),
  ('learnings', 'Mutual Aid Learnings', 'Stories / learnings', 'reporting', '/err-portal/stories', 110),
  ('data_archive', 'Data Archive', 'Data archive', 'reporting', '/err-portal/data-archive', 120),
  ('room_management', 'Room Management', 'Emergency rooms', 'admin', '/err-portal/room-management', 130),
  ('state_management', 'State Management', 'States / localities', 'admin', '/err-portal/state-management', 140),
  ('user_management', 'User Management', 'Users and permissions', 'admin', '/err-portal/user-management', 150),
  ('audit_log', 'Audit Log', 'Audit log', 'admin', '/err-portal/audit-log', 160),
  ('compliance', 'Compliance', 'Compliance queue', 'admin', '/err-portal/compliance', 170),
  ('raise_ticket', 'Raise a ticket', 'Raise a ticket', 'admin', '/err-portal/raise-a-ticket', 180),
  ('ticket_dashboard', 'Ticket dashboard', 'Ticket dashboard', 'admin', '/err-portal/ticket-dashboard', 190),
  ('surveys', 'Surveys', 'Surveys', 'admin', '/err-portal/surveys', 200)
on conflict do nothing;

insert into public.workflow_templates (code, name, description, mount_codes) values
  ('full_portal', 'Full portal (all modules)', 'Complete grant + F1–F5 + reporting + admin mounts',
    array['f1_workplans','ticket_dashboard','grant_decisions','f4_f5_reporting','access_inbox','report_tracker','compliance','grant_allocation','user_management','learnings','environment_home','project_management','grant_grants','surveys','raise_ticket','f2_approvals','data_archive','state_management','room_management','dashboard','f3_mous','audit_log']),
  ('grants_reporting_only', 'Grants + reporting only', 'Lighter pack: grants, F4/F5, report tracker, project management',
    array['environment_home','grant_grants','f4_f5_reporting','report_tracker','project_management'])
on conflict do nothing;

insert into public.environments (id, organization_id, slug, display_name, header_title) values
  ('dd227344-b444-4b8d-9c25-cb853613f4b1', '8425b7c2-70ad-4054-890b-84d669de4f4f', 'localization_hub', 'Localization Hub', 'Localization Hub'),
  ('5e60c378-8e61-4ba1-8bb5-ca5ea674ea8b', 'bbb2a578-642b-4064-bfe9-f6fcddcaa946', 'lcc', 'LCC', 'LCC'),
  ('d42c047b-7d55-46b5-8ced-0dcf3bb22372', 'c50f542b-8b99-4275-9fbf-657bb4d0fcb3', 'demo_empty', 'Demo Empty Org', 'Demo Empty Org')
on conflict do nothing;

insert into public.environment_mounts (environment_id, mount_code, sort_order)
select e.id, m.mount_code, m.sort_order
from (values
  ('localization_hub', 'environment_home', 0), ('localization_hub', 'access_inbox', 5),
  ('localization_hub', 'grant_decisions', 10), ('localization_hub', 'grant_grants', 20),
  ('localization_hub', 'grant_allocation', 30), ('localization_hub', 'f1_workplans', 40),
  ('localization_hub', 'f2_approvals', 50), ('localization_hub', 'f3_mous', 60),
  ('localization_hub', 'f4_f5_reporting', 70), ('localization_hub', 'report_tracker', 80),
  ('localization_hub', 'project_management', 90), ('localization_hub', 'dashboard', 100),
  ('localization_hub', 'learnings', 110), ('localization_hub', 'data_archive', 120),
  ('localization_hub', 'room_management', 130), ('localization_hub', 'state_management', 140),
  ('localization_hub', 'user_management', 150), ('localization_hub', 'audit_log', 160),
  ('localization_hub', 'compliance', 170), ('localization_hub', 'raise_ticket', 180),
  ('localization_hub', 'ticket_dashboard', 190), ('localization_hub', 'surveys', 200),
  ('lcc', 'environment_home', 0), ('lcc', 'grant_decisions', 10),
  ('lcc', 'grant_grants', 20), ('lcc', 'report_tracker', 80),
  ('lcc', 'oversight', 85), ('lcc', 'project_management', 90),
  ('lcc', 'user_management', 150), ('lcc', 'audit_log', 160),
  ('demo_empty', 'f1_workplans', 0), ('demo_empty', 'ticket_dashboard', 10),
  ('demo_empty', 'grant_decisions', 20), ('demo_empty', 'f4_f5_reporting', 30),
  ('demo_empty', 'access_inbox', 40), ('demo_empty', 'report_tracker', 50),
  ('demo_empty', 'compliance', 60), ('demo_empty', 'grant_allocation', 70),
  ('demo_empty', 'user_management', 80), ('demo_empty', 'learnings', 90),
  ('demo_empty', 'environment_home', 100), ('demo_empty', 'project_management', 110),
  ('demo_empty', 'grant_grants', 120), ('demo_empty', 'surveys', 130),
  ('demo_empty', 'raise_ticket', 140), ('demo_empty', 'f2_approvals', 150),
  ('demo_empty', 'data_archive', 160), ('demo_empty', 'state_management', 170),
  ('demo_empty', 'room_management', 180), ('demo_empty', 'dashboard', 190),
  ('demo_empty', 'f3_mous', 200), ('demo_empty', 'audit_log', 210)
) as m(env_slug, mount_code, sort_order)
join public.environments e on e.slug = m.env_slug
on conflict (environment_id, mount_code) do nothing;

insert into public.disclosure_policies (organization_id, resource_type, advertise_existence, disclose_content)
select o.id, r.resource_type, true, false
from public.organizations o
cross join (values ('err_project'), ('f1'), ('decisions'), ('fund_requests'), ('mous'), ('f4'), ('f5')) as r(resource_type)
where o.slug in ('localization_hub', 'demo_empty')
on conflict (organization_id, resource_type) do nothing;

-- ---------------------------------------------------------------------------
-- Ownership backfill: existing records and users belong to the default owner
-- (Localization Hub). Production is already fully backfilled, so this only
-- touches dev.
-- ---------------------------------------------------------------------------

update public.err_projects set organization_id = '8425b7c2-70ad-4054-890b-84d669de4f4f' where organization_id is null;
update public.mous set organization_id = '8425b7c2-70ad-4054-890b-84d669de4f4f' where organization_id is null;
update public.fsps set organization_id = '8425b7c2-70ad-4054-890b-84d669de4f4f' where organization_id is null;
update public.fund_requests set organization_id = '8425b7c2-70ad-4054-890b-84d669de4f4f' where organization_id is null;
update public.err_summary set organization_id = '8425b7c2-70ad-4054-890b-84d669de4f4f' where organization_id is null;
update public.err_program_report set organization_id = '8425b7c2-70ad-4054-890b-84d669de4f4f' where organization_id is null;
update public.grants_grid_view set organization_id = '8425b7c2-70ad-4054-890b-84d669de4f4f' where organization_id is null;
update public.distribution_decision_master_sheet_1 set organization_id = '8425b7c2-70ad-4054-890b-84d669de4f4f' where organization_id is null;

insert into public.organization_memberships (user_id, organization_id, environment_id, is_default)
select u.id, '8425b7c2-70ad-4054-890b-84d669de4f4f', 'dd227344-b444-4b8d-9c25-cb853613f4b1', true
from public.users u
where not exists (select 1 from public.organization_memberships m where m.user_id = u.id);

commit;
