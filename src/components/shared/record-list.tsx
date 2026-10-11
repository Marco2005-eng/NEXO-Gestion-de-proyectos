export type RecordRow = Record<string, string | number | null>;
export function RecordList({ rows, columns }: { rows: RecordRow[]; columns: { key: string; label: string }[] }) {
  if (!rows.length) return <div className="card"><h3>No hay registros visibles</h3><p className="muted">Los registros dependen de los permisos y proyectos de tu cuenta.</p></div>;
  return <div className="table-wrap"><table><thead><tr>{columns.map(c => <th key={c.key}>{c.label}</th>)}</tr></thead><tbody>{rows.map((row, index) => <tr key={String(row.id ?? row.request_id ?? row.project_id ?? index)}>{columns.map(c => <td key={c.key}>{String(row[c.key] ?? '—')}</td>)}</tr>)}</tbody></table></div>;
}
