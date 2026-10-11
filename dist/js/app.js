const projects = [
  { code: "ER", tone: "blue", name: "Implementación ERP", description: "Centralización de procesos administrativos, inventario y compras.", area: "Tecnología", due: "18 oct.", progress: 82, people: ["CR", "AM", "JP"], status: "En curso" },
  { code: "RL", tone: "teal", name: "Renovación de laboratorio", description: "Adecuación de infraestructura y adquisición de equipos.", area: "Infraestructura", due: "02 nov.", progress: 68, people: ["LV", "JP", "AM"], status: "En curso" },
  { code: "CA", tone: "orange", name: "Campaña de admisión", description: "Plan de contenidos y difusión para el nuevo periodo académico.", area: "Marketing", due: "28 sep.", progress: 54, people: ["DT", "MS"], status: "En riesgo" },
  { code: "BD", tone: "purple", name: "Biblioteca digital", description: "Repositorio académico y sistema de consulta documental.", area: "Académica", due: "12 dic.", progress: 41, people: ["MS", "CR"], status: "En curso" },
  { code: "SE", tone: "blue", name: "Seguridad estudiantil", description: "Nuevo protocolo de acceso y respuesta ante incidencias.", area: "Bienestar", due: "20 nov.", progress: 35, people: ["AM", "LV"], status: "En riesgo" },
  { code: "PA", tone: "teal", name: "Portal de egresados", description: "Red de oportunidades y seguimiento profesional.", area: "Académica", due: "15 ene.", progress: 23, people: ["CR", "DT", "MS"], status: "En curso" },
  { code: "SA", tone: "orange", name: "Sistema de asistencia", description: "Registro centralizado de asistencia para estudiantes y docentes.", area: "Tecnología", due: "30 nov.", progress: 57, people: ["CR", "AM"], status: "En curso" },
  { code: "CP", tone: "purple", name: "Capacitación docente", description: "Programa de actualización en herramientas de aprendizaje digital.", area: "Académica", due: "15 ago.", progress: 100, people: ["MS", "DT"], status: "Finalizado" }
];

const tasks = [
  { status: "Pendiente", project: "Implementación ERP", tag: "ERP", title: "Documentar flujo de compras", description: "Registrar las reglas acordadas con Logística.", assignee: "JP", due: "22 sep." },
  { status: "Pendiente", project: "Renovación de laboratorio", tag: "LAB", title: "Confirmar especificaciones técnicas", description: "Validar requisitos con los docentes responsables.", assignee: "LV", due: "24 sep." },
  { status: "En progreso", project: "Implementación ERP", tag: "ERP", title: "Configurar módulo de inventario", description: "Crear categorías, almacenes y unidades de medida.", assignee: "CR", due: "Hoy" },
  { status: "En progreso", project: "Campaña de admisión", tag: "CAMPAÑA", title: "Preparar calendario de publicaciones", description: "Distribuir piezas por canal y fecha.", assignee: "DT", due: "23 sep." },
  { status: "En revisión", project: "Renovación de laboratorio", tag: "LAB", title: "Validar cotización de equipos", description: "Comparar propuestas y condiciones de garantía.", assignee: "LV", due: "Mañana" },
  { status: "En revisión", project: "Implementación ERP", tag: "ERP", title: "Probar permisos de aprobación", description: "Comprobar accesos de jefatura y logística.", assignee: "AM", due: "25 sep." },
  { status: "Completada", project: "Biblioteca digital", tag: "BIBLIOTECA", title: "Definir categorías documentales", description: "Estructura inicial aprobada por el área académica.", assignee: "MS", due: "18 sep." }
];

const approvals = [
  { id: "MAT-024", title: "12 cables de red CAT6", project: "Renovación de laboratorio", requester: "Lucía Vega", date: "Hace 20 min", amount: "S/ 480.00", area: "Infraestructura", reason: "Instalación de los nuevos puntos de red del laboratorio 3. Se adjuntó la cotización del proveedor seleccionado." },
  { id: "MAT-023", title: "Licencias de software", project: "Implementación ERP", requester: "Carlos Ruiz", date: "Hace 2 h", amount: "S/ 1,920.00", area: "Tecnología", reason: "Licencias requeridas para el ambiente de pruebas y capacitación del equipo." },
  { id: "CAM-011", title: "Impresión de material gráfico", project: "Campaña de admisión", requester: "Diego Torres", date: "Ayer", amount: "S/ 760.00", area: "Marketing", reason: "Producción de afiches y material informativo para las visitas programadas." },
  { id: "CAM-010", title: "Ampliación de presupuesto", project: "Campaña de admisión", requester: "Ana Mendoza", date: "Ayer", amount: "S/ 2,500.00", area: "Dirección", reason: "Ampliación para pauta digital durante la semana de inscripciones." }
];

