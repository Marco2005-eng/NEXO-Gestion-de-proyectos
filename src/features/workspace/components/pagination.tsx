'use client';
import {useState} from 'react';
import type {Row} from '../domain/types';
export function Pagination({total,page,pageSize,onPage,onPageSize}:{total:number;page:number;pageSize:number;onPage:(page:number)=>void;onPageSize:(size:number)=>void}){
 const pages=Math.max(1,Math.ceil(total/pageSize));
 return <nav className="records-pagination" aria-label="Paginación de materiales"><span className="pagination-count" aria-live="polite">{total?`${(page-1)*pageSize+1}–${Math.min(page*pageSize,total)} de ${total} registros`:'0 registros'}</span><label>Por página<select aria-label="Registros por página" value={pageSize} onChange={e=>onPageSize(Number(e.target.value))}>{[10,15,20].map(n=><option key={n} value={n}>{n}</option>)}</select></label><div className="pagination-navigation"><button type="button" className="button secondary small" disabled={page<=1} onClick={()=>onPage(page-1)}>Anterior</button><span>Página <strong>{page}</strong> de {pages}</span><button type="button" className="button secondary small" disabled={page>=pages} onClick={()=>onPage(page+1)}>Siguiente</button></div></nav>;
}
export function CatalogWithoutStock({materials}:{materials:Row[]}){
 const [pageSize,setPageSize]=useState(10);const [requestedPage,setPage]=useState(1);const page=Math.min(requestedPage,Math.max(1,Math.ceil(materials.length/pageSize)));
 if(!materials.length)return null;
 return <section className="panel catalog-note"><h3>Catálogo sin existencias</h3><p className="muted">Estos materiales están registrados y aún no tienen saldo en un almacén.</p><div className="tag-list">{materials.slice((page-1)*pageSize,page*pageSize).map(m=><span className="tag" key={String(m.id)}>{m.name}</span>)}</div><Pagination total={materials.length} page={page} pageSize={pageSize} onPage={setPage} onPageSize={size=>{setPageSize(size);setPage(1);}}/></section>;
}
