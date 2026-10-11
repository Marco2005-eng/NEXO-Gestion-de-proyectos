'use client';
import { useEffect, useRef } from 'react';
import { Icon } from '@/components/shared/icon';
export function Dialog({ title, children, onClose, wide = false }: { title: string; children: React.ReactNode; onClose: () => void; wide?: boolean }) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => { const element = ref.current; element?.showModal(); return () => element?.close(); }, []);
  return <dialog className={'dialog '+(wide?'dialog-wide':'')} ref={ref} onCancel={e => {e.preventDefault();onClose();}} onClick={e => { if (e.target === e.currentTarget) { const r = e.currentTarget.getBoundingClientRect(); if (e.clientX < r.left || e.clientX > r.right || e.clientY < r.top || e.clientY > r.bottom) onClose(); } }}><div className="dialog-head"><div><span className="eyebrow">Nexo / espacio de trabajo</span><h2>{title}</h2></div><button className="icon-button" type="button" onClick={onClose} aria-label="Cerrar ventana"><Icon name="close"/></button></div>{children}</dialog>;
}
