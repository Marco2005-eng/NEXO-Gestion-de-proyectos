'use client';

import { hasGrant, type WorkspaceData } from '@/features/workspace/domain/types';
import { Icon } from '@/components/shared/icon';

/** UI reservada: el envío debe habilitarse únicamente con un servicio autorizado en el servidor. */
export function EmailInvitations({data,organizationId}:{data:WorkspaceData;organizationId:string}) {
  const projects=data.projects.filter(p=>p.organization_id===organizationId&&hasGrant(data.grants,'project.manage',organizationId,String(p.id),p.area_id as string|null));
  return <div className="email-invitations">
    <div className="invitation-heading"><div><span className="eyebrow">ACCESO AL EQUIPO</span><h2>Invitaciones por correo</h2><p className="muted">Invita a colaboradores a unirse a tu organización y a sus proyectos.</p></div><span className="invitation-pending">Próximamente</span></div>
    <div className="notice" role="status"><strong>Envío todavía no habilitado</strong><p>Esta función estará disponible cuando configuremos el dominio y el servicio de correo. Por ahora puedes utilizar «Registrar usuario».</p></div>
    <div className="invitation-layout">
      <section className="panel invitation-card" aria-labelledby="invitation-form-title"><h3 id="invitation-form-title">Nueva invitación</h3><p className="muted">El destinatario podrá aceptar la invitación y configurar su acceso.</p>
        <fieldset disabled className="invitation-fields"><legend className="sr-only">Invitación no disponible todavía</legend><div className="form-grid">
          <label className="full">Correo del colaborador *<input type="email" placeholder="colaborador@empresa.com" autoComplete="off"/></label>
          <label className="full">Nombre del colaborador (opcional)<input placeholder="Nombre completo" maxLength={150}/></label>
          <label className="full">Proyecto *<select defaultValue=""><option value="">Seleccionar proyecto</option>{projects.map(p=><option key={String(p.id)} value={String(p.id)}>{p.name}</option>)}</select></label>
          <label className="full">Rol en el proyecto *<select defaultValue="member"><option value="member">Colaborador</option></select><span className="form-help">Al habilitar el envío, se mostrarán los roles que tengas permiso para asignar en el proyecto elegido.</span></label>
          <label className="full">Mensaje (opcional)<textarea rows={3} placeholder="Te invitamos a colaborar en nuestro proyecto…" maxLength={1000}/></label>
        </div></fieldset>
        <div className="invitation-send"><button type="button" disabled className="button primary" aria-describedby="invitation-disabled-reason"><Icon name="arrow" size={17}/>Enviar invitación</button><p id="invitation-disabled-reason" className="form-help">Pendiente de configuración del correo. No se guardan ni envían invitaciones.</p></div>
      </section>
      <aside className="panel invitation-card"><h3>Así se incorporará al equipo</h3><ol className="invitation-steps"><li><strong>Envías la invitación</strong><p>Seleccionas el correo, el proyecto y el rol autorizado.</p></li><li><strong>El colaborador acepta</strong><p>Recibe un enlace temporal para crear su contraseña o ingresar con su cuenta.</p></li><li><strong>Comienza a trabajar</strong><p>Accede al proyecto y a las funciones correspondientes a su rol.</p></li></ol><div className="invitation-history"><Icon name="administration"/><h3>Seguimiento de invitaciones</h3><p className="muted">Cuando se active, aquí podrás consultar las invitaciones pendientes, aceptadas o vencidas.</p><span className="invitation-pending">Aún no disponible</span></div></aside>
    </div>
  </div>;
}