const materialRequests = {
  "MAT-024": { status: "Pendiente", title: "12 cables de red CAT6", requester: "Lucía Vega", project: "Renovación de laboratorio", needed: "Hoy, 17:00", approver: "Ana Mendoza", steps: [["Solicitud registrada", "Hoy, 08:32 · Lucía Vega", "complete"], ["Validación de stock", "Hoy, 08:55 · 12 m reservados por José Pérez", "complete"], ["Aprobación del responsable", "Pendiente · Ana Mendoza", "current"], ["Entrega al solicitante", "Aún no iniciada", ""], ["Reporte de uso o devolución", "Aún no iniciada", ""]] },
  "MAT-023": { status: "Aprobada", title: "3 licencias de software", requester: "Carlos Ruiz", project: "Implementación ERP", needed: "23 sep.", approver: "Ana Mendoza", steps: [["Solicitud registrada", "Ayer, 15:12 · Carlos Ruiz", "complete"], ["Validación de presupuesto", "Ayer, 16:05 · Presupuesto disponible", "complete"], ["Solicitud aprobada", "Hoy, 09:10 · Ana Mendoza", "complete"], ["Compra y entrega", "En preparación por Logística", "current"], ["Cierre", "Aún no iniciado", ""]] },
  "MAT-019": { status: "Entregada", title: "4 millares de papel A4", requester: "Diego Torres", project: "Campaña de admisión", needed: "18 sep.", approver: "Ana Mendoza", steps: [["Solicitud registrada", "16 sep. · Diego Torres", "complete"], ["Solicitud aprobada", "17 sep. · Ana Mendoza", "complete"], ["Material entregado", "18 sep. · José Pérez entregó a Diego Torres", "complete"], ["Reporte de uso", "Pendiente de evidencia", "current"], ["Cierre", "Aún no iniciado", ""]] },
  "MAT-014": { status: "Cerrada", title: "1 proyector multimedia", requester: "María Soto", project: "Biblioteca digital", needed: "12 sep.", approver: "Ana Mendoza", steps: [["Solicitud registrada", "10 sep. · María Soto", "complete"], ["Solicitud aprobada", "10 sep. · Ana Mendoza", "complete"], ["Equipo entregado", "11 sep. · José Pérez", "complete"], ["Equipo devuelto", "17 sep. · Sin incidencias", "complete"], ["Solicitud cerrada", "17 sep. · María Soto", "complete"]] }
};

const accessProfiles = {
  admin: { name: "Ana Mendoza", initials: "AM", role: "Administradora", modules: ["overview", "projects", "tasks", "materials", "approvals", "reports", "team", "permissions", "settings"], actions: ["task", "material", "stock", "project", "invite", "access"], projects: "*" },
  lucia: { name: "Lucía Vega", initials: "LV", role: "Jefa de área", modules: ["overview", "projects", "tasks", "materials", "approvals", "reports"], actions: ["task", "material"], projects: ["Renovación de laboratorio", "Seguridad estudiantil"] },
  carlos: { name: "Carlos Ruiz", initials: "CR", role: "Responsable", modules: ["overview", "projects", "tasks", "reports"], actions: ["task"], projects: ["Implementación ERP", "Biblioteca digital", "Portal de egresados"] },
  jose: { name: "José Pérez", initials: "JP", role: "Gestor de materiales", modules: ["overview", "materials", "approvals"], actions: ["material", "stock"], projects: ["Implementación ERP", "Renovación de laboratorio"] },
  auditor: { name: "Rosa Flores", initials: "RF", role: "Auditora · solo lectura", modules: ["overview", "projects", "reports"], actions: [], projects: "*" }
};

let activeAccessKey = "admin";
let currentProjectStatusFilter = "Todos";

const viewButtons = document.querySelectorAll("[data-view]");
const views = document.querySelectorAll(".view");
const sidebar = document.getElementById("sidebar");
const toast = document.getElementById("toast");
let toastTimer;

