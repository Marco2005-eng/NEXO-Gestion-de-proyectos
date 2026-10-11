import type { CSSProperties } from 'react';
const paths: Record<string, string> = {
  appearance: 'M12 3a9 9 0 1 0 9 9c0-1-1-2-2-2h-2c-1 0-2-1-2-2s0-2-1-3l-2-2ZM7 8h.01M6 13h.01M10 17h.01',
  sun: 'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8M12 2v2M12 20v2M2 12h2M20 12h2M5 5l1 1M18 18l1 1M5 19l1-1M18 6l1-1',
  moon: 'M21 13a9 9 0 1 1-10-10 7 7 0 0 0 10 10',
  screen: 'M3 4h18v13H3V4ZM8 21h8M12 17v4',
  home: 'M3 10 12 3l9 7v10H3V10ZM9 20v-7h6v7',
  projects: 'M3 7h7l2 2h9v11H3V7ZM3 7V4h7l2 3',
  tasks: 'M9 5h12M9 12h12M9 19h12M3 5l1 1 2-2M3 12l1 1 2-2M3 19l1 1 2-2',
  materials: 'm3 7 9-4 9 4-9 4-9-4Zm0 0v10l9 4 9-4V7M12 11v10',
  requests: 'M6 3h12v18H6V3ZM9 7h6M9 11h6M9 15h4',
  approvals: 'm12 3 9 4v6c0 4-9 8-9 8s-9-4-9-8V7l9-4ZM8 12l3 3 5-6',
  documents: 'M5 3h9l5 5v13H5V3ZM14 3v6h5M8 13h8M8 17h6',
  diagrams: 'M9 3h6v5H9V3ZM2 16h6v5H2v-5Zm14 0h6v5h-6v-5ZM12 8v4M5 16v-4h14v4',
  reports: 'M4 20V10h4v10M10 20V4h4v16M16 20V7h4v13',
  administration: 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8M17 4a4 4 0 0 1 0 8M22 21v-2a4 4 0 0 0-3-4',
  search: 'M21 21l-6-6M17 10a7 7 0 1 0-14 0 7 7 0 0 0 14 0',
  plus: 'M12 5v14M5 12h14', menu: 'M4 6h16M4 12h16M4 18h16', close: 'm6 6 12 12M6 18 18 6',
  arrow: 'M5 12h14m-5-5 5 5-5 5', bell: 'M5 17h14l-2-3V9a5 5 0 0 0-10 0v5l-2 3ZM10 21h4',
  calendar: 'M4 5h16v16H4V5ZM8 3v4M16 3v4M4 10h16', check: 'm5 12 4 4 10-10',
  download: 'M12 3v12m-5-5 5 5 5-5M4 16v5h16v-5', grid: 'M3 3h7v7H3V3Zm11 0h7v7h-7V3ZM3 14h7v7H3v-7Zm11 0h7v7h-7v-7',
  list: 'M8 6h13M8 12h13M8 18h13M3 6h1M3 12h1M3 18h1', logout: 'M9 3H3v18h6M8 12h13m-5-5 5 5-5 5',
};
export function Icon({ name, size = 20, style }: { name: string; size?: number; style?: CSSProperties }) {
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" style={style}><path d={paths[name] ?? paths.projects} /></svg>;
}
