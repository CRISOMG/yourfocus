import { serverSupabaseUser } from "#supabase/server";

interface JournalBody {
  content?: string;
  parts?: any[];
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
  const body = await readBody<JournalBody>(event).catch(() => null);

  const parts = body?.parts || [];
  let content = body?.content || "";

  if (!content && parts.length > 0) {
    const textPart = parts.find((p) => p.type === "text");
    if (textPart?.text) {
      content = textPart.text;
    }
  }

  const nowIso = new Date().toISOString();

  const messagePayload = {
    type: "human",
    content,
    additional_kwargs: {
      parts,
      created_at: nowIso,
    },
  };

  try {
    const insertedId = await insertChatHistory(userId, messagePayload);

    if (!insertedId) {
      throw new Error("No ID returned from database insert");
    }

    console.log("[Journal API] Saved journal entry with id:", insertedId);

    return {
      id: insertedId.toString(),
      role: "user" as const,
      content,
      parts: parts.length > 0 ? parts : [{ type: "text", text: content }],
      createdAt: new Date(nowIso),
    };
  } catch (error: any) {
    console.error("[Journal API] Error inserting journal message:", error);
    throw createError({
      statusCode: 500,
      statusMessage: "Failed to persist journal entry",
      data: error?.message,
    });
  }
});
