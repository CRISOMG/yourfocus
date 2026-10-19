import postgres from "postgres";

// Usamos una única instancia lazy para toda la aplicación
// Asegúrate de definir N8N_POSTGRES_URL en tu archivo .env
// Ejemplo: postgres://user:pass@host:5432/db
export const sql = postgres(
  process.env.N8N_POSTGRES_URL || process.env.DATABASE_URL!,
);

/**
 * Inserta un registro en n8n_chat_histories garantizando que la secuencia de IDs esté sincronizada
 * con el MAX(id) actual para evitar colisiones de clave primaria y desfases cronológicos.
 */
export async function insertChatHistory(
  sessionId: string,
  messagePayload: any,
): Promise<number> {
  try {
    const rows = await sql<{ id: number }[]>`
      INSERT INTO n8n_chat_histories (session_id, message)
      VALUES (${sessionId}, ${sql.json(messagePayload)})
      RETURNING id
    `;
    return rows[0]?.id;
  } catch (err: any) {
    if (err?.code === "23505" || err?.message?.includes("duplicate key")) {
      console.warn(
        "[messages-db] Primary key collision detected, syncing sequence to MAX(id)...",
      );
      await syncChatHistoriesSequence();
      const retryRows = await sql<{ id: number }[]>`
        INSERT INTO n8n_chat_histories (session_id, message)
        VALUES (${sessionId}, ${sql.json(messagePayload)})
        RETURNING id
      `;
      return retryRows[0]?.id;
    }
    throw err;
  }
}

export async function syncChatHistoriesSequence(): Promise<void> {
  try {
    await sql`
      SELECT setval(
        pg_get_serial_sequence('n8n_chat_histories', 'id'),
        COALESCE((SELECT MAX(id) FROM n8n_chat_histories), 1)
      );
    `;
  } catch (e) {
    console.error("[messages-db] Failed to sync sequence:", e);
  }
}
