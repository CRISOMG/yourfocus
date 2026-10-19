/**
 * @deprecated Este endpoint usa el formato n8n/LangChain (type: "human"/"ai")
 * que NO soporta parts multimodales (source-url, file, reasoning).
 * Ver: docs/features/chat-persistence-migration.md para plan de migración a AI SDK v6.
 */
import type { UIMessage } from "ai";
import { serverSupabaseUser } from "#supabase/server";
interface N8NMessageLangChain {
  type: "human" | "ai" | "system" | string;
  content: string;
  tool_calls?: any[];
  additional_kwargs?: Record<string, any>;
  response_metadata?: Record<string, any>;
  invalid_tool_calls?: any[];
  // Soporte para variaciones de LangChain donde el contenido está dentro de 'data'
  data?: {
    content: string;
    [key: string]: any;
  };
}

interface N8NChatHistoryRow {
  id: number;
  session_id: string;
  message: string | N8NMessageLangChain; // Puede venir como string JSON o ya parseado
}

export default defineEventHandler(async (event) => {
  const user = await serverSupabaseUser(event);

  if (!user) {
    throw createError({
      statusCode: 401,
      statusMessage: "Unauthorized",
    });
  }

  const userId = (user as any).id || (user as any).sub;

  const rows = await sql<N8NChatHistoryRow[]>`
    SELECT * FROM (
      SELECT id, session_id, message
      FROM n8n_chat_histories
      WHERE session_id = ${userId}
      ORDER BY id DESC
      LIMIT 40
    ) AS subquery
    ORDER BY id ASC
  `;

  // 3. Mapear mensajes de LangChain (n8n) a Vercel AI SDK
  const mappedMessages = rows.map((row) => {
    // Si la DB devuelve un string, lo parseamos
    const msg: N8NMessageLangChain =
      typeof row.message === "string" ? JSON.parse(row.message) : row.message;

    // Determinamos el rol compatible con Vercel AI SDK
    let role: UIMessage["role"] = "system";
    if (msg.type === "human") role = "user";
    else if (msg.type === "ai") role = "assistant";

    // Extraemos el contenido dinámicamente
    const textContent = msg.content || msg.data?.content || "";

    // Extraemos parts preservados (source-url, file, text, etc.)
    const rawParts = msg.additional_kwargs?.parts || (msg as any).parts;
    const parts =
      Array.isArray(rawParts) && rawParts.length > 0
        ? rawParts
        : [{ type: "text", text: textContent }];

    const replyToId =
      msg.additional_kwargs?.reply_to_id || (msg as any).reply_to_id;
    const createdAtStr =
      msg.additional_kwargs?.created_at || (msg as any).created_at;
    const createdAt = createdAtStr ? new Date(createdAtStr) : new Date();

    return {
      id: row.id.toString(),
      role,
      content: textContent,
      parts,
      createdAt,
      replyToId: replyToId ? String(replyToId) : undefined,
    } as UIMessage & { replyToId?: string };
  });

  // 4. Reordenamiento topológico: si una respuesta del asistente tiene replyToId,
  // se intercala inmediatamente debajo de ese mensaje sin romper la línea de tiempo.
  const reorderedMessages: (UIMessage & { replyToId?: string })[] = [];
  const pendingReplies: (UIMessage & { replyToId?: string })[] = [];

  for (const m of mappedMessages) {
    if (m.role === "assistant" && m.replyToId) {
      pendingReplies.push(m);
    } else {
      reorderedMessages.push(m);
    }
  }

  for (const reply of pendingReplies) {
    const parentIdx = reorderedMessages.findIndex((m) => m.id === reply.replyToId);
    if (parentIdx !== -1) {
      let insertIdx = parentIdx + 1;
      while (
        insertIdx < reorderedMessages.length &&
        reorderedMessages[insertIdx].role === "assistant" &&
        reorderedMessages[insertIdx].replyToId === reply.replyToId
      ) {
        insertIdx++;
      }
      reorderedMessages.splice(insertIdx, 0, reply);
    } else {
      reorderedMessages.push(reply);
    }
  }

  // 5. Retornar el objeto Chat completo que espera el template
  return {
    id: userId,
    messages: reorderedMessages,
  };
});
