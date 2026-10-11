-- NEXO: INSTALACIÓN INICIAL EN SUPABASE
-- Ejecutar TODO el archivo una sola vez en SQL Editor como postgres.
-- Requiere un proyecto Supabase nuevo con Auth y Storage disponibles.
-- Supabase ya proporciona la base de datos; este archivo crea el esquema de Nexo.
-- Si ya aplicaste la migración inicial, NO ejecutes este archivo otra vez.
-- Fuente: migrations/20260920000000_initial_schema.sql
-- Después: crear usuario en Authentication > Users y ejecutar 02_crear_administrador.sql.
-- Nexo: esquema inicial para gestión integral de proyectos.
-- PostgreSQL / Supabase. Todos los cambios futuros deben agregarse en nuevas migraciones.

begin;

create schema if not exists extensions;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create extension if not exists pgcrypto with schema extensions;

-- -----------------------------------------------------------------------------
-- Catálogos ampliables
-- -----------------------------------------------------------------------------

create table public.project_statuses (
  code text primary key,
  name text not null,
  display_order integer not null default 0,
  is_terminal boolean not null default false,
  color text,
  created_at timestamptz not null default now()
);

create table public.task_statuses (
  code text primary key,
  name text not null,
  display_order integer not null default 0,
  is_terminal boolean not null default false,
  color text,
  created_at timestamptz not null default now()
);

create table public.task_priorities (
  code text primary key,
  name text not null,
  weight integer not null default 0,
  color text,
  created_at timestamptz not null default now()
);

create table public.material_request_statuses (
  code text primary key,
  name text not null,
  display_order integer not null default 0,
  is_terminal boolean not null default false,
  color text,
  created_at timestamptz not null default now()
);

create table public.material_request_status_transitions (
  from_status text not null references public.material_request_statuses(code) on update cascade,
  to_status text not null references public.material_request_statuses(code) on update cascade,
  requires_comment boolean not null default false,
  primary key (from_status, to_status),
  check (from_status <> to_status)
);

create table public.stock_movement_types (
  code text primary key,
  name text not null,
  on_hand_direction smallint not null default 0 check (on_hand_direction in (-1, 0, 1)),
  reserved_direction smallint not null default 0 check (reserved_direction in (-1, 0, 1)),
  requires_reference boolean not null default false,
  created_at timestamptz not null default now(),
  check (on_hand_direction <> 0 or reserved_direction <> 0)
);

create table public.approval_statuses (
  code text primary key,
  name text not null,
  is_terminal boolean not null default false,
  color text,
  created_at timestamptz not null default now()
);

insert into public.project_statuses (code, name, display_order, is_terminal, color) values
  ('draft', 'Borrador', 10, false, 'slate'),
  ('planning', 'Planificación', 20, false, 'blue'),
  ('active', 'Activo', 30, false, 'indigo'),
  ('on_hold', 'Pausado', 40, false, 'amber'),
  ('completed', 'Finalizado', 50, true, 'green'),
  ('cancelled', 'Cancelado', 60, true, 'red');

insert into public.task_statuses (code, name, display_order, is_terminal, color) values
  ('pending', 'Pendiente', 10, false, 'slate'),
  ('in_progress', 'En progreso', 20, false, 'blue'),
  ('in_review', 'En revisión', 30, false, 'violet'),
  ('blocked', 'Bloqueada', 40, false, 'red'),
  ('completed', 'Completada', 50, true, 'green'),
  ('cancelled', 'Cancelada', 60, true, 'gray');

insert into public.task_priorities (code, name, weight, color) values
  ('low', 'Baja', 10, 'slate'),
  ('medium', 'Media', 20, 'blue'),
  ('high', 'Alta', 30, 'amber'),
  ('critical', 'Crítica', 40, 'red');

insert into public.material_request_statuses (code, name, display_order, is_terminal, color) values
  ('draft', 'Borrador', 10, false, 'slate'),
  ('pending', 'Pendiente', 20, false, 'amber'),
  ('needs_changes', 'Requiere corrección', 30, false, 'orange'),
  ('approved', 'Aprobada', 40, false, 'violet'),
  ('reserved', 'Reservada', 50, false, 'blue'),
  ('partially_delivered', 'Entrega parcial', 60, false, 'cyan'),
  ('delivered', 'Entregada', 70, false, 'indigo'),
  ('usage_reported', 'Uso reportado', 80, false, 'teal'),
  ('returned', 'Devuelta', 90, false, 'teal'),
  ('closed', 'Cerrada', 100, true, 'green'),
  ('rejected', 'Rechazada', 110, true, 'red'),
  ('cancelled', 'Cancelada', 120, true, 'gray');

insert into public.material_request_status_transitions (from_status, to_status, requires_comment) values
  ('draft', 'pending', false), ('draft', 'cancelled', true),
  ('pending', 'approved', false), ('pending', 'rejected', true), ('pending', 'needs_changes', true), ('pending', 'cancelled', true),
  ('needs_changes', 'pending', false), ('needs_changes', 'cancelled', true),
  ('approved', 'reserved', false), ('approved', 'cancelled', true),
  ('reserved', 'partially_delivered', false), ('reserved', 'delivered', false), ('reserved', 'cancelled', true),
  ('partially_delivered', 'delivered', false), ('partially_delivered', 'cancelled', true),
  ('delivered', 'usage_reported', false), ('delivered', 'returned', false),
  ('usage_reported', 'closed', false), ('returned', 'closed', false);

insert into public.stock_movement_types (code, name, on_hand_direction, reserved_direction, requires_reference) values
  ('initial', 'Existencia inicial', 1, 0, false),
  ('purchase', 'Compra', 1, 0, true),
  ('donation', 'Donación', 1, 0, true),
  ('positive_adjustment', 'Ajuste positivo', 1, 0, true),
  ('reservation', 'Reserva', 0, 1, true),
  ('reservation_release', 'Liberación de reserva', 0, -1, true),
  ('delivery', 'Entrega', -1, -1, true),
  ('return', 'Devolución', 1, 0, true),
  ('negative_adjustment', 'Ajuste negativo', -1, 0, true),
  ('transfer_in', 'Traslado recibido', 1, 0, true),
  ('transfer_out', 'Traslado enviado', -1, 0, true);

insert into public.approval_statuses (code, name, is_terminal, color) values
  ('pending', 'Pendiente', false, 'amber'),
  ('approved', 'Aprobada', true, 'green'),
  ('rejected', 'Rechazada', true, 'red'),
  ('needs_changes', 'Requiere corrección', false, 'orange'),
  ('cancelled', 'Cancelada', true, 'gray');

-- -----------------------------------------------------------------------------
-- Identidad, organizaciones y autorización
-- -----------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text,
  last_name text,
  display_name text,
  phone text,
  avatar_path text,
  locale text not null default 'es-PE',
  timezone text not null default 'America/Lima',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (coalesce(nullif(trim(display_name), ''), nullif(trim(first_name), ''), nullif(trim(last_name), '')) is not null)
);

create table public.organizations (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null,
  slug text not null,
  legal_name text,
  tax_id text,
  logo_path text,
  timezone text not null default 'America/Lima',
  currency_code char(3) not null default 'PEN',
  settings jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (slug = lower(slug)),
  check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);
create unique index organizations_slug_uq on public.organizations (lower(slug)) where deleted_at is null;

create table public.organization_members (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  employee_code text,
  job_title text,
  status text not null default 'active' check (status in ('invited', 'active', 'suspended', 'inactive')),
  invited_by uuid references public.profiles(id) on delete set null,
  invited_at timestamptz,
  joined_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, user_id)
);
create unique index organization_members_employee_code_uq on public.organization_members (organization_id, employee_code) where employee_code is not null;

create table public.areas (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  parent_area_id uuid references public.areas(id) on delete set null,
  code text not null,
  name text not null,
  description text,
  manager_member_id uuid references public.organization_members(id) on delete set null,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (organization_id, code)
);

create table public.permissions (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique,
  module text not null,
  name text not null,
  description text,
  created_at timestamptz not null default now(),
  check (code ~ '^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$')
);

create table public.roles (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  is_system boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  granted_at timestamptz not null default now(),
  granted_by uuid references public.profiles(id) on delete set null,
  primary key (role_id, permission_id)
);

-- La misma persona puede tener roles distintos por organización, área o proyecto.
create table public.member_role_assignments (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  member_id uuid not null references public.organization_members(id) on delete cascade,
  role_id uuid not null references public.roles(id) on delete cascade,
  scope_type text not null check (scope_type in ('organization', 'area', 'project')),
  area_id uuid references public.areas(id) on delete cascade,
  project_id uuid,
  valid_from timestamptz not null default now(),
  valid_until timestamptz,
  assigned_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  check (valid_until is null or valid_until > valid_from),
  check (
    (scope_type = 'organization' and area_id is null and project_id is null) or
    (scope_type = 'area' and area_id is not null and project_id is null) or
    (scope_type = 'project' and area_id is null and project_id is not null)
  )
);

