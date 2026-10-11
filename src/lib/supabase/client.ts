'use client';
import { createBrowserClient } from '@supabase/ssr';
import { getSupabaseConfig } from './config';
export function createClient() {
  const config = getSupabaseConfig();
  if (!config) throw new Error('Configura las variables de Supabase.');
  return createBrowserClient(config.url, config.key);
}
