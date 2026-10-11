export type Appearance = {
  theme: 'light' | 'dark' | 'system';
  fontSize: 'small' | 'normal' | 'large' | 'extra';
  density: 'comfortable' | 'compact';
  accent: 'blue' | 'teal' | 'violet';
  reducedMotion: boolean;
};
export const storageKey = 'nexo.appearance.v1';
export const defaults: Appearance = { theme: 'system', fontSize: 'normal', density: 'comfortable', accent: 'blue', reducedMotion: false };
export function parseAppearance(value: unknown): Appearance {
  if (!value || typeof value !== 'object') return {...defaults};
  const input = value as Record<string,unknown>;
  return {
    theme: ['light','dark','system'].includes(String(input.theme)) ? input.theme as Appearance['theme'] : defaults.theme,
    fontSize: ['small','normal','large','extra'].includes(String(input.fontSize)) ? input.fontSize as Appearance['fontSize'] : defaults.fontSize,
    density: input.density === 'compact' ? 'compact' : 'comfortable',
    accent: ['blue','teal','violet'].includes(String(input.accent)) ? input.accent as Appearance['accent'] : defaults.accent,
    reducedMotion: input.reducedMotion === true,
  };
}
export function applyAppearance(value: Appearance) {
  const root=document.documentElement;
  const theme=value.theme==='system' ? (window.matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light') : value.theme;
  root.dataset.theme=theme;
  root.dataset.fontSize=value.fontSize;
  root.dataset.density=value.density;
  root.dataset.accent=value.accent;
  root.dataset.reducedMotion=String(value.reducedMotion);
  root.style.colorScheme=theme;
}
// Solo valores enumerados se aplican al DOM; no contiene datos ni código externos.
export const bootstrapAppearance = `(()=>{try{const p=JSON.parse(localStorage.getItem('${storageKey}')||'{}'),r=document.documentElement;const t=['light','dark','system'].includes(p.theme)?p.theme:'system';r.dataset.theme=t==='system'?(matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light'):t;r.dataset.fontSize=['small','normal','large','extra'].includes(p.fontSize)?p.fontSize:'normal';r.dataset.density=p.density==='compact'?'compact':'comfortable';r.dataset.accent=['blue','teal','violet'].includes(p.accent)?p.accent:'blue';r.dataset.reducedMotion=String(p.reducedMotion===true);r.style.colorScheme=r.dataset.theme}catch{document.documentElement.dataset.theme=matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light'}})();`;
