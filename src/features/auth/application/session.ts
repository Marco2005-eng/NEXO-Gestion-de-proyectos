import 'server-only';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
export async function requireUser() {
  const client = await createClient();
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) redirect('/iniciar-sesion');
  return { client, user: data.user };
}
