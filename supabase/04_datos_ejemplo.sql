-- NEXO: DATOS DE EJEMPLO
-- Ejecutar TODO en Supabase > SQL Editor como postgres.
-- Requiere haber ejecutado 01_instalar_nexo.sql y 02_crear_administrador.sql.
-- Puedes repetirlo: si el proyecto de ejemplo ya existe, no duplica datos.
-- No crea usuarios, no cambia roles y no borra ni actualiza registros existentes.
-- Todos los registros creados son DEMOSTRATIVOS.

begin;

do $$
declare
  v_email text := '2023100659@ucss.pe';
  v_org_slug text := 'mi-organizacion';
  v_user uuid;
  v_org uuid;
  v_member uuid;
  v_area uuid;
  v_project uuid;
  v_warehouse uuid;
  v_category uuid;
  v_milestone uuid;
  v_task uuid;
  v_previous_task uuid;
  v_install_task uuid;
  v_material uuid;
  v_cable uuid;
  v_connector uuid;
  v_switch uuid;
  v_request uuid;
  v_flow uuid;
  v_flow_step uuid;
  v_approval uuid;
  v_approver_role uuid;
  v_row record;
  v_today date := (now() at time zone 'America/Lima')::date;
begin
  -- Se vincula con el usuario y la organización existentes.
  select id into v_user from auth.users where lower(email) = lower(trim(v_email));
  if v_user is null then
    raise exception 'No existe el usuario %. Créalo primero en Authentication > Users.', v_email;
  end if;
  select id into v_org from public.organizations
    where slug = v_org_slug and deleted_at is null and is_active;
  if v_org is null then
    raise exception 'No existe la organización %. Ejecuta 02_crear_administrador.sql o cambia v_org_slug.', v_org_slug;
  end if;
  select id into v_member from public.organization_members
    where organization_id = v_org and user_id = v_user and status = 'active';
  if v_member is null then
    raise exception 'El usuario no es miembro activo de la organización.';
  end if;
  if not exists (
    select 1 from public.member_role_assignments a
    join public.roles r on r.id = a.role_id
    where a.member_id = v_member and a.organization_id = v_org
      and r.code = 'admin' and r.is_active and a.scope_type = 'organization'
      and a.valid_from <= now() and (a.valid_until is null or a.valid_until > now())
  ) then
    raise exception 'Ejecuta primero 02_crear_administrador.sql para asignar el administrador.';
  end if;

  -- Serializa dos cargas simultáneas del mismo ejemplo.
  perform pg_advisory_xact_lock(hashtextextended(v_org::text || ':nexo-demo-red-v1', 0));
  select id into v_project from public.projects
    where organization_id = v_org and code = 'DEMO-RED-001';
  if v_project is not null then
    if not exists (select 1 from public.projects where id = v_project
      and metadata ->> 'demo_seed' = 'nexo-demo-red-v1') then
      raise exception 'El código DEMO-RED-001 ya pertenece a otro proyecto. No se modificó.';
    end if;
    raise notice 'El ejemplo ya está cargado. Proyecto: %. No se duplicaron datos.', v_project;
    return;
  end if;

  -- 1. Área, proyecto y responsable.
  insert into public.areas(organization_id, code, name, description, manager_member_id, created_by)
  values (v_org, 'DEMO-TI', 'Tecnología — ejemplo', 'Área demostrativa de soporte y redes.', v_member, v_user)
  on conflict (organization_id, code) do nothing;
  select id into v_area from public.areas where organization_id = v_org and code = 'DEMO-TI';

  insert into public.projects(organization_id, area_id, code, name, description, objective,
    status_code, priority_code, manager_member_id, planned_start_date, planned_end_date,
    budget, progress_mode, created_by, metadata)
  values (v_org, v_area, 'DEMO-RED-001', 'Implementación de red del laboratorio — ejemplo',
    'Proyecto demostrativo: conectar 20 estaciones, ordenar el cableado y validar conectividad.',
    'Habilitar una red estable para las prácticas del laboratorio.',
    'active', 'high', v_member, v_today - 7, v_today + 21,
    8500, 'tasks', v_user, '{"demo_seed":"nexo-demo-red-v1"}'::jsonb)
  returning id into v_project;

  insert into public.project_members(project_id, member_id, project_title, is_project_manager, allocation_percent, created_by)
  values (v_project, v_member, 'Responsable del proyecto de ejemplo', true, 50, v_user);

  insert into public.project_milestones(project_id, name, status_code, planned_date, weight, display_order, created_by)
  values (v_project, 'Infraestructura instalada', 'in_progress', v_today + 10, 60, 1, v_user)
  returning id into v_milestone;
  insert into public.project_milestones(project_id, name, status_code, planned_date, weight, display_order, created_by)
  values (v_project, 'Pruebas y aceptación del laboratorio', 'pending', v_today + 21, 40, 2, v_user);

  -- 2. Seis tareas, una secuencia de dependencias y avances.
  for v_row in select * from (values
    ('DEMO-T01', 'Levantar requerimientos del laboratorio', 'completed', 'high', 100, -7, -5, 8),
    ('DEMO-T02', 'Diseñar la distribución de red', 'completed', 'high', 100, -5, -2, 12),
    ('DEMO-T03', 'Gestionar materiales y equipos', 'in_progress', 'high', 60, -2, 3, 10),
    ('DEMO-T04', 'Instalar cableado y puntos de red', 'in_progress', 'high', 30, 0, 10, 24),
    ('DEMO-T05', 'Configurar equipos y probar conectividad', 'pending', 'medium', 0, 10, 17, 16),
    ('DEMO-T06', 'Capacitar y entregar el laboratorio', 'pending', 'medium', 0, 17, 21, 8)
  ) as x(code, title, status, priority, progress, starts_in, due_in, hours)
  loop
    insert into public.tasks(project_id, area_id, code, title, description, acceptance_criteria,
      status_code, priority_code, progress, planned_start_at, due_at,
      completed_at, estimated_hours, display_order, created_by)
    values (v_project, v_area, v_row.code, v_row.title,
      'Tarea demostrativa del proyecto de red del laboratorio.',
      'Resultado revisado y evidencia registrada por el responsable.',
      v_row.status, v_row.priority, v_row.progress,
      (v_today + v_row.starts_in)::timestamp at time zone 'America/Lima',
      (v_today + v_row.due_in)::timestamp at time zone 'America/Lima',
      case when v_row.status = 'completed' then
        (v_today + v_row.due_in)::timestamp at time zone 'America/Lima' else null end,
      v_row.hours, right(v_row.code, 2)::integer, v_user)
    returning id into v_task;

    insert into public.task_assignees(task_id, member_id, assignment_type, assigned_by)
    values (v_task, v_member, 'responsible', v_user);
    insert into public.task_progress_entries(task_id, reported_by, progress, note)
    values (v_task, v_user, v_row.progress, 'Avance inicial demostrativo.');
    if v_previous_task is not null then
      insert into public.task_dependencies(predecessor_task_id, successor_task_id)
      values (v_previous_task, v_task);
    end if;
    v_previous_task := v_task;
    if v_row.code = 'DEMO-T04' then
      v_install_task := v_task;
      update public.tasks set milestone_id = v_milestone where id = v_task;
      insert into public.task_comments(task_id, author_id, body)
      values (v_task, v_user, 'Ejemplo: se identificaron las rutas de cableado. La siguiente etapa requiere la aprobación de materiales.');
    end if;
  end loop;

  -- 3. Catálogo y existencias. Los saldos se generan mediante movimientos.
  insert into public.material_categories(organization_id, code, name, description)
  values (v_org, 'DEMO-RED', 'Redes — ejemplo', 'Materiales y equipos demostrativos.')
  on conflict (organization_id, code) do nothing;
  select id into v_category from public.material_categories where organization_id = v_org and code = 'DEMO-RED';
  insert into public.warehouses(organization_id, code, name, location, manager_member_id)
  values (v_org, 'DEMO-ALM', 'Almacén de tecnología — ejemplo', 'Ubicación demostrativa: laboratorio', v_member)
  on conflict (organization_id, code) do nothing;
  select id into v_warehouse from public.warehouses where organization_id = v_org and code = 'DEMO-ALM';

  for v_row in select * from (values
    ('DEMO-CAT6', 'Cable UTP categoría 6', 'metro', 'consumable', 50, 3.50, 300),
    ('DEMO-RJ45', 'Conector RJ45', 'unidad', 'consumable', 20, 1.20, 100),
    ('DEMO-SW24', 'Switch de 24 puertos', 'unidad', 'returnable', 1, 850.00, 3),
    ('DEMO-PATCH', 'Patch cord de 2 metros', 'unidad', 'consumable', 10, 12.00, 30),
    ('DEMO-TEST', 'Probador de cable de red', 'unidad', 'returnable', 1, 150.00, 1)
  ) as x(sku, name, unit, kind, minimum, cost, initial_quantity)
  loop
    -- Evita sumar existencias sobre un SKU que alguien ya haya registrado.
    if exists (select 1 from public.materials where organization_id = v_org and sku = v_row.sku) then
      raise exception 'El SKU % ya existe sin el proyecto de ejemplo. No se cargó ningún dato.', v_row.sku;
    end if;
    insert into public.materials(organization_id, category_id, sku, name, description,
      unit_of_measure, material_kind, minimum_stock, standard_cost,
      requires_usage_report, requires_return, created_by, metadata)
    values (v_org, v_category, v_row.sku, v_row.name, 'Material de demostración; no representa inventario real.',
      v_row.unit, v_row.kind, v_row.minimum, v_row.cost,
      v_row.kind = 'consumable', v_row.kind = 'returnable', v_user,
      '{"demo_seed":"nexo-demo-red-v1"}'::jsonb)
    returning id into v_material;

    -- El trigger calcula deltas y saldos antes de validar el registro.
    insert into public.stock_movements(organization_id, material_id, warehouse_id,
      movement_type_code, quantity, quantity_delta, balance_after,
      reference_type, reference_id, project_id, reason, recorded_by)
    values (v_org, v_material, v_warehouse, 'initial', v_row.initial_quantity, 0, 0,
      'demo_project', v_project, v_project, 'Existencia inicial de ejemplo.', v_user);

    if v_row.sku = 'DEMO-CAT6' then v_cable := v_material; end if;
    if v_row.sku = 'DEMO-RJ45' then v_connector := v_material; end if;
    if v_row.sku = 'DEMO-SW24' then v_switch := v_material; end if;
  end loop;

  -- 4. Solicitud pendiente: 120 metros de cable + 40 conectores = S/ 468.
  insert into public.material_requests(organization_id, request_number, project_id, task_id,
    requested_by_member_id, justification, priority_code, needed_at, estimated_total, created_by)
  values (v_org, 'DEMO-SOL-001', v_project, v_install_task, v_member,
    'Ejemplo: cableado y conectores para habilitar 20 puntos de red.', 'high',
    (v_today + 3)::timestamp at time zone 'America/Lima', 468, v_user)
  returning id into v_request;
  insert into public.material_request_items(request_id, material_id, preferred_warehouse_id, quantity_requested, unit_cost)
  values (v_request, v_cable, v_warehouse, 120, 3.50), (v_request, v_connector, v_warehouse, 40, 1.20);
  -- Usa una transición permitida y genera historial con el trigger existente.
  update public.material_requests set status_code = 'pending', submitted_at = now() where id = v_request;
  update public.material_request_status_history
    set changed_by = v_user, comment = 'Envío de solicitud demostrativa para revisión.'
    where request_id = v_request and from_status = 'draft' and to_status = 'pending';

  -- 5. Aprobación pendiente, sin registrar una autoaprobación ficticia.
  select id into v_approver_role from public.roles
    where organization_id = v_org and code = 'approver';
  if v_approver_role is null then raise exception 'Falta el rol approver de la organización.'; end if;
  insert into public.approval_flows(organization_id, code, name, subject_type, description)
  values (v_org, 'DEMO-APR-MAT', 'Aprobación de materiales — ejemplo', 'material_request',
    'Ejemplo de revisión por un aprobador distinto del solicitante.')
  returning id into v_flow;
  insert into public.approval_flow_steps(flow_id, step_order, name, approver_type, role_id, allow_self_approval)
  values (v_flow, 1, 'Revisar necesidad y presupuesto', 'role', v_approver_role, false)
  returning id into v_flow_step;
  insert into public.approval_instances(organization_id, flow_id, subject_type, subject_id,
    project_id, requested_by_member_id, metadata)
  values (v_org, v_flow, 'material_request', v_request, v_project, v_member,
    '{"demo_seed":"nexo-demo-red-v1"}'::jsonb)
  returning id into v_approval;
  insert into public.approval_instance_steps(approval_instance_id, flow_step_id, step_order,
    assigned_role_id, due_at)
  values (v_approval, v_flow_step, 1, v_approver_role,
    (v_today + 2)::timestamp at time zone 'America/Lima');

  -- 6. Segunda solicitud en borrador: préstamo de un switch.
  insert into public.material_requests(organization_id, request_number, project_id,
    requested_by_member_id, justification, priority_code, needed_at, estimated_total, created_by)
  values (v_org, 'DEMO-SOL-002', v_project, v_member,
    'Ejemplo: préstamo de un switch para realizar pruebas; requiere devolución.', 'medium',
    (v_today + 10)::timestamp at time zone 'America/Lima', 850, v_user)
  returning id into v_request;
  insert into public.material_request_items(request_id, material_id, preferred_warehouse_id, quantity_requested, unit_cost)
  values (v_request, v_switch, v_warehouse, 1, 850);

  -- 7. Diagrama de actividades sin archivos de evidencia ficticios.
  insert into public.activity_diagrams(project_id, name, description, format, source, created_by)
  values (v_project, 'Flujo de materiales del laboratorio — ejemplo',
    'Solicitud, aprobación, reserva, entrega y cierre.', 'mermaid',
    E'flowchart TD\n A[Solicitar materiales] --> B{Revisar solicitud}\n B -->|Aprobar| C[Reservar stock]\n B -->|Corregir| A\n B -->|Rechazar| R[Fin]\n C --> D[Entregar materiales]\n D --> E{Tipo de material}\n E -->|Consumible| F[Reportar uso]\n E -->|Equipo prestable| G[Registrar devolución]\n F --> H[Cerrar solicitud]\n G --> H',
    v_user);

  raise notice 'Ejemplo cargado: proyecto %, 6 tareas, 5 materiales, 2 solicitudes y 1 aprobación pendiente.', v_project;
end;
$$;

commit;

-- Resultados de comprobación del ejemplo.
select s.code, s.name, s.total_tasks, s.completed_tasks, s.progress_percent
from public.project_progress_summary s
join public.organizations o on o.id = s.organization_id
where s.code = 'DEMO-RED-001' and o.slug = 'mi-organizacion';

select r.request_number, r.project_name, r.status_code, r.item_count, r.total_quantity_requested
from public.material_request_tracking r
join public.projects p on p.id = r.project_id
join public.organizations o on o.id = r.organization_id
where p.code = 'DEMO-RED-001' and o.slug = 'mi-organizacion'
order by r.request_number;

select i.sku, i.name, i.warehouse_name, i.on_hand, i.reserved, i.available
from public.inventory_availability i
join public.organizations o on o.id = i.organization_id
where i.sku like 'DEMO-%' and o.slug = 'mi-organizacion'
order by i.sku;
