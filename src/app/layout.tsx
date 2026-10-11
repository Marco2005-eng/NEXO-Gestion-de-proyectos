import type { Metadata } from 'next';
import './globals.css';
import './appearance.css';
import './calendar.css';
import './organizations.css';
import { AppearanceProvider } from '@/features/appearance/appearance-provider';
import { bootstrapAppearance } from '@/features/appearance/preferences';
export const metadata: Metadata = { title: 'Nexo | Gestión de proyectos', description: 'Proyectos, tareas y materiales en un solo lugar.' };
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="es" suppressHydrationWarning><head><script dangerouslySetInnerHTML={{__html:bootstrapAppearance}} /></head><body><AppearanceProvider>{children}</AppearanceProvider></body></html>;
}
