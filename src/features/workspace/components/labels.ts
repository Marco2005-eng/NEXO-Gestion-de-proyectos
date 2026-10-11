export const labels: Record<string,string> = {
 draft:'Borrador',planning:'Planificación',active:'En curso',on_hold:'Pausado',completed:'Completado',cancelled:'Cancelado',
 pending:'Pendiente',in_progress:'En progreso',in_review:'En revisión',blocked:'Bloqueado',needs_changes:'Por corregir',approved:'Aprobado',reserved:'Reservado',partially_delivered:'Entrega parcial',delivered:'Entregado',usage_reported:'Uso reportado',returned:'Devuelto',closed:'Cerrado',rejected:'Rechazado',
 low:'Baja',medium:'Media',high:'Alta',critical:'Crítica',consumable:'Consumible',returnable:'Equipo prestable',service:'Servicio',license:'Licencia',
 available:'Disponible',low_stock:'Stock bajo',out_of_stock:'Sin stock',invited:'Invitado',suspended:'Suspendido',inactive:'Inactivo',
};
export function label(value: unknown) { return labels[String(value)] ?? String(value ?? '—'); }
export function date(value: unknown) { if (!value) return 'Sin fecha'; const input = String(value); const d = new Date(input.length===10?input+'T12:00:00':input); return Number.isNaN(d.getTime())?'Sin fecha':d.toLocaleDateString('es-PE',{day:'2-digit',month:'short',year:'numeric',timeZone:'America/Lima'}); }
export function money(value: unknown) { return new Intl.NumberFormat('es-PE',{style:'currency',currency:'PEN'}).format(Number(value ?? 0)); }
