'use client';
export default function ErrorPage({ reset }: { reset: () => void }) {
  return <div className="card" role="alert"><h2>No pudimos cargar los registros</h2><p>Revisa la conexión, las migraciones y los permisos de tu cuenta.</p><button onClick={reset}>Reintentar</button></div>;
}
