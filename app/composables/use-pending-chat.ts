/**
 * Shared state for passing pending chat messages from the background
 * to the chat container via Nuxt useState (global reactive state).
 */

export interface PendingChatMessage {
  text: string;
}

export function usePendingChat() {
  const pendingChat = useState<PendingChatMessage | null>(
    "pending-chat",
    () => null,
  );

  function setPendingChat(data: PendingChatMessage) {
    pendingChat.value = data;
  }

  function consumePendingChat(): PendingChatMessage | null {
    const data = pendingChat.value;
    if (data) {
      pendingChat.value = null;
    }
    return data;
  }

  return {
    pendingChat: readonly(pendingChat),
    setPendingChat,
    consumePendingChat,
  };
}
