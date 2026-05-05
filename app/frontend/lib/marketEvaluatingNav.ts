/** Prevents duplicate Inertia navigations when ActionCable + polling both fire. */

const locks = new Set<string>()

export function releaseMarketEvaluatingNavLock(eventId: string): void {
  locks.delete(eventId.trim())
}

export function tryNavigateToMarketOnce(eventId: string, navigate: () => void): void {
  const k = eventId.trim()
  if (locks.has(k)) return
  locks.add(k)
  navigate()
}
