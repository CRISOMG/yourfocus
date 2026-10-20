// server/api/audio/drive-status.get.ts
import { serverSupabaseUser, serverSupabaseClient } from "#supabase/server";
import type { Database } from "~~/app/types/database.types";
import {
  isDriveAuthorizedUser,
  getStoredDriveTokens,
} from "~~/server/utils/google-drive-auth";

export default defineEventHandler(async (event) => {
  const user = await serverSupabaseUser(event);

  if (!user || !isDriveAuthorizedUser(user)) {
    return {
      connected: false,
      isAuthorized: false,
    };
  }

  const userId = (user as any).id || (user as any).sub;
  const supabase = await serverSupabaseClient<Database>(event);
  const tokens = await getStoredDriveTokens(supabase, userId);

  const hasValidTokens =
    !!tokens && (Boolean(tokens.accessToken) || Boolean(tokens.refreshToken));

  return {
    connected: hasValidTokens,
    isAuthorized: true,
    email: (user as any).email,
    updatedAt: tokens?.updatedAt || null,
  };
});