function showView(name) {
  if (!accessProfiles[activeAccessKey].modules.includes(name)) {
    showToast("No tienes permiso para acceder a este módulo");
    return;
  }
  viewButtons.forEach(button => button.classList.toggle("active", button.dataset.view === name));
  views.forEach(view => view.classList.toggle("active", view.id === `view-${name}`));
  sidebar.classList.remove("open");
  window.scrollTo({ top: 0, behavior: "smooth" });
}

viewButtons.forEach(button => button.addEventListener("click", () => showView(button.dataset.view)));
document.querySelectorAll("[data-go]").forEach(button => button.addEventListener("click", () => showView(button.dataset.go)));
document.getElementById("menuButton").addEventListener("click", () => sidebar.classList.toggle("open"));

function showToast(message) {
  clearTimeout(toastTimer);
  toast.textContent = `✓  ${message}`;
  toast.classList.add("show");
  toastTimer = setTimeout(() => toast.classList.remove("show"), 2800);
}

document.querySelectorAll("[data-toast]").forEach(button => button.addEventListener("click", () => showToast(button.dataset.toast)));

function renderProjects() {
  document.getElementById("projectGrid").innerHTML = projects.map(project => `
    <article class="project-card" data-project-name="${project.name}" data-status="${project.status}" data-searchable="${project.name} ${project.area} ${project.status}">
      <div class="project-card-top"><span class="project-code ${project.tone}">${project.code}</span><span class="status ${project.status === "En riesgo" ? "warning" : project.status === "Finalizado" ? "success" : "progress"}">${project.status}</span></div>
      <h2>${project.name}</h2><p>${project.description}</p>
      <div class="project-meta"><span>${project.area}</span><span>Entrega ${project.due}</span></div>
      <div class="progress-track"><span style="width:${project.progress}%"></span></div>
      <div class="progress-caption"><span>Avance</span><strong>${project.progress}%</strong></div>
      <div class="project-card-footer"><div class="avatar-stack">${project.people.map(person => `<i>${person}</i>`).join("")}</div><span>${project.people.length} responsables</span></div>
    </article>`).join("");
  applyProjectCardVisibility();
}

function renderKanban(filter = "all") {
  const states = ["Pendiente", "En progreso", "En revisión", "Completada"];
  const profile = accessProfiles[activeAccessKey];
  const filtered = tasks.filter(task => (filter === "all" || task.project === filter) && (profile.projects === "*" || profile.projects.includes(task.project)));
  document.getElementById("kanbanBoard").innerHTML = states.map(state => {
    const items = filtered.filter(task => task.status === state);
    return `<section class="kanban-column"><div class="kanban-head"><strong>${state}</strong><span>${items.length}</span></div>${items.map(task => `<article class="task-card" data-searchable="${task.title} ${task.description} ${task.assignee}"><span class="tag">${task.tag}</span><h3>${task.title}</h3><p>${task.description}</p><div class="task-footer"><span class="task-assignee">${task.assignee}</span><span>◷ ${task.due}</span></div></article>`).join("") || `<div class="search-empty">Sin tareas</div>`}</section>`;
  }).join("");
}

function renderApprovals() {
  const profile = accessProfiles[activeAccessKey];
  const visible = approvals.map((item, index) => ({ item, index })).filter(({ item }) => profile.projects === "*" || profile.projects.includes(item.project));
  document.getElementById("approvalList").innerHTML = visible.map(({ item, index }) => `<button class="approval-item" data-approval="${index}"><span class="approval-item-icon">◇</span><span><strong>${item.title}</strong><small>${item.id} · ${item.project}</small><small>Solicita ${item.requester}</small></span><time>${item.date}</time></button>`).join("") || `<div class="empty-state"><span>✓</span><h2>Sin solicitudes asignadas</h2><p>No hay aprobaciones pendientes dentro de tu alcance.</p></div>`;
  document.querySelectorAll("[data-approval]").forEach(button => button.addEventListener("click", () => showApproval(Number(button.dataset.approval))));
}

