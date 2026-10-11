import 'server-only';
import { createClient } from '@supabase/supabase-js';
import { getSupabaseConfig } from './config';
export function createAdminClient() {
  const config = getSupabaseConfig();
  const secret = process.env.SUPABASE_SECRET_KEY;
  if (!config || !secret) throw new Error('Configura SUPABASE_SECRET_KEY en .env.local y reinicia Nexo para registrar cuentas.');
  return createClient(config.url, secret, { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } });
}
