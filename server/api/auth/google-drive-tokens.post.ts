// server/api/auth/google-drive-tokens.post.ts
import { serverSupabaseUser, serverSupabaseClient } from "#supabase/server";
import type { Database } from "~~/app/types/database.types";
import {
  assertDriveAuthorized,
  saveDriveTokens,
} from "~~/server/utils/google-drive-auth";

interface TokenPayload {
  accessToken: string;
  refreshToken?: string;
  expiryDate?: number;
}

export default defineEventHandler(async (event) => {
  const user = await serverSupabaseUser(event);
  assertDriveAuthorized(user);

  const userId = (user as any).id || (user as any).sub;
  const body = await readBody<TokenPayload>(event);

  if (!body?.accessToken && !body?.refreshToken) {
    throw createError({
      statusCode: 400,
      statusMessage: "Missing accessToken or refreshToken",
    });
  }

  const supabase = await serverSupabaseClient<Database>(event);

  await saveDriveTokens(supabase, userId, {
    accessToken: body.accessToken || "",
    refreshToken: body.refreshToken,
    expiryDate: body.expiryDate,
  });

  return {
    success: true,
    message: "Google Drive tokens securely stored",
  };
});
