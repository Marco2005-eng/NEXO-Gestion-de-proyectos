import { signIn } from '@/features/auth/application/actions';
import { getSupabaseConfig } from '@/lib/supabase/config';
export default async function Login({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const params = await searchParams;
  return <main className="login card"><span className="eyebrow">Nexo</span><h2>Bienvenido</h2><p className="muted">Ingresa con tu cuenta de la organización.</p>{params.error && <p role="alert">No pudimos iniciar sesión. Revisa tus credenciales.</p>}{getSupabaseConfig() ? <form action={signIn}><label>Correo<input type="email" name="email" autoComplete="email" required /></label><label>Contraseña<input type="password" name="password" autoComplete="current-password" required /></label><button>Iniciar sesión</button></form> : <div className="notice">Configura .env.local para habilitar el acceso.</div>}</main>;
}