insert into public.permissions (code, module, name, description) values
  ('organization.view', 'organization', 'Ver organización', 'Consulta la organización y su configuración pública'),
  ('organization.manage', 'organization', 'Administrar organización', 'Edita datos y configuración general'),
  ('user.invite', 'users', 'Invitar usuarios', 'Invita personas a la organización'),
  ('user.manage', 'users', 'Administrar usuarios', 'Activa, suspende y actualiza miembros'),
  ('access.manage', 'access', 'Administrar accesos', 'Gestiona roles, permisos y alcances'),
  ('area.view', 'areas', 'Ver áreas', 'Consulta áreas habilitadas'),
  ('area.manage', 'areas', 'Administrar áreas', 'Crea y edita áreas'),
  ('project.view', 'projects', 'Ver proyectos', 'Consulta proyectos dentro del alcance'),
  ('project.create', 'projects', 'Crear proyectos', 'Crea proyectos'),
  ('project.manage', 'projects', 'Administrar proyectos', 'Edita proyectos, miembros e hitos'),
  ('task.view', 'tasks', 'Ver tareas', 'Consulta tareas de proyectos autorizados'),
  ('task.create', 'tasks', 'Crear tareas', 'Registra tareas'),
  ('task.manage', 'tasks', 'Administrar tareas', 'Asigna, edita y elimina tareas'),
  ('task.update_own', 'tasks', 'Actualizar tareas propias', 'Actualiza tareas asignadas al usuario'),
  ('material.view', 'materials', 'Ver materiales', 'Consulta catálogo y disponibilidad'),
  ('material.request', 'materials', 'Solicitar materiales', 'Crea solicitudes para proyectos autorizados'),
  ('material.manage_catalog', 'materials', 'Administrar catálogo', 'Crea y actualiza materiales y categorías'),
  ('material.manage_stock', 'materials', 'Administrar existencias', 'Registra movimientos, entregas y devoluciones'),
  ('material.approve', 'materials', 'Aprobar materiales', 'Decide solicitudes de materiales'),
  ('approval.view', 'approvals', 'Ver aprobaciones', 'Consulta aprobaciones dentro del alcance'),
  ('approval.decide', 'approvals', 'Decidir aprobaciones', 'Aprueba, rechaza o solicita correcciones'),
  ('approval.manage', 'approvals', 'Configurar aprobaciones', 'Gestiona flujos y pasos de aprobación'),
  ('document.view', 'documents', 'Ver documentos', 'Consulta documentos autorizados'),
  ('document.manage', 'documents', 'Administrar documentos', 'Carga, actualiza y archiva documentos'),
  ('diagram.view', 'diagrams', 'Ver diagramas', 'Consulta diagramas del proyecto'),
  ('diagram.manage', 'diagrams', 'Administrar diagramas', 'Crea y edita diagramas'),
  ('report.view', 'reports', 'Ver reportes', 'Consulta indicadores y reportes'),
  ('report.export', 'reports', 'Exportar reportes', 'Genera archivos PDF o CSV'),
  ('audit.view', 'audit', 'Ver auditoría', 'Consulta el historial de cambios');

-- -----------------------------------------------------------------------------
-- Proyectos, hitos y tareas
-- -----------------------------------------------------------------------------

create table public.projects (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  area_id uuid references public.areas(id) on delete set null,
  code text not null,
  name text not null,
  description text,
  objective text,
  status_code text not null default 'draft' references public.project_statuses(code) on update cascade,
  priority_code text references public.task_priorities(code) on update cascade,
  manager_member_id uuid references public.organization_members(id) on delete set null,
  sponsor_member_id uuid references public.organization_members(id) on delete set null,
  planned_start_date date,
  planned_end_date date,
  actual_start_date date,
  actual_end_date date,
  budget numeric(18,2) check (budget is null or budget >= 0),
  currency_code char(3) not null default 'PEN',
  progress_mode text not null default 'tasks' check (progress_mode in ('manual', 'tasks', 'milestones')),
  manual_progress numeric(5,2) not null default 0 check (manual_progress between 0 and 100),
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (organization_id, code),
  check (planned_end_date is null or planned_start_date is null or planned_end_date >= planned_start_date),
  check (actual_end_date is null or actual_start_date is null or actual_end_date >= actual_start_date)
);

alter table public.member_role_assignments
  add constraint member_role_assignments_project_fk foreign key (project_id) references public.projects(id) on delete cascade;

create table public.project_members (
  id uuid primary key default extensions.gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  member_id uuid not null references public.organization_members(id) on delete cascade,
  project_title text,
  is_project_manager boolean not null default false,
  allocation_percent numeric(5,2) check (allocation_percent is null or allocation_percent between 0 and 100),
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  unique (project_id, member_id),
  check (left_at is null or left_at >= joined_at)
);

