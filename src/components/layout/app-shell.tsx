'use client';
import { useState } from 'react';
import Link from 'next/link';
import { usePathname, useSearchParams } from 'next/navigation';
import { modules } from '@/features/shared/module-catalog';
import { signOut } from '@/features/auth/application/actions';
import { Icon } from '@/components/shared/icon';
import { AppearanceSettings } from '@/features/appearance/appearance-settings';
import {useWorkspaceSelection} from '@/features/workspace/components/selection-provider';
import {canOpenModule} from '@/features/workspace/domain/module-access';
import type {Grant} from '@/features/workspace/domain/types';
const icons:Record<string,string>={proyectos:'projects',tareas:'tasks',materiales:'materials',solicitudes:'requests',aprobaciones:'approvals',documentos:'documents',diagramas:'diagrams',reportes:'reports',administracion:'administration'};
const navigationGroups=[{title:'Trabajo',slugs:['proyectos','tareas']},{title:'Recursos',slugs:['materiales','solicitudes','aprobaciones']},{title:'Documentación y análisis',slugs:['documentos','diagramas','reportes']},{title:'Administración',slugs:['administracion']}];
export function AppShell({ children, connected, grants=[], platformAdmin=false }: { children: React.ReactNode; connected: boolean; grants?:Grant[];platformAdmin?:boolean }) {
  const [open, setOpen] = useState(false); const path = usePathname(); const params = useSearchParams();
  const {organizationId}=useWorkspaceSelection();
  const preview = path === '/vista-previa';
  const currentPath = preview ? '/'+(params.get('modulo')??'') : path;
  const href = (slug: string) => preview ? '/vista-previa'+(slug?'?modulo='+slug:'') : '/'+slug;
  return <div className="shell"><button className="mobile-menu icon-button" aria-label="Abrir menú" aria-expanded={open} onClick={() => setOpen(true)}><Icon name="menu" /></button>{open && <button className="sidebar-shade" aria-label="Cerrar menú" onClick={() => setOpen(false)} />}
    <aside className={'sidebar sidebar-organized '+(open?'is-open':'')}><div className="sidebar-header"><Link href={href('')} className="brand" onClick={()=>setOpen(false)}><span className="brand-mark">n</span><span>Nexo<span className="brand-dot">.</span></span></Link><div className="workspace-label"><Icon name="projects" size={15}/>Espacio de trabajo</div></div>
    <nav className="sidebar-navigation" aria-label="Navegación principal"><div className="sidebar-nav-group"><span className="nav-caption">Trabajo</span><Link className={currentPath==='/'?'active':''} aria-current={currentPath==='/'?'page':undefined} href={href('')} onClick={()=>setOpen(false)}><Icon name="home" size={18}/>Resumen</Link>{navigationGroups[0].slugs.map(slug=>{const item=modules.find(m=>m.slug===slug);return item&&(preview||canOpenModule(grants,slug,organizationId))?<Link key={slug} className={currentPath==='/'+slug?'active':''} aria-current={currentPath==='/'+slug?'page':undefined} href={href(slug)} onClick={()=>setOpen(false)}><Icon name={icons[slug]} size={18}/>{item.title}</Link>:null;})}</div>
    {navigationGroups.slice(1).map(group=>{const available=group.slugs.filter(slug=>preview||canOpenModule(grants,slug,organizationId));const showPlatform=group.title==='Administración'&&platformAdmin;if(!available.length&&!showPlatform)return null;return <div className="sidebar-nav-group" key={group.title}><span className="nav-caption">{group.title}</span>{available.map(slug=><Link key={slug} className={currentPath==='/'+slug?'active':''} aria-current={currentPath==='/'+slug?'page':undefined} href={href(slug)} onClick={()=>setOpen(false)}><Icon name={icons[slug]} size={18}/>{modules.find(m=>m.slug===slug)?.title}</Link>)}{showPlatform&&<Link href="/sistema" className={path==='/sistema'?'active':''} aria-current={path==='/sistema'?'page':undefined} onClick={()=>setOpen(false)}><Icon name="administration" size={18}/>Administrar Nexo</Link>}</div>;})}</nav>
    <div className="sidebar-bottom"><span className="nav-caption">Mi cuenta</span>{connected&&<Link className={'sidebar-account-link '+(path==='/perfil'?'active':'')} aria-current={path==='/perfil'?'page':undefined} href="/perfil" onClick={()=>setOpen(false)}><Icon name="administration" size={18}/><span>Mi perfil</span></Link>}<AppearanceSettings/>{connected&&<form action={signOut}><button className="logout-button"><Icon name="logout" size={18}/><span>Cerrar sesión</span></button></form>}<div className={'sidebar-connection '+(connected?'connected':'preview')}><span className="sidebar-connection-dot"/><div><strong>{connected?'Conectado':'Vista de prueba'}</strong><small>{connected?'Datos de tu organización':'Datos ilustrativos'}</small></div></div><span className="sidebar-version">NEXO · GESTIÓN EMPRESARIAL</span></div></aside><main className="main-content">{children}</main></div>;
}

