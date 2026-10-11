import 'server-only';
import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { getSupabaseConfig } from './config';
export async function createClient() {
  const config = getSupabaseConfig();
  if (!config) throw new Error('Configura las variables de Supabase.');
  const store = await cookies();
  return createServerClient(config.url, config.key, {
    cookies: {
      getAll: () => store.getAll(),
      setAll: (entries) => {
        try { entries.forEach(({ name, value, options }) => store.set(name, value, options)); }
        catch { /* Los Server Components no escriben cookies; proxy renueva la sesión. */ }
      },
    },
  });
}
