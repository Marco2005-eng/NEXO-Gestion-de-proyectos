export function availableStock(onHand: number, reserved: number): number {
  if (!Number.isFinite(onHand) || !Number.isFinite(reserved) || onHand < 0 || reserved < 0 || reserved > onHand) throw new Error('Saldo de inventario inválido.');
  return onHand - reserved;
}
export function validateReservation(quantity: number, onHand: number, reserved: number): void {
  if (!Number.isFinite(quantity) || quantity <= 0) throw new Error('La cantidad debe ser positiva.');
  if (quantity > availableStock(onHand, reserved)) throw new Error('Stock disponible insuficiente.');
}
