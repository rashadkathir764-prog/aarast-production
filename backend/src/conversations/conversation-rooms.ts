/**
 * Single source of truth for Socket.IO room names.
 *
 * The gateway joins these rooms and the realtime publisher broadcasts to them
 * from a different module. Hardcoding the format in both places means a change
 * on one side silently stops delivering to the other, so both import from here.
 */
export function conversationRoom(conversationId: string): string {
  return `conversation:${conversationId}`;
}

export function userRoom(userId: string): string {
  return `user:${userId}`;
}
