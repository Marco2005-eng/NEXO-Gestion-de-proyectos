'use client';
import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import { applyAppearance, defaults, parseAppearance, storageKey, type Appearance } from './preferences';
const Context=createContext<{appearance:Appearance;update:(patch:Partial<Appearance>)=>void;reset:()=>void;stored:boolean}|null>(null);
export function AppearanceProvider({children}:{children:ReactNode}){
  const [appearance,setAppearance]=useState<Appearance>(defaults);
  const [stored,setStored]=useState(true);
  const [initialized,setInitialized]=useState(false);
  useEffect(()=>{
    try{const parsed=parseAppearance(JSON.parse(localStorage.getItem(storageKey)??'null'));setAppearance(parsed);applyAppearance(parsed);}catch{applyAppearance(defaults);}
    setInitialized(true);
    const onStorage=(event:StorageEvent)=>{if(event.key===storageKey){try{const parsed=parseAppearance(JSON.parse(event.newValue??'null'));setAppearance(parsed);applyAppearance(parsed);}catch{/* Conserva las preferencias válidas. */}}};
    window.addEventListener('storage',onStorage);
    return()=>window.removeEventListener('storage',onStorage);
  },[]);
  useEffect(()=>{
    if(!initialized)return;
    applyAppearance(appearance);
    const media=window.matchMedia('(prefers-color-scheme: dark)');
    const onChange=()=>{if(appearance.theme==='system')applyAppearance(appearance);};
    media.addEventListener('change',onChange);return()=>media.removeEventListener('change',onChange);
  },[appearance,initialized]);
  function update(patch:Partial<Appearance>){const value=parseAppearance({...appearance,...patch});setAppearance(value);applyAppearance(value);try{localStorage.setItem(storageKey,JSON.stringify(value));setStored(true);}catch{setStored(false);}}
  return <Context.Provider value={{appearance,update,reset:()=>update(defaults),stored}}>{children}</Context.Provider>;
}
export function useAppearance(){const value=useContext(Context);if(!value)throw new Error('Falta el proveedor de apariencia.');return value;}
