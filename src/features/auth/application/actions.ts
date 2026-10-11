'use server';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
export async function signIn(form: FormData) {
  const email = String(form.get('email') ?? '').trim();
  const password = String(form.get('password') ?? '');
  if (!email || !password) redirect('/iniciar-sesion?error=credentials');
  const client = await createClient();
  const { error } = await client.auth.signInWithPassword({ email, password });
  if (error) redirect('/iniciar-sesion?error=credentials');
  redirect('/');
}
export async function signOut() {
  const client = await createClient();
  await client.auth.signOut();
  redirect('/iniciar-sesion');
}
