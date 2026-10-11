export const transitions = {
  draft: ['pending', 'cancelled'], pending: ['approved', 'rejected', 'needs_changes', 'cancelled'],
  needs_changes: ['pending', 'cancelled'], approved: ['reserved', 'cancelled'],
  reserved: ['partially_delivered', 'delivered', 'cancelled'], partially_delivered: ['delivered', 'cancelled'],
  delivered: ['usage_reported', 'returned'], usage_reported: ['closed'], returned: ['closed'],
  closed: [], rejected: [], cancelled: [],
} as const;
export type RequestStatus = keyof typeof transitions;
export function validateTransition(context: { from: RequestStatus; to: RequestStatus; actorMemberId: string; requesterMemberId: string; comment?: string }): void {
  const allowed: readonly string[] = transitions[context.from];
  if (!allowed.includes(context.to)) throw new Error('Transición de estado no permitida.');
  if (['approved', 'rejected', 'needs_changes'].includes(context.to) && context.actorMemberId === context.requesterMemberId) throw new Error('El solicitante no puede decidir su propia solicitud.');
  if (['rejected', 'needs_changes', 'cancelled'].includes(context.to) && !context.comment?.trim()) throw new Error('Esta decisión requiere un comentario.');
}