function showApproval(index) {
  const item = approvals[index];
  document.querySelectorAll("[data-approval]").forEach((button, i) => button.classList.toggle("active", i === index));
  document.getElementById("approvalDetail").innerHTML = `<div class="detail-heading"><span class="status pending">Pendiente de aprobación</span><h2>${item.title}</h2><p>Solicitud ${item.id} para ${item.project}</p></div><div class="detail-grid"><div class="detail-field"><small>Solicitante</small><strong>${item.requester}</strong></div><div class="detail-field"><small>Área</small><strong>${item.area}</strong></div><div class="detail-field"><small>Monto estimado</small><strong>${item.amount}</strong></div><div class="detail-field"><small>Fecha de solicitud</small><strong>${item.date}</strong></div></div><h3>Justificación</h3><p class="request-note">${item.reason}</p><div class="approval-actions"><button class="button secondary" data-decision="rechazada">Rechazar</button><button class="button primary" data-decision="aprobada">Aprobar solicitud</button></div>`;
  document.querySelectorAll("[data-decision]").forEach(button => button.addEventListener("click", () => {
    showToast(`Solicitud ${item.id} ${button.dataset.decision}`);
    document.querySelector(`[data-approval="${index}"]`).remove();
    document.getElementById("approvalDetail").innerHTML = `<div class="empty-state"><span>✓</span><h2>Decisión registrada</h2><p>La trazabilidad de la solicitud se conservará en el historial.</p></div>`;
  }));
}

const modalBackdrop = document.getElementById("modalBackdrop");
const modalContent = document.getElementById("modalContent");
const forms = {
  task: { title: "Crear nueva tarea", intro: "Registra una actividad y asigna un responsable.", fields: `<label>Título<input name="title" required placeholder="Ej. Validar informe final" /></label><label>Proyecto<select><option>Implementación ERP</option><option>Renovación de laboratorio</option><option>Campaña de admisión</option></select></label><div class="form-grid"><label>Responsable<select><option>Carlos Ruiz</option><option>Lucía Vega</option><option>Diego Torres</option></select></label><label>Fecha de entrega<input type="date" required /></label></div><label>Descripción<textarea placeholder="Resultado esperado y detalles relevantes"></textarea></label>`, submit: "Crear tarea" },
  material: { title: "Solicitar material", intro: "La solicitud será enviada al aprobador correspondiente.", fields: `<label>Proyecto<select><option>Renovación de laboratorio</option><option>Implementación ERP</option><option>Campaña de admisión</option></select></label><label>Material<input required placeholder="Buscar o escribir material" /></label><div class="form-grid"><label>Cantidad<input type="number" min="1" value="1" required /></label><label>Fecha requerida<input type="date" required /></label></div><label>Justificación<textarea required placeholder="Indica para qué se utilizará"></textarea></label>`, submit: "Enviar solicitud" },
  stock: { title: "Registrar material", intro: "Agrega un material al catálogo y registra su existencia inicial.", fields: `<label>Nombre del material<input required placeholder="Ej. Router Wi-Fi 6" /></label><div class="form-grid"><label>Categoría<select><option>Equipos</option><option>Instalación</option><option>Oficina</option><option>Mantenimiento</option></select></label><label>Unidad de medida<select><option>Unidad</option><option>Metro</option><option>Galón</option><option>Millar</option></select></label></div><div class="form-grid"><label>Cantidad inicial<input type="number" min="0" value="1" required /></label><label>Stock mínimo<input type="number" min="0" value="1" required /></label></div><label>Ubicación<input required placeholder="Ej. Almacén A-02" /></label><label>Documento o motivo de ingreso<input placeholder="Orden de compra, donación o ajuste" /></label>`, submit: "Registrar ingreso", success: "Material e ingreso registrados correctamente" },
  project: { title: "Crear proyecto", intro: "Define la información principal para iniciar la planificación.", fields: `<label>Nombre del proyecto<input required placeholder="Nombre claro y reconocible" /></label><div class="form-grid"><label>Área responsable<select><option>Tecnología</option><option>Infraestructura</option><option>Académica</option><option>Marketing</option></select></label><label>Fecha de entrega<input type="date" required /></label></div><label>Objetivo<textarea required placeholder="¿Qué resultado debe alcanzar el proyecto?"></textarea></label>`, submit: "Crear proyecto" },
  invite: { title: "Invitar integrante", intro: "La persona recibirá un correo para activar su cuenta.", fields: `<label>Correo institucional<input type="email" required placeholder="nombre@universidad.edu.pe" /></label><div class="form-grid"><label>Área<select><option>Tecnología</option><option>Infraestructura</option><option>Logística</option><option>Académica</option></select></label><label>Rol<select><option>Miembro</option><option>Jefe de área</option><option>Aprobador</option><option>Materiales</option></select></label></div>`, submit: "Enviar invitación" },
  access: { title: "Asignar acceso", intro: "Combina un rol con funciones y proyectos específicos.", fields: `<label>Usuario<select><option>Lucía Vega</option><option>Carlos Ruiz</option><option>José Pérez</option><option>Rosa Flores</option></select></label><label>Rol<select><option>Jefe de área</option><option>Jefe de proyecto</option><option>Aprobador</option><option>Miembro</option><option>Gestor de materiales</option><option>Auditor</option></select></label><label>Funciones habilitadas<div class="check-grid"><label class="check-option"><input type="checkbox" checked /> Proyectos</label><label class="check-option"><input type="checkbox" checked /> Tareas</label><label class="check-option"><input type="checkbox" /> Materiales</label><label class="check-option"><input type="checkbox" /> Aprobar</label><label class="check-option"><input type="checkbox" /> Reportes</label><label class="check-option"><input type="checkbox" /> Auditoría</label></div></label><label>Proyectos visibles<div class="check-grid"><label class="check-option"><input type="checkbox" checked /> Implementación ERP</label><label class="check-option"><input type="checkbox" /> Laboratorio</label><label class="check-option"><input type="checkbox" /> Biblioteca digital</label><label class="check-option"><input type="checkbox" /> Campaña</label></div></label>`, submit: "Guardar acceso", success: "Acceso actualizado correctamente" }
};

