// server/api/audio/drive-status.delete.ts
import { serverSupabaseUser, serverSupabaseClient } from "#supabase/server";
import type { Database } from "~~/app/types/database.types";
import {
  assertDriveAuthorized,
  deleteDriveTokens,
} from "~~/server/utils/google-drive-auth";

export default defineEventHandler(async (event) => {
  const user = await serverSupabaseUser(event);
  assertDriveAuthorized(user);

  const userId = (user as any).id || (user as any).sub;
  const supabase = await serverSupabaseClient<Database>(event);

  await deleteDriveTokens(supabase, userId);

  return {
    success: true,
    message: "Google Drive desconectado correctamente",
  };
});