create table public.project_milestones (
  id uuid primary key default extensions.gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  name text not null,
  description text,
  status_code text not null default 'pending' references public.task_statuses(code) on update cascade,
  planned_date date,
  completed_at timestamptz,
  weight numeric(7,4) not null default 1 check (weight > 0),
  display_order integer not null default 0,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.tasks (
  id uuid primary key default extensions.gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  area_id uuid references public.areas(id) on delete set null,
  milestone_id uuid references public.project_milestones(id) on delete set null,
  parent_task_id uuid references public.tasks(id) on delete set null,
  code text,
  title text not null,
  description text,
  acceptance_criteria text,
  status_code text not null default 'pending' references public.task_statuses(code) on update cascade,
  priority_code text not null default 'medium' references public.task_priorities(code) on update cascade,
  planned_start_at timestamptz,
  due_at timestamptz,
  actual_start_at timestamptz,
  completed_at timestamptz,
  estimated_hours numeric(10,2) check (estimated_hours is null or estimated_hours >= 0),
  progress numeric(5,2) not null default 0 check (progress between 0 and 100),
  display_order integer not null default 0,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (due_at is null or planned_start_at is null or due_at >= planned_start_at)
);
create unique index tasks_project_code_uq on public.tasks(project_id, code) where code is not null and deleted_at is null;

create table public.task_assignees (
  task_id uuid not null references public.tasks(id) on delete cascade,
  member_id uuid not null references public.organization_members(id) on delete cascade,
  assignment_type text not null default 'responsible' check (assignment_type in ('responsible', 'collaborator', 'reviewer', 'observer')),
  assigned_by uuid references public.profiles(id) on delete set null,
  assigned_at timestamptz not null default now(),
  primary key (task_id, member_id, assignment_type)
);

create table public.task_dependencies (
  predecessor_task_id uuid not null references public.tasks(id) on delete cascade,
  successor_task_id uuid not null references public.tasks(id) on delete cascade,
  dependency_type text not null default 'finish_to_start' check (dependency_type in ('finish_to_start', 'start_to_start', 'finish_to_finish', 'start_to_finish')),
  lag_minutes integer not null default 0,
  created_at timestamptz not null default now(),
  primary key (predecessor_task_id, successor_task_id),
  check (predecessor_task_id <> successor_task_id)
);

create table public.task_comments (
  id uuid primary key default extensions.gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete restrict,
  parent_comment_id uuid references public.task_comments(id) on delete cascade,
  body text not null,
  is_edited boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.task_progress_entries (
  id uuid primary key default extensions.gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  reported_by uuid not null references public.profiles(id) on delete restrict,
  progress numeric(5,2) not null check (progress between 0 and 100),
  hours_spent numeric(10,2) check (hours_spent is null or hours_spent >= 0),
  note text,
  reported_at timestamptz not null default now()
);

create table public.project_status_history (
  id uuid primary key default extensions.gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  from_status text references public.project_statuses(code),
  to_status text not null references public.project_statuses(code),
  changed_by uuid references public.profiles(id) on delete set null,
  comment text,
  changed_at timestamptz not null default now()
);

create table public.task_status_history (
  id uuid primary key default extensions.gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  from_status text references public.task_statuses(code),
  to_status text not null references public.task_statuses(code),
  changed_by uuid references public.profiles(id) on delete set null,
  comment text,
  changed_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- Documentos, archivos y diagramas
-- -----------------------------------------------------------------------------

create table public.files (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  bucket_id text not null default 'project-files',
  object_path text not null,
  original_name text not null,
  mime_type text,
  size_bytes bigint check (size_bytes is null or size_bytes >= 0),
  checksum_sha256 text,
  uploaded_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (bucket_id, object_path)
);

create table public.documents (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  project_id uuid references public.projects(id) on delete cascade,
  task_id uuid references public.tasks(id) on delete cascade,
  file_id uuid not null references public.files(id) on delete restrict,
  document_type text not null default 'other',
  title text not null,
  description text,
  version integer not null default 1 check (version > 0),
  previous_document_id uuid references public.documents(id) on delete set null,
  is_current boolean not null default true,
  visibility text not null default 'project' check (visibility in ('organization', 'area', 'project', 'private')),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (project_id is not null or task_id is not null)
);

create table public.activity_diagrams (
  id uuid primary key default extensions.gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  name text not null,
  description text,
  format text not null default 'mermaid' check (format in ('mermaid', 'bpmn', 'json')),
  source text not null,
  version integer not null default 1 check (version > 0),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- -----------------------------------------------------------------------------
-- Inventario, solicitudes, entregas, uso y devoluciones
-- -----------------------------------------------------------------------------

create table public.material_categories (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  parent_category_id uuid references public.material_categories(id) on delete set null,
  code text not null,
  name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table public.warehouses (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  code text not null,
  name text not null,
  location text,
  manager_member_id uuid references public.organization_members(id) on delete set null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table public.materials (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  category_id uuid references public.material_categories(id) on delete set null,
  sku text not null,
  name text not null,
  description text,
  unit_of_measure text not null,
  material_kind text not null default 'consumable' check (material_kind in ('consumable', 'returnable', 'service', 'license')),
  minimum_stock numeric(18,4) not null default 0 check (minimum_stock >= 0),
  standard_cost numeric(18,4) check (standard_cost is null or standard_cost >= 0),
  currency_code char(3) not null default 'PEN',
  requires_usage_report boolean not null default true,
  requires_return boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (organization_id, sku),
  check (not requires_return or material_kind = 'returnable')
);

create table public.material_stock (
  material_id uuid not null references public.materials(id) on delete cascade,
  warehouse_id uuid not null references public.warehouses(id) on delete cascade,
  on_hand numeric(18,4) not null default 0 check (on_hand >= 0),
  reserved numeric(18,4) not null default 0 check (reserved >= 0 and reserved <= on_hand),
  updated_at timestamptz not null default now(),
  primary key (material_id, warehouse_id)
);

create table public.material_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  request_number text not null,
  project_id uuid not null references public.projects(id) on delete restrict,
  task_id uuid references public.tasks(id) on delete set null,
  requested_by_member_id uuid not null references public.organization_members(id) on delete restrict,
  status_code text not null default 'draft' references public.material_request_statuses(code) on update cascade,
  priority_code text not null default 'medium' references public.task_priorities(code) on update cascade,
  needed_at timestamptz,
  justification text not null,
  estimated_total numeric(18,2) not null default 0 check (estimated_total >= 0),
  currency_code char(3) not null default 'PEN',
  submitted_at timestamptz,
  closed_at timestamptz,
  cancelled_at timestamptz,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (organization_id, request_number)
);

create table public.material_request_items (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null references public.material_requests(id) on delete cascade,
  material_id uuid not null references public.materials(id) on delete restrict,
  preferred_warehouse_id uuid references public.warehouses(id) on delete set null,
  quantity_requested numeric(18,4) not null check (quantity_requested > 0),
  quantity_approved numeric(18,4) check (quantity_approved is null or quantity_approved between 0 and quantity_requested),
  quantity_reserved numeric(18,4) not null default 0 check (quantity_reserved >= 0),
  quantity_delivered numeric(18,4) not null default 0 check (quantity_delivered >= 0),
  unit_cost numeric(18,4) check (unit_cost is null or unit_cost >= 0),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (request_id, material_id, preferred_warehouse_id)
);

create table public.material_request_status_history (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null references public.material_requests(id) on delete cascade,
  from_status text references public.material_request_statuses(code),
  to_status text not null references public.material_request_statuses(code),
  changed_by uuid references public.profiles(id) on delete set null,
  comment text,
  changed_at timestamptz not null default now()
);

create table public.material_deliveries (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  request_id uuid not null references public.material_requests(id) on delete restrict,
  warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  delivered_by_member_id uuid not null references public.organization_members(id) on delete restrict,
  received_by_member_id uuid not null references public.organization_members(id) on delete restrict,
  delivery_number text not null,
  delivered_at timestamptz not null default now(),
  notes text,
  evidence_file_id uuid references public.files(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (organization_id, delivery_number)
);

create table public.material_delivery_items (
  id uuid primary key default extensions.gen_random_uuid(),
  delivery_id uuid not null references public.material_deliveries(id) on delete cascade,
  request_item_id uuid not null references public.material_request_items(id) on delete restrict,
  material_id uuid not null references public.materials(id) on delete restrict,
  quantity numeric(18,4) not null check (quantity > 0),
  condition_notes text,
  unique (delivery_id, request_item_id)
);

create table public.material_usage_reports (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  request_id uuid not null references public.material_requests(id) on delete restrict,
  reported_by_member_id uuid not null references public.organization_members(id) on delete restrict,
  summary text not null,
  reported_at timestamptz not null default now(),
  evidence_file_id uuid references public.files(id) on delete set null,
  approved_by_member_id uuid references public.organization_members(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.material_usage_report_items (
  id uuid primary key default extensions.gen_random_uuid(),
  usage_report_id uuid not null references public.material_usage_reports(id) on delete cascade,
  request_item_id uuid not null references public.material_request_items(id) on delete restrict,
  quantity_used numeric(18,4) not null default 0 check (quantity_used >= 0),
  quantity_remaining numeric(18,4) not null default 0 check (quantity_remaining >= 0),
  notes text,
  unique (usage_report_id, request_item_id)
);

create table public.material_returns (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  request_id uuid not null references public.material_requests(id) on delete restrict,
  warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  returned_by_member_id uuid not null references public.organization_members(id) on delete restrict,
  received_by_member_id uuid not null references public.organization_members(id) on delete restrict,
  returned_at timestamptz not null default now(),
  notes text,
  evidence_file_id uuid references public.files(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.material_return_items (
  id uuid primary key default extensions.gen_random_uuid(),
  return_id uuid not null references public.material_returns(id) on delete cascade,
  request_item_id uuid not null references public.material_request_items(id) on delete restrict,
  material_id uuid not null references public.materials(id) on delete restrict,
  quantity numeric(18,4) not null check (quantity > 0),
  condition text not null default 'good' check (condition in ('good', 'damaged', 'lost', 'maintenance_required')),
  notes text,
  unique (return_id, request_item_id)
);

create table public.stock_movements (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  material_id uuid not null references public.materials(id) on delete restrict,
  warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  movement_type_code text not null references public.stock_movement_types(code) on update cascade,
  quantity numeric(18,4) not null check (quantity > 0),
  quantity_delta numeric(18,4) not null,
  balance_after numeric(18,4) not null check (balance_after >= 0),
  reserved_delta numeric(18,4) not null default 0,
  reserved_balance_after numeric(18,4) not null default 0 check (reserved_balance_after >= 0),
  reference_type text,
  reference_id uuid,
  project_id uuid references public.projects(id) on delete set null,
  request_id uuid references public.material_requests(id) on delete set null,
  reason text,
  occurred_at timestamptz not null default now(),
  recorded_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  check (quantity_delta <> 0 or reserved_delta <> 0)
);

-- -----------------------------------------------------------------------------
-- Flujos de aprobación reutilizables
-- -----------------------------------------------------------------------------

create table public.approval_flows (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  code text not null,
  name text not null,
  subject_type text not null,
  description text,
  is_active boolean not null default true,
  conditions jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table public.approval_flow_steps (
  id uuid primary key default extensions.gen_random_uuid(),
  flow_id uuid not null references public.approval_flows(id) on delete cascade,
  step_order integer not null check (step_order > 0),
  name text not null,
  approver_type text not null check (approver_type in ('role', 'member', 'project_manager', 'area_manager', 'requester_manager')),
  role_id uuid references public.roles(id) on delete set null,
  member_id uuid references public.organization_members(id) on delete set null,
  minimum_approvals integer not null default 1 check (minimum_approvals > 0),
  allow_self_approval boolean not null default false,
  conditions jsonb not null default '{}'::jsonb,
  unique (flow_id, step_order)
);

create table public.approval_instances (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  flow_id uuid not null references public.approval_flows(id) on delete restrict,
  subject_type text not null,
  subject_id uuid not null,
  project_id uuid references public.projects(id) on delete cascade,
  requested_by_member_id uuid not null references public.organization_members(id) on delete restrict,
  status_code text not null default 'pending' references public.approval_statuses(code) on update cascade,
  current_step_order integer not null default 1,
  submitted_at timestamptz not null default now(),
  completed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.approval_instance_steps (
  id uuid primary key default extensions.gen_random_uuid(),
  approval_instance_id uuid not null references public.approval_instances(id) on delete cascade,
  flow_step_id uuid not null references public.approval_flow_steps(id) on delete restrict,
  step_order integer not null,
  assigned_role_id uuid references public.roles(id) on delete set null,
  assigned_member_id uuid references public.organization_members(id) on delete set null,
  status_code text not null default 'pending' references public.approval_statuses(code) on update cascade,
  decided_by_member_id uuid references public.organization_members(id) on delete set null,
  decision_comment text,
  due_at timestamptz,
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  unique (approval_instance_id, flow_step_id)
);

-- -----------------------------------------------------------------------------
-- Notificaciones, correo y auditoría
-- -----------------------------------------------------------------------------

create table public.notifications (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  recipient_user_id uuid not null references public.profiles(id) on delete cascade,
  notification_type text not null,
  title text not null,
  body text,
  action_url text,
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.email_outbox (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  template_key text not null,
  recipient_email text not null,
  recipient_user_id uuid references public.profiles(id) on delete set null,
  subject text not null,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending', 'processing', 'sent', 'failed', 'cancelled')),
  attempts integer not null default 0 check (attempts >= 0),
  provider_message_id text,
  last_error text,
  scheduled_at timestamptz not null default now(),
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  organization_id uuid references public.organizations(id) on delete set null,
  actor_user_id uuid references public.profiles(id) on delete set null,
  action text not null,
  table_name text not null,
  record_id text,
  project_id uuid references public.projects(id) on delete set null,
  old_data jsonb,
  new_data jsonb,
  request_id text,
  ip_address inet,
  user_agent text,
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- Índices
-- -----------------------------------------------------------------------------

create index organization_members_user_idx on public.organization_members(user_id, organization_id) where status = 'active';
create index areas_organization_idx on public.areas(organization_id) where deleted_at is null;
create index roles_organization_idx on public.roles(organization_id) where is_active;
create index role_permissions_permission_idx on public.role_permissions(permission_id, role_id);
create index role_assignments_member_idx on public.member_role_assignments(member_id, organization_id);
create index role_assignments_project_idx on public.member_role_assignments(project_id) where project_id is not null;
create index role_assignments_area_idx on public.member_role_assignments(area_id) where area_id is not null;
create index projects_organization_status_idx on public.projects(organization_id, status_code) where deleted_at is null;
create index projects_area_idx on public.projects(area_id) where deleted_at is null;
create index project_members_member_idx on public.project_members(member_id, project_id) where left_at is null;
create index milestones_project_idx on public.project_milestones(project_id, display_order);
create index tasks_project_status_idx on public.tasks(project_id, status_code, due_at) where deleted_at is null;
create index tasks_parent_idx on public.tasks(parent_task_id) where parent_task_id is not null;
create index tasks_due_idx on public.tasks(due_at) where deleted_at is null and status_code not in ('completed', 'cancelled');
create index task_assignees_member_idx on public.task_assignees(member_id, task_id);
create index task_comments_task_idx on public.task_comments(task_id, created_at) where deleted_at is null;
create index task_progress_task_idx on public.task_progress_entries(task_id, reported_at desc);
create index files_organization_idx on public.files(organization_id) where deleted_at is null;
create index documents_project_idx on public.documents(project_id, created_at desc) where deleted_at is null;
create index documents_task_idx on public.documents(task_id) where task_id is not null and deleted_at is null;
create index diagrams_project_idx on public.activity_diagrams(project_id) where deleted_at is null;
create index materials_organization_category_idx on public.materials(organization_id, category_id) where deleted_at is null;
create index material_stock_warehouse_idx on public.material_stock(warehouse_id, material_id);
create index material_requests_project_status_idx on public.material_requests(project_id, status_code, created_at desc) where deleted_at is null;
create index material_requests_requester_idx on public.material_requests(requested_by_member_id, created_at desc) where deleted_at is null;
create index material_request_items_material_idx on public.material_request_items(material_id, request_id);
create index stock_movements_material_time_idx on public.stock_movements(material_id, warehouse_id, occurred_at desc);
create index stock_movements_request_idx on public.stock_movements(request_id) where request_id is not null;
create index approval_instances_subject_idx on public.approval_instances(subject_type, subject_id);
create index approval_instances_project_status_idx on public.approval_instances(project_id, status_code) where project_id is not null;
create index approval_steps_assigned_member_idx on public.approval_instance_steps(assigned_member_id, status_code) where assigned_member_id is not null;
create index notifications_recipient_idx on public.notifications(recipient_user_id, read_at, created_at desc);
create index email_outbox_pending_idx on public.email_outbox(status, scheduled_at) where status in ('pending', 'failed');
create index audit_logs_organization_time_idx on public.audit_logs(organization_id, created_at desc);
create index audit_logs_record_idx on public.audit_logs(table_name, record_id, created_at desc);

-- -----------------------------------------------------------------------------
-- Funciones y triggers de integridad
-- -----------------------------------------------------------------------------

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_first text;
  v_last text;
  v_display text;
begin
  v_first := nullif(trim(new.raw_user_meta_data ->> 'first_name'), '');
  v_last := nullif(trim(new.raw_user_meta_data ->> 'last_name'), '');
  v_display := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
    nullif(trim(concat_ws(' ', v_first, v_last)), ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'Usuario'
  );

  insert into public.profiles (id, first_name, last_name, display_name)
  values (new.id, v_first, v_last, v_display)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

insert into public.profiles(id, first_name, last_name, display_name)
select
  u.id,
  nullif(trim(u.raw_user_meta_data ->> 'first_name'), ''),
  nullif(trim(u.raw_user_meta_data ->> 'last_name'), ''),
  coalesce(
    nullif(trim(u.raw_user_meta_data ->> 'display_name'), ''),
    nullif(trim(concat_ws(' ', u.raw_user_meta_data ->> 'first_name', u.raw_user_meta_data ->> 'last_name')), ''),
    nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
    'Usuario'
  )
from auth.users u
on conflict (id) do nothing;

create or replace function private.validate_role_assignment()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_member_org uuid;
  v_role_org uuid;
  v_scope_org uuid;
begin
  select organization_id into v_member_org from public.organization_members where id = new.member_id;
  select organization_id into v_role_org from public.roles where id = new.role_id;
  if v_member_org is distinct from new.organization_id or v_role_org is distinct from new.organization_id then
    raise exception 'El miembro, el rol y la asignación deben pertenecer a la misma organización';
  end if;

  if new.scope_type = 'area' then
    select organization_id into v_scope_org from public.areas where id = new.area_id;
  elsif new.scope_type = 'project' then
    select organization_id into v_scope_org from public.projects where id = new.project_id;
  else
    v_scope_org := new.organization_id;
  end if;

  if v_scope_org is distinct from new.organization_id then
    raise exception 'El alcance debe pertenecer a la organización de la asignación';
  end if;
  return new;
end;
$$;

create trigger validate_role_assignment_before_write
  before insert or update on public.member_role_assignments
  for each row execute function private.validate_role_assignment();

create or replace function private.capture_project_status_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status_code is distinct from old.status_code then
    insert into public.project_status_history(project_id, from_status, to_status, changed_by)
    values (new.id, old.status_code, new.status_code, auth.uid());
  end if;
  return new;
end;
$$;

create trigger capture_project_status_after_update
  after update of status_code on public.projects
  for each row execute function private.capture_project_status_change();

create or replace function private.capture_task_status_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status_code is distinct from old.status_code then
    insert into public.task_status_history(task_id, from_status, to_status, changed_by)
    values (new.id, old.status_code, new.status_code, auth.uid());
  end if;
  return new;
end;
$$;

create trigger capture_task_status_after_update
  after update of status_code on public.tasks
  for each row execute function private.capture_task_status_change();

create or replace function private.validate_material_request_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status_code is distinct from old.status_code and not exists (
    select 1
    from public.material_request_status_transitions t
    where t.from_status = old.status_code and t.to_status = new.status_code
  ) then
    raise exception 'Transición de solicitud no permitida: % -> %', old.status_code, new.status_code;
  end if;
  return new;
end;
$$;

create or replace function private.capture_material_request_status_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status_code is distinct from old.status_code then
    insert into public.material_request_status_history(request_id, from_status, to_status, changed_by)
    values (new.id, old.status_code, new.status_code, auth.uid());
  end if;
  return new;
end;
$$;

create trigger validate_material_request_transition_before_update
  before update of status_code on public.material_requests
  for each row execute function private.validate_material_request_transition();

create trigger capture_material_request_status_after_update
  after update of status_code on public.material_requests
  for each row execute function private.capture_material_request_status_change();

create or replace function private.apply_stock_movement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_on_hand_direction smallint;
  v_reserved_direction smallint;
  v_requires_reference boolean;
  v_on_hand numeric(18,4);
  v_reserved numeric(18,4);
  v_new_on_hand numeric(18,4);
  v_new_reserved numeric(18,4);
  v_material_org uuid;
  v_warehouse_org uuid;
begin
  select on_hand_direction, reserved_direction, requires_reference
  into v_on_hand_direction, v_reserved_direction, v_requires_reference
  from public.stock_movement_types
  where code = new.movement_type_code;

  if not found then raise exception 'Tipo de movimiento inválido'; end if;
  if v_requires_reference and new.reference_id is null and new.request_id is null then
    raise exception 'El movimiento % requiere una referencia', new.movement_type_code;
  end if;

  select organization_id into v_material_org from public.materials where id = new.material_id;
  select organization_id into v_warehouse_org from public.warehouses where id = new.warehouse_id;
  if v_material_org is distinct from new.organization_id or v_warehouse_org is distinct from new.organization_id then
    raise exception 'Material, almacén y movimiento deben pertenecer a la misma organización';
  end if;

  insert into public.material_stock(material_id, warehouse_id, on_hand, reserved)
  values (new.material_id, new.warehouse_id, 0, 0)
  on conflict (material_id, warehouse_id) do nothing;

  select on_hand, reserved into v_on_hand, v_reserved
  from public.material_stock
  where material_id = new.material_id and warehouse_id = new.warehouse_id
  for update;

  new.quantity_delta := new.quantity * v_on_hand_direction;
  new.reserved_delta := new.quantity * v_reserved_direction;
  v_new_on_hand := v_on_hand + new.quantity_delta;
  v_new_reserved := v_reserved + new.reserved_delta;

  if v_new_on_hand < 0 then raise exception 'Stock físico insuficiente'; end if;
  if v_new_reserved < 0 then raise exception 'La reserva no puede ser negativa'; end if;
  if v_new_reserved > v_new_on_hand then raise exception 'Stock disponible insuficiente para reservar'; end if;

  update public.material_stock
  set on_hand = v_new_on_hand, reserved = v_new_reserved, updated_at = now()
  where material_id = new.material_id and warehouse_id = new.warehouse_id;

  new.balance_after := v_new_on_hand;
  new.reserved_balance_after := v_new_reserved;
  return new;
end;
$$;

create trigger apply_stock_movement_before_insert
  before insert on public.stock_movements
  for each row execute function private.apply_stock_movement();

create or replace function private.prevent_stock_movement_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Los movimientos de inventario son inmutables; registre un movimiento compensatorio';
end;
$$;

create trigger prevent_stock_movement_update_delete
  before update or delete on public.stock_movements
  for each row execute function private.prevent_stock_movement_mutation();

create or replace function private.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old jsonb;
  v_new jsonb;
  v_org uuid;
  v_project uuid;
  v_record_id text;
begin
  if tg_op <> 'INSERT' then v_old := to_jsonb(old); end if;
  if tg_op <> 'DELETE' then v_new := to_jsonb(new); end if;
  v_org := coalesce(nullif(v_new ->> 'organization_id', '')::uuid, nullif(v_old ->> 'organization_id', '')::uuid);
  v_project := coalesce(nullif(v_new ->> 'project_id', '')::uuid, nullif(v_old ->> 'project_id', '')::uuid);
  v_record_id := coalesce(v_new ->> 'id', v_old ->> 'id');

  insert into public.audit_logs(organization_id, actor_user_id, action, table_name, record_id, project_id, old_data, new_data)
  values (v_org, auth.uid(), lower(tg_op), tg_table_name, v_record_id, v_project, v_old, v_new);
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles','organizations','organization_members','areas','roles','projects','project_milestones','tasks',
    'task_comments','documents','activity_diagrams','material_categories','warehouses','materials','material_requests',
    'material_request_items','approval_flows','email_outbox'
  ] loop
    execute format('create trigger set_%I_updated_at before update on public.%I for each row execute function private.set_updated_at()', t, t);
  end loop;
end $$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'organization_members','areas','roles','member_role_assignments','projects','project_members','tasks',
    'materials','material_requests','approval_flows','approval_instances','approval_instance_steps'
  ] loop
    execute format('create trigger audit_%I after insert or update or delete on public.%I for each row execute function private.audit_row_change()', t, t);
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- Funciones privadas usadas por RLS
-- -----------------------------------------------------------------------------

create or replace function private.is_org_member(p_organization_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null and exists (
    select 1 from public.organization_members m
    where m.organization_id = p_organization_id
      and m.user_id = p_user_id
      and m.status = 'active'
  );
$$;

create or replace function private.current_member_id(p_organization_id uuid, p_user_id uuid default auth.uid())
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.id from public.organization_members m
  where m.organization_id = p_organization_id
    and m.user_id = p_user_id
    and m.status = 'active'
  limit 1;
$$;

create or replace function private.shares_organization(p_other_user_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null and exists (
    select 1
    from public.organization_members me
    join public.organization_members other_member on other_member.organization_id = me.organization_id
    where me.user_id = p_user_id and me.status = 'active'
      and other_member.user_id = p_other_user_id and other_member.status = 'active'
  );
$$;

create or replace function private.has_permission(
  p_organization_id uuid,
  p_permission_code text,
  p_project_id uuid default null,
  p_area_id uuid default null,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null and exists (
    select 1
    from public.organization_members m
    join public.member_role_assignments a on a.member_id = m.id and a.organization_id = m.organization_id
    join public.roles r on r.id = a.role_id and r.organization_id = m.organization_id and r.is_active
    join public.role_permissions rp on rp.role_id = r.id
    join public.permissions p on p.id = rp.permission_id and p.code = p_permission_code
    left join public.projects scope_project on scope_project.id = p_project_id
    where m.organization_id = p_organization_id
      and m.user_id = p_user_id
      and m.status = 'active'
      and a.valid_from <= now()
      and (a.valid_until is null or a.valid_until > now())
      and (
        a.scope_type = 'organization'
        or (a.scope_type = 'area' and a.area_id = coalesce(p_area_id, scope_project.area_id))
        or (a.scope_type = 'project' and a.project_id = p_project_id)
      )
  );
$$;

create or replace function private.can_access_project(p_project_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null and exists (
    select 1
    from public.projects p
    join public.organization_members m on m.organization_id = p.organization_id
    where p.id = p_project_id
      and p.deleted_at is null
      and m.user_id = p_user_id
      and m.status = 'active'
      and (
        exists (select 1 from public.project_members pm where pm.project_id = p.id and pm.member_id = m.id and pm.left_at is null)
        or private.has_permission(p.organization_id, 'project.view', p.id, p.area_id, p_user_id)
      )
  );
$$;

create or replace function private.can_access_material_request(p_request_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null and exists (
    select 1
    from public.material_requests r
    join public.organization_members m on m.organization_id = r.organization_id and m.user_id = p_user_id and m.status = 'active'
    where r.id = p_request_id
      and r.deleted_at is null
      and (
        r.requested_by_member_id = m.id
        or private.has_permission(r.organization_id, 'material.view', r.project_id, null, p_user_id)
        or private.has_permission(r.organization_id, 'material.approve', r.project_id, null, p_user_id)
      )
  );
$$;

create or replace function private.bootstrap_organization(p_name text, p_slug text, p_owner_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org_id uuid;
  v_member_id uuid;
  v_role_id uuid;
  v_role record;
begin
  if p_owner_user_id is null or not exists (select 1 from public.profiles where id = p_owner_user_id) then
    raise exception 'El propietario debe existir en profiles';
  end if;

  insert into public.organizations(name, slug, created_by)
  values (trim(p_name), lower(trim(p_slug)), p_owner_user_id)
  returning id into v_org_id;

  insert into public.organization_members(organization_id, user_id, status, joined_at)
  values (v_org_id, p_owner_user_id, 'active', now()) returning id into v_member_id;

  for v_role in select * from (values
    ('admin', 'Administrador', 'Control completo de la organización'),
    ('project_manager', 'Jefe de proyecto', 'Gestión de sus proyectos'),
    ('area_manager', 'Jefe de área', 'Gestión dentro de su área'),
    ('approver', 'Aprobador', 'Decisión de solicitudes asignadas'),
    ('member', 'Miembro', 'Trabajo operativo en proyectos'),
    ('material_manager', 'Gestor de materiales', 'Catálogo, almacén y entregas'),
    ('auditor', 'Auditor', 'Consulta y auditoría sin edición')
  ) as x(code, name, description)
  loop
    insert into public.roles(organization_id, code, name, description, is_system)
    values (v_org_id, v_role.code, v_role.name, v_role.description, true);
  end loop;

  insert into public.role_permissions(role_id, permission_id, granted_by)
  select r.id, p.id, p_owner_user_id
  from public.roles r cross join public.permissions p
  where r.organization_id = v_org_id and r.code = 'admin';

  insert into public.role_permissions(role_id, permission_id, granted_by)
  select r.id, p.id, p_owner_user_id from public.roles r join public.permissions p on p.code = any(array[
    'organization.view','area.view','project.view','project.manage','task.view','task.create','task.manage',
    'material.view','material.request','approval.view','document.view','document.manage','diagram.view','diagram.manage',
    'report.view','report.export'
  ]) where r.organization_id = v_org_id and r.code = 'project_manager';

  insert into public.role_permissions(role_id, permission_id, granted_by)
  select r.id, p.id, p_owner_user_id from public.roles r join public.permissions p on p.code = any(array[
    'organization.view','area.view','project.view','task.view','task.create','task.manage','material.view','material.request',
    'approval.view','document.view','document.manage','diagram.view','diagram.manage','report.view'
  ]) where r.organization_id = v_org_id and r.code = 'area_manager';

  insert into public.role_permissions(role_id, permission_id, granted_by)
  select r.id, p.id, p_owner_user_id from public.roles r join public.permissions p on p.code = any(array[
    'organization.view','area.view','project.view','task.view','material.view','material.approve','approval.view','approval.decide','document.view','report.view'
  ]) where r.organization_id = v_org_id and r.code = 'approver';

  insert into public.role_permissions(role_id, permission_id, granted_by)
  select r.id, p.id, p_owner_user_id from public.roles r join public.permissions p on p.code = any(array[
    'organization.view','area.view','project.view','task.view','task.create','task.update_own','material.view','material.request',
    'document.view','document.manage','diagram.view'
  ]) where r.organization_id = v_org_id and r.code = 'member';

  insert into public.role_permissions(role_id, permission_id, granted_by)
  select r.id, p.id, p_owner_user_id from public.roles r join public.permissions p on p.code = any(array[
    'organization.view','area.view','project.view','material.view','material.request','material.manage_catalog','material.manage_stock',
    'approval.view','document.view','report.view'
  ]) where r.organization_id = v_org_id and r.code = 'material_manager';

  insert into public.role_permissions(role_id, permission_id, granted_by)
  select r.id, p.id, p_owner_user_id from public.roles r join public.permissions p on p.code = any(array[
    'organization.view','area.view','project.view','task.view','material.view','approval.view','document.view','diagram.view','report.view','report.export','audit.view'
  ]) where r.organization_id = v_org_id and r.code = 'auditor';

  select id into v_role_id from public.roles where organization_id = v_org_id and code = 'admin';
  insert into public.member_role_assignments(organization_id, member_id, role_id, scope_type, assigned_by)
  values (v_org_id, v_member_id, v_role_id, 'organization', p_owner_user_id);
  return v_org_id;
end;
$$;

grant usage on schema private to authenticated, service_role;
grant execute on function private.is_org_member(uuid, uuid) to authenticated, service_role;
grant execute on function private.current_member_id(uuid, uuid) to authenticated, service_role;
grant execute on function private.shares_organization(uuid, uuid) to authenticated, service_role;
grant execute on function private.has_permission(uuid, text, uuid, uuid, uuid) to authenticated, service_role;
grant execute on function private.can_access_project(uuid, uuid) to authenticated, service_role;
grant execute on function private.can_access_material_request(uuid, uuid) to authenticated, service_role;
revoke all on function private.bootstrap_organization(text, text, uuid) from public, anon, authenticated;
grant execute on function private.bootstrap_organization(text, text, uuid) to service_role;

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'project_statuses','task_statuses','task_priorities','material_request_statuses','material_request_status_transitions',
    'stock_movement_types','approval_statuses','profiles','organizations','organization_members','areas','permissions',
    'roles','role_permissions','member_role_assignments','projects','project_members','project_milestones','tasks',
    'task_assignees','task_dependencies','task_comments','task_progress_entries','project_status_history','task_status_history',
    'files','documents','activity_diagrams','material_categories','warehouses','materials','material_stock','material_requests',
    'material_request_items','material_request_status_history','material_deliveries','material_delivery_items',
    'material_usage_reports','material_usage_report_items','material_returns','material_return_items','stock_movements',
    'approval_flows','approval_flow_steps','approval_instances','approval_instance_steps','notifications','email_outbox','audit_logs'
  ] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- Catálogos globales de solo lectura.
do $$
declare
  t text;
begin
  foreach t in array array[
    'project_statuses','task_statuses','task_priorities','material_request_statuses','material_request_status_transitions',
    'stock_movement_types','approval_statuses','permissions'
  ] loop
    execute format('create policy %I on public.%I for select to authenticated using (true)', 'authenticated_read_' || t, t);
  end loop;
end $$;

create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or private.shares_organization(id));
create policy profiles_update_self on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy organizations_select on public.organizations for select to authenticated
  using (private.is_org_member(id) and deleted_at is null);
create policy organizations_update on public.organizations for update to authenticated
  using (private.has_permission(id, 'organization.manage'))
  with check (private.has_permission(id, 'organization.manage'));

create policy organization_members_select on public.organization_members for select to authenticated
  using (private.is_org_member(organization_id));
create policy organization_members_insert on public.organization_members for insert to authenticated
  with check (private.has_permission(organization_id, 'user.invite'));
create policy organization_members_update on public.organization_members for update to authenticated
  using (private.has_permission(organization_id, 'user.manage'))
  with check (private.has_permission(organization_id, 'user.manage'));

create policy areas_select on public.areas for select to authenticated
  using (private.is_org_member(organization_id) and deleted_at is null);
create policy areas_insert on public.areas for insert to authenticated
  with check (private.has_permission(organization_id, 'area.manage'));
create policy areas_update on public.areas for update to authenticated
  using (private.has_permission(organization_id, 'area.manage'))
  with check (private.has_permission(organization_id, 'area.manage'));

create policy roles_select on public.roles for select to authenticated
  using (private.is_org_member(organization_id));
create policy roles_manage on public.roles for all to authenticated
  using (private.has_permission(organization_id, 'access.manage'))
  with check (private.has_permission(organization_id, 'access.manage'));

create policy role_permissions_select on public.role_permissions for select to authenticated
  using (exists (select 1 from public.roles r where r.id = role_id and private.is_org_member(r.organization_id)));
create policy role_permissions_manage on public.role_permissions for all to authenticated
  using (exists (select 1 from public.roles r where r.id = role_id and private.has_permission(r.organization_id, 'access.manage')))
  with check (exists (select 1 from public.roles r where r.id = role_id and private.has_permission(r.organization_id, 'access.manage')));

create policy role_assignments_select on public.member_role_assignments for select to authenticated
  using (private.is_org_member(organization_id));
create policy role_assignments_manage on public.member_role_assignments for all to authenticated
  using (private.has_permission(organization_id, 'access.manage'))
  with check (private.has_permission(organization_id, 'access.manage'));

create policy projects_select on public.projects for select to authenticated
  using (private.can_access_project(id));
create policy projects_insert on public.projects for insert to authenticated
  with check (private.has_permission(organization_id, 'project.create', null, area_id));
create policy projects_update on public.projects for update to authenticated
  using (private.has_permission(organization_id, 'project.manage', id, area_id))
  with check (private.has_permission(organization_id, 'project.manage', id, area_id));
create policy projects_delete on public.projects for delete to authenticated
  using (private.has_permission(organization_id, 'organization.manage'));

create policy project_members_select on public.project_members for select to authenticated
  using (private.can_access_project(project_id));
create policy project_members_manage on public.project_members for all to authenticated
  using (exists (select 1 from public.projects p where p.id = project_id and private.has_permission(p.organization_id, 'project.manage', p.id, p.area_id)))
  with check (exists (select 1 from public.projects p where p.id = project_id and private.has_permission(p.organization_id, 'project.manage', p.id, p.area_id)));

create policy milestones_select on public.project_milestones for select to authenticated
  using (private.can_access_project(project_id));
create policy milestones_manage on public.project_milestones for all to authenticated
  using (exists (select 1 from public.projects p where p.id = project_id and private.has_permission(p.organization_id, 'project.manage', p.id, p.area_id)))
  with check (exists (select 1 from public.projects p where p.id = project_id and private.has_permission(p.organization_id, 'project.manage', p.id, p.area_id)));

create policy tasks_select on public.tasks for select to authenticated
  using (private.can_access_project(project_id) and exists (
    select 1 from public.projects p where p.id = project_id and private.has_permission(p.organization_id, 'task.view', p.id, coalesce(area_id, p.area_id))
  ));
create policy tasks_insert on public.tasks for insert to authenticated
  with check (created_by = (select auth.uid()) and exists (
    select 1 from public.projects p where p.id = project_id and private.can_access_project(p.id)
      and private.has_permission(p.organization_id, 'task.create', p.id, coalesce(area_id, p.area_id))
  ));
create policy tasks_update on public.tasks for update to authenticated
  using (exists (
    select 1 from public.projects p
    where p.id = project_id and private.can_access_project(p.id) and (
      private.has_permission(p.organization_id, 'task.manage', p.id, coalesce(area_id, p.area_id))
      or (private.has_permission(p.organization_id, 'task.update_own', p.id, coalesce(area_id, p.area_id)) and exists (
        select 1 from public.task_assignees ta join public.organization_members m on m.id = ta.member_id
        where ta.task_id = tasks.id and m.user_id = (select auth.uid()) and m.status = 'active'
      ))
    )
  )) with check (private.can_access_project(project_id));

create policy task_assignees_select on public.task_assignees for select to authenticated
  using (exists (select 1 from public.tasks t where t.id = task_id and private.can_access_project(t.project_id)));
create policy task_assignees_manage on public.task_assignees for all to authenticated
  using (exists (select 1 from public.tasks t join public.projects p on p.id = t.project_id where t.id = task_id and private.has_permission(p.organization_id, 'task.manage', p.id, coalesce(t.area_id, p.area_id))))
  with check (exists (select 1 from public.tasks t join public.projects p on p.id = t.project_id where t.id = task_id and private.has_permission(p.organization_id, 'task.manage', p.id, coalesce(t.area_id, p.area_id))));

create policy task_dependencies_access on public.task_dependencies for all to authenticated
  using (exists (select 1 from public.tasks t where t.id = predecessor_task_id and private.can_access_project(t.project_id)))
  with check (exists (select 1 from public.tasks t join public.projects p on p.id = t.project_id where t.id = predecessor_task_id and private.has_permission(p.organization_id, 'task.manage', p.id, coalesce(t.area_id, p.area_id))));

create policy task_comments_select on public.task_comments for select to authenticated
  using (exists (select 1 from public.tasks t where t.id = task_id and private.can_access_project(t.project_id)) and deleted_at is null);
create policy task_comments_insert on public.task_comments for insert to authenticated
  with check (author_id = (select auth.uid()) and exists (select 1 from public.tasks t where t.id = task_id and private.can_access_project(t.project_id)));
create policy task_comments_update_own on public.task_comments for update to authenticated
  using (author_id = (select auth.uid())) with check (author_id = (select auth.uid()));

create policy task_progress_select on public.task_progress_entries for select to authenticated
  using (exists (select 1 from public.tasks t where t.id = task_id and private.can_access_project(t.project_id)));
create policy task_progress_insert on public.task_progress_entries for insert to authenticated
  with check (reported_by = (select auth.uid()) and exists (select 1 from public.tasks t where t.id = task_id and private.can_access_project(t.project_id)));

create policy project_history_select on public.project_status_history for select to authenticated
  using (private.can_access_project(project_id));
create policy task_history_select on public.task_status_history for select to authenticated
  using (exists (select 1 from public.tasks t where t.id = task_id and private.can_access_project(t.project_id)));

create policy files_select on public.files for select to authenticated
  using (private.has_permission(organization_id, 'document.view') and deleted_at is null);
create policy files_insert on public.files for insert to authenticated
  with check (uploaded_by = (select auth.uid()) and private.has_permission(organization_id, 'document.manage'));
create policy files_update on public.files for update to authenticated
  using (uploaded_by = (select auth.uid()) or private.has_permission(organization_id, 'document.manage'))
  with check (private.has_permission(organization_id, 'document.manage'));

create policy documents_select on public.documents for select to authenticated
  using (deleted_at is null and (project_id is null or private.can_access_project(project_id)) and private.has_permission(organization_id, 'document.view', project_id));
create policy documents_manage on public.documents for all to authenticated
  using (private.has_permission(organization_id, 'document.manage', project_id))
  with check (created_by = (select auth.uid()) and private.has_permission(organization_id, 'document.manage', project_id));

create policy diagrams_select on public.activity_diagrams for select to authenticated
  using (deleted_at is null and private.can_access_project(project_id));
create policy diagrams_manage on public.activity_diagrams for all to authenticated
  using (exists (select 1 from public.projects p where p.id = project_id and private.has_permission(p.organization_id, 'diagram.manage', p.id, p.area_id)))
  with check (created_by = (select auth.uid()) and exists (select 1 from public.projects p where p.id = project_id and private.has_permission(p.organization_id, 'diagram.manage', p.id, p.area_id)));

-- Inventario y solicitudes.
create policy material_categories_select on public.material_categories for select to authenticated
  using (private.has_permission(organization_id, 'material.view'));
create policy material_categories_manage on public.material_categories for all to authenticated
  using (private.has_permission(organization_id, 'material.manage_catalog'))
  with check (private.has_permission(organization_id, 'material.manage_catalog'));
create policy warehouses_select on public.warehouses for select to authenticated
  using (private.has_permission(organization_id, 'material.view'));
create policy warehouses_manage on public.warehouses for all to authenticated
  using (private.has_permission(organization_id, 'material.manage_stock'))
  with check (private.has_permission(organization_id, 'material.manage_stock'));
create policy materials_select on public.materials for select to authenticated
  using (private.has_permission(organization_id, 'material.view') and deleted_at is null);
create policy materials_manage on public.materials for all to authenticated
  using (private.has_permission(organization_id, 'material.manage_catalog'))
  with check (private.has_permission(organization_id, 'material.manage_catalog'));
create policy material_stock_select on public.material_stock for select to authenticated
  using (exists (select 1 from public.materials m where m.id = material_id and private.has_permission(m.organization_id, 'material.view')));

create policy material_requests_select on public.material_requests for select to authenticated
  using (private.can_access_material_request(id));
create policy material_requests_insert on public.material_requests for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and requested_by_member_id = private.current_member_id(organization_id)
    and private.can_access_project(project_id)
    and private.has_permission(organization_id, 'material.request', project_id)
  );
create policy material_requests_update on public.material_requests for update to authenticated
  using (
    (requested_by_member_id = private.current_member_id(organization_id) and status_code in ('draft', 'needs_changes'))
    or private.has_permission(organization_id, 'material.approve', project_id)
    or private.has_permission(organization_id, 'material.manage_stock', project_id)
  ) with check (private.can_access_material_request(id));

create policy material_request_items_select on public.material_request_items for select to authenticated
  using (private.can_access_material_request(request_id));
create policy material_request_items_manage on public.material_request_items for all to authenticated
  using (exists (select 1 from public.material_requests r where r.id = request_id and (
    (r.requested_by_member_id = private.current_member_id(r.organization_id) and r.status_code in ('draft', 'needs_changes'))
    or private.has_permission(r.organization_id, 'material.manage_stock', r.project_id)
  ))) with check (private.can_access_material_request(request_id));
create policy material_request_history_select on public.material_request_status_history for select to authenticated
  using (private.can_access_material_request(request_id));

create policy stock_movements_select on public.stock_movements for select to authenticated
  using (private.has_permission(organization_id, 'material.view', project_id));
create policy stock_movements_insert on public.stock_movements for insert to authenticated
  with check (recorded_by = (select auth.uid()) and private.has_permission(organization_id, 'material.manage_stock', project_id));

create policy deliveries_select on public.material_deliveries for select to authenticated
  using (private.can_access_material_request(request_id));
create policy deliveries_insert on public.material_deliveries for insert to authenticated
  with check (private.has_permission(organization_id, 'material.manage_stock'));
create policy delivery_items_select on public.material_delivery_items for select to authenticated
  using (exists (select 1 from public.material_deliveries d where d.id = delivery_id and private.can_access_material_request(d.request_id)));
create policy delivery_items_insert on public.material_delivery_items for insert to authenticated
  with check (exists (select 1 from public.material_deliveries d where d.id = delivery_id and private.has_permission(d.organization_id, 'material.manage_stock')));

create policy usage_reports_select on public.material_usage_reports for select to authenticated
  using (private.can_access_material_request(request_id));
create policy usage_reports_insert on public.material_usage_reports for insert to authenticated
  with check (reported_by_member_id = private.current_member_id(organization_id) and private.can_access_material_request(request_id));
create policy usage_report_items_access on public.material_usage_report_items for all to authenticated
  using (exists (select 1 from public.material_usage_reports u where u.id = usage_report_id and private.can_access_material_request(u.request_id)))
  with check (exists (select 1 from public.material_usage_reports u where u.id = usage_report_id and u.reported_by_member_id = private.current_member_id(u.organization_id)));

create policy returns_select on public.material_returns for select to authenticated
  using (private.can_access_material_request(request_id));
create policy returns_insert on public.material_returns for insert to authenticated
  with check (private.has_permission(organization_id, 'material.manage_stock'));
create policy return_items_access on public.material_return_items for all to authenticated
  using (exists (select 1 from public.material_returns r where r.id = return_id and private.can_access_material_request(r.request_id)))
  with check (exists (select 1 from public.material_returns r where r.id = return_id and private.has_permission(r.organization_id, 'material.manage_stock')));

-- Aprobaciones genéricas.
create policy approval_flows_select on public.approval_flows for select to authenticated
  using (private.is_org_member(organization_id));
create policy approval_flows_manage on public.approval_flows for all to authenticated
  using (private.has_permission(organization_id, 'approval.manage'))
  with check (private.has_permission(organization_id, 'approval.manage'));
create policy approval_flow_steps_select on public.approval_flow_steps for select to authenticated
  using (exists (select 1 from public.approval_flows f where f.id = flow_id and private.is_org_member(f.organization_id)));
create policy approval_flow_steps_manage on public.approval_flow_steps for all to authenticated
  using (exists (select 1 from public.approval_flows f where f.id = flow_id and private.has_permission(f.organization_id, 'approval.manage')))
  with check (exists (select 1 from public.approval_flows f where f.id = flow_id and private.has_permission(f.organization_id, 'approval.manage')));
create policy approval_instances_select on public.approval_instances for select to authenticated
  using ((project_id is null and private.is_org_member(organization_id)) or private.can_access_project(project_id));
create policy approval_instances_insert on public.approval_instances for insert to authenticated
  with check (requested_by_member_id = private.current_member_id(organization_id) and (project_id is null or private.can_access_project(project_id)));
create policy approval_instances_update on public.approval_instances for update to authenticated
  using (private.has_permission(organization_id, 'approval.decide', project_id) or private.has_permission(organization_id, 'approval.manage', project_id))
  with check (private.is_org_member(organization_id));
create policy approval_instance_steps_select on public.approval_instance_steps for select to authenticated
  using (exists (select 1 from public.approval_instances i where i.id = approval_instance_id and ((i.project_id is null and private.is_org_member(i.organization_id)) or private.can_access_project(i.project_id))));
create policy approval_instance_steps_update on public.approval_instance_steps for update to authenticated
  using (exists (select 1 from public.approval_instances i where i.id = approval_instance_id and (
    assigned_member_id = private.current_member_id(i.organization_id)
    or private.has_permission(i.organization_id, 'approval.decide', i.project_id)
  ))) with check (true);

create policy notifications_select_own on public.notifications for select to authenticated
  using (recipient_user_id = (select auth.uid()));
create policy notifications_update_own on public.notifications for update to authenticated
  using (recipient_user_id = (select auth.uid())) with check (recipient_user_id = (select auth.uid()));
create policy audit_logs_select on public.audit_logs for select to authenticated
  using (organization_id is not null and private.has_permission(organization_id, 'audit.view', project_id));

-- -----------------------------------------------------------------------------
-- Grants. RLS sigue siendo obligatorio después de estos permisos SQL.
-- -----------------------------------------------------------------------------

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

grant select on all tables in schema public to authenticated;
grant update on public.profiles to authenticated;
grant insert, update on public.organizations to authenticated;
grant insert, update on public.organization_members, public.areas, public.roles, public.role_permissions, public.member_role_assignments to authenticated;
grant delete on public.roles, public.role_permissions, public.member_role_assignments to authenticated;
grant insert, update, delete on public.projects, public.project_members, public.project_milestones to authenticated;
grant insert, update on public.tasks, public.task_comments to authenticated;
grant insert, update, delete on public.task_assignees, public.task_dependencies to authenticated;
grant insert on public.task_progress_entries to authenticated;
grant insert, update on public.files, public.documents, public.activity_diagrams to authenticated;
grant insert, update, delete on public.material_categories, public.warehouses, public.materials to authenticated;
grant insert, update on public.material_requests, public.material_request_items to authenticated;
grant delete on public.material_request_items to authenticated;
grant insert on public.stock_movements, public.material_deliveries, public.material_delivery_items to authenticated;
grant insert on public.material_usage_reports, public.material_usage_report_items, public.material_returns, public.material_return_items to authenticated;
grant update on public.material_usage_reports to authenticated;
grant insert, update, delete on public.approval_flows, public.approval_flow_steps to authenticated;
grant insert, update on public.approval_instances, public.approval_instance_steps to authenticated;
grant update on public.notifications to authenticated;

grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;

-- Almacén privado para evidencias y documentos.
insert into storage.buckets (id, name, public, file_size_limit)
values ('project-files', 'project-files', false, 52428800)
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit;

create policy project_files_select on storage.objects for select to authenticated
  using (bucket_id = 'project-files' and exists (
    select 1 from public.files f
    where f.bucket_id = storage.objects.bucket_id and f.object_path = storage.objects.name
      and f.deleted_at is null and private.has_permission(f.organization_id, 'document.view')
  ));

create policy project_files_insert on storage.objects for insert to authenticated
  with check (
    bucket_id = 'project-files'
    and (storage.foldername(name))[1] ~ '^[0-9a-fA-F-]{36}$'
    and private.has_permission(((storage.foldername(name))[1])::uuid, 'document.manage')
  );

create policy project_files_update on storage.objects for update to authenticated
  using (bucket_id = 'project-files' and exists (
    select 1 from public.files f where f.bucket_id = storage.objects.bucket_id and f.object_path = storage.objects.name
      and private.has_permission(f.organization_id, 'document.manage')
  )) with check (bucket_id = 'project-files');

create policy project_files_delete on storage.objects for delete to authenticated
  using (bucket_id = 'project-files' and exists (
    select 1 from public.files f where f.bucket_id = storage.objects.bucket_id and f.object_path = storage.objects.name
      and private.has_permission(f.organization_id, 'document.manage')
  ));

-- -----------------------------------------------------------------------------
-- Vistas seguras para paneles y reportes
-- -----------------------------------------------------------------------------

create view public.project_progress_summary
with (security_invoker = true)
as
select
  p.id as project_id,
  p.organization_id,
  p.code,
  p.name,
  p.status_code,
  count(t.id) filter (where t.deleted_at is null) as total_tasks,
  count(t.id) filter (where t.deleted_at is null and t.status_code = 'completed') as completed_tasks,
  count(t.id) filter (where t.deleted_at is null and t.due_at < now() and t.status_code not in ('completed', 'cancelled')) as overdue_tasks,
  case
    when p.progress_mode = 'manual' then p.manual_progress
    when count(t.id) filter (where t.deleted_at is null) = 0 then 0
    else round(avg(t.progress) filter (where t.deleted_at is null), 2)
  end as progress_percent
from public.projects p
left join public.tasks t on t.project_id = p.id
where p.deleted_at is null
group by p.id;

create view public.inventory_availability
with (security_invoker = true)
as
select
  m.id as material_id,
  m.organization_id,
  m.sku,
  m.name,
  m.unit_of_measure,
  m.minimum_stock,
  w.id as warehouse_id,
  w.name as warehouse_name,
  s.on_hand,
  s.reserved,
  s.on_hand - s.reserved as available,
  case
    when s.on_hand - s.reserved <= 0 then 'out_of_stock'
    when s.on_hand - s.reserved <= m.minimum_stock then 'low_stock'
    else 'available'
  end as availability_status,
  s.updated_at
from public.materials m
join public.material_stock s on s.material_id = m.id
join public.warehouses w on w.id = s.warehouse_id
where m.deleted_at is null and m.is_active and w.is_active;

create view public.material_request_tracking
with (security_invoker = true)
as
select
  r.id as request_id,
  r.organization_id,
  r.request_number,
  r.project_id,
  p.name as project_name,
  r.requested_by_member_id,
  pr.display_name as requester_name,
  r.status_code,
  r.priority_code,
  r.needed_at,
  r.submitted_at,
  r.closed_at,
  count(i.id) as item_count,
  coalesce(sum(i.quantity_requested), 0) as total_quantity_requested,
  coalesce(sum(i.quantity_delivered), 0) as total_quantity_delivered,
  r.created_at,
  r.updated_at
from public.material_requests r
join public.projects p on p.id = r.project_id
join public.organization_members om on om.id = r.requested_by_member_id
join public.profiles pr on pr.id = om.user_id
left join public.material_request_items i on i.request_id = r.id
where r.deleted_at is null
group by r.id, p.name, pr.display_name;

grant select on public.project_progress_summary, public.inventory_availability, public.material_request_tracking to authenticated, service_role;

commit;