function openModal(type) {
  const config = forms[type];
  modalContent.innerHTML = `<h2 id="modalTitle">${config.title}</h2><p>${config.intro}</p><form id="dynamicForm">${config.fields}<div class="modal-actions"><button type="button" class="button secondary" id="cancelModal">Cancelar</button><button type="submit" class="button primary">${config.submit}</button></div></form>`;
  modalBackdrop.hidden = false;
  document.body.style.overflow = "hidden";
  document.getElementById("cancelModal").addEventListener("click", closeModal);
  if (["task", "material"].includes(type) && accessProfiles[activeAccessKey].projects !== "*") {
    const projectSelect = modalContent.querySelector("form select");
    projectSelect.innerHTML = accessProfiles[activeAccessKey].projects.map(project => `<option>${project}</option>`).join("");
  }
  document.getElementById("dynamicForm").addEventListener("submit", event => { event.preventDefault(); closeModal(); showToast(config.success || `${config.title.replace("Crear", "").replace("nueva", "").trim()} registrada correctamente`); });
  setTimeout(() => modalContent.querySelector("input, select, textarea")?.focus(), 50);
}

function closeModal() { modalBackdrop.hidden = true; document.body.style.overflow = ""; }
document.querySelectorAll("[data-action]").forEach(button => button.addEventListener("click", () => openModal(button.dataset.action)));
document.getElementById("modalClose").addEventListener("click", closeModal);
modalBackdrop.addEventListener("click", event => { if (event.target === modalBackdrop) closeModal(); });
document.addEventListener("keydown", event => { if (event.key === "Escape") closeModal(); if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") { event.preventDefault(); document.getElementById("globalSearch").focus(); } });

document.getElementById("globalSearch").addEventListener("input", event => {
  const value = event.target.value.trim().toLowerCase();
  document.querySelectorAll(".view.active [data-searchable]").forEach(item => item.classList.toggle("search-hidden", value && !item.dataset.searchable.toLowerCase().includes(value)));
});

document.querySelectorAll("[data-table-search]").forEach(input => input.addEventListener("input", event => {
  const value = event.target.value.toLowerCase();
  document.querySelectorAll(`#${input.dataset.tableSearch} tbody tr`).forEach(row => row.classList.toggle("is-hidden", !row.textContent.toLowerCase().includes(value)));
}));

function showMaterialTab(name) {
  document.querySelectorAll("[data-material-tab]").forEach(button => button.classList.toggle("active", button.dataset.materialTab === name));
  document.querySelectorAll(".material-tab-content").forEach(content => content.classList.toggle("active", content.id === `material-tab-${name}`));
}

document.querySelectorAll("[data-material-tab]").forEach(button => button.addEventListener("click", () => showMaterialTab(button.dataset.materialTab)));
document.querySelectorAll("[data-material-tab-link]").forEach(button => button.addEventListener("click", () => showMaterialTab(button.dataset.materialTabLink)));

function showMaterialRequest(id) {
  const request = materialRequests[id];
  document.querySelectorAll("[data-material-request]").forEach(button => button.closest("tr").classList.toggle("selected-row", button.dataset.materialRequest === id));
  document.getElementById("materialRequestTrace").innerHTML = `<div class="trace-head"><span class="status ${request.status === "Cerrada" ? "success" : request.status === "Pendiente" ? "pending" : "progress"}">${request.status}</span><h2>${request.title}</h2><p>${id} · ${request.project}</p></div><div class="trace-summary"><div><small>Solicitante</small><strong>${request.requester}</strong></div><div><small>Fecha requerida</small><strong>${request.needed}</strong></div><div><small>Aprobador</small><strong>${request.approver}</strong></div><div><small>Proyecto</small><strong>${request.project}</strong></div></div><ol class="trace-timeline">${request.steps.map(step => `<li class="${step[2]}"><strong>${step[0]}</strong><small>${step[1]}</small></li>`).join("")}</ol>`;
}

document.querySelectorAll("[data-material-request]").forEach(button => button.addEventListener("click", () => showMaterialRequest(button.dataset.materialRequest)));
document.getElementById("materialStatusFilter").addEventListener("change", event => {
  const value = event.target.value;
  document.querySelectorAll("#requestsTable tbody tr").forEach(row => row.classList.toggle("filter-hidden", value !== "all" && row.dataset.requestStatus !== value));
});

document.getElementById("taskProjectFilter").addEventListener("change", event => renderKanban(event.target.value));
function applyProjectCardVisibility() {
  const profile = accessProfiles[activeAccessKey];
  document.querySelectorAll(".project-card").forEach(card => {
    const withinScope = profile.projects === "*" || profile.projects.includes(card.dataset.projectName);
    const matchesStatus = currentProjectStatusFilter === "Todos" || card.dataset.status === currentProjectStatusFilter;
    card.classList.toggle("access-hidden", !withinScope);
    card.classList.toggle("filter-hidden", !matchesStatus);
  });
}

function applyAccessProfile(key) {
  activeAccessKey = key;
  const profile = accessProfiles[key];
  document.getElementById("profileAvatar").textContent = profile.initials;
  document.getElementById("profileName").textContent = profile.name;
  document.getElementById("profileRole").textContent = profile.role;
  document.getElementById("accessPreviewBar").hidden = key === "admin";
  document.getElementById("previewUserName").textContent = profile.name;
  viewButtons.forEach(button => button.classList.toggle("access-hidden", !profile.modules.includes(button.dataset.view)));
  document.querySelectorAll("[data-action]").forEach(button => button.classList.toggle("access-hidden", !profile.actions.includes(button.dataset.action)));
  document.querySelectorAll("[data-project-name]:not(.project-card)").forEach(item => item.classList.toggle("access-hidden", profile.projects !== "*" && !profile.projects.includes(item.dataset.projectName)));
  renderProjects();
  renderKanban(document.getElementById("taskProjectFilter").value);
  renderApprovals();
  const currentView = document.querySelector(".view.active").id.replace("view-", "");
  if (!profile.modules.includes(currentView)) showView("overview");
}

document.querySelectorAll("[data-project-filter]").forEach(button => button.addEventListener("click", () => {
  document.querySelectorAll("[data-project-filter]").forEach(item => item.classList.remove("active"));
  button.classList.add("active");
  currentProjectStatusFilter = button.dataset.projectFilter;
  applyProjectCardVisibility();
}));
document.getElementById("exportButton").addEventListener("click", () => showToast("Reporte preparado para exportación"));
document.getElementById("startAccessPreview").addEventListener("click", () => {
  const key = document.getElementById("accessUserSelect").value;
  applyAccessProfile(key);
  showView("overview");
  showToast(`Vista limitada a los permisos de ${accessProfiles[key].name}`);
});
document.getElementById("exitPreview").addEventListener("click", () => {
  applyAccessProfile("admin");
  showView("permissions");
  showToast("Vista de administrador restaurada");
});
document.querySelectorAll(".role-item").forEach(button => button.addEventListener("click", () => {
  document.querySelectorAll(".role-item").forEach(item => item.classList.remove("active"));
  button.classList.add("active");
}));

renderProjects();
renderKanban();
renderApprovals();
