// server/utils/google-drive-auth.ts
import { google, drive_v3 } from "googleapis";
import { createError } from "h3";
import type { SupabaseClient } from "@supabase/supabase-js";
import { encryptSecret, decryptSecret } from "./vault";

export const AUTHORIZED_DRIVE_EMAIL = "cristiancaraballo112@gmail.com";
export const AUTHORIZED_DRIVE_USER_ID = "4ddb8909-ef46-4cde-8feb-8ce0a3c72564";
export const DRIVE_SECRET_NAME = "google_drive_tokens";

export interface StoredDriveTokens {
  accessToken: string;
  refreshToken?: string;
  expiryDate?: number;
  updatedAt: string;
}

/**
 * Checks if the given user is authorized to use the Google Drive integration
 */
export function isDriveAuthorizedUser(user: any): boolean {
  if (!user) return false;
  const email = user.email;
  const id = user.id || user.sub;
  return (
    email === AUTHORIZED_DRIVE_EMAIL || id === AUTHORIZED_DRIVE_USER_ID
  );
}

/**
 * Strictly asserts user authentication and authorization
 */
export function assertDriveAuthorized(user: any): void {
  if (!user) {
    throw createError({
      statusCode: 401,
      statusMessage: "Unauthorized: Debes iniciar sesión",
    });
  }

  if (!isDriveAuthorizedUser(user)) {
    throw createError({
      statusCode: 403,
      statusMessage:
        "Forbidden: La exportación a Google Drive está restringida al propietario",
    });
  }
}

/**
 * Retrieves and decrypts stored Google Drive tokens from user_secrets
 */
export async function getStoredDriveTokens(
  supabase: SupabaseClient<any>,
  userId: string,
): Promise<StoredDriveTokens | null> {
  const { data, error } = await supabase
    .from("user_secrets")
    .select("key_value, iv, tag, is_active")
    .eq("user_id", userId)
    .eq("name", DRIVE_SECRET_NAME)
    .eq("is_active", true)
    .maybeSingle();

  if (error || !data) {
    return null;
  }

  try {
    const decrypted = decryptSecret({
      encrypted: data.key_value,
      iv: data.iv,
      tag: data.tag,
    });
    return JSON.parse(decrypted) as StoredDriveTokens;
  } catch (err) {
    console.error("[GoogleDriveAuth] Error decrypting tokens:", err);
    return null;
  }
}

/**
 * Encrypts and saves Google Drive tokens to user_secrets
 */
export async function saveDriveTokens(
  supabase: SupabaseClient<any>,
  userId: string,
  tokens: { accessToken: string; refreshToken?: string; expiryDate?: number },
): Promise<void> {
  const existingTokens = await getStoredDriveTokens(supabase, userId);

  const mergedTokens: StoredDriveTokens = {
    accessToken: tokens.accessToken || existingTokens?.accessToken || "",
    refreshToken: tokens.refreshToken || existingTokens?.refreshToken,
    expiryDate: tokens.expiryDate || existingTokens?.expiryDate,
    updatedAt: new Date().toISOString(),
  };

  const { encrypted, iv, tag } = encryptSecret(JSON.stringify(mergedTokens));

  const { data: existing } = await supabase
    .from("user_secrets")
    .select("id")
    .eq("user_id", userId)
    .eq("name", DRIVE_SECRET_NAME)
    .maybeSingle();

  if (existing) {
    const { error } = await supabase
      .from("user_secrets")
      .update({
        key_value: encrypted,
        iv,
        tag,
        is_active: true,
        updated_at: new Date().toISOString(),
      })
      .eq("id", existing.id);

    if (error) {
      throw createError({ statusCode: 500, statusMessage: error.message });
    }
  } else {
    const { error } = await supabase.from("user_secrets").insert({
      user_id: userId,
      name: DRIVE_SECRET_NAME,
      key_value: encrypted,
      iv,
      tag,
      is_active: true,
    });

    if (error) {
      throw createError({ statusCode: 500, statusMessage: error.message });
    }
  }
}

/**
 * Deactivates stored tokens
 */
export async function deleteDriveTokens(
  supabase: SupabaseClient<any>,
  userId: string,
): Promise<void> {
  await supabase
    .from("user_secrets")
    .update({ is_active: false, updated_at: new Date().toISOString() })
    .eq("user_id", userId)
    .eq("name", DRIVE_SECRET_NAME);
}

/**
 * Instantiates an authenticated Google Drive client with automatic token refreshing
 */
export async function createDriveOAuthClient(
  supabase: SupabaseClient<any>,
  userId: string,
): Promise<drive_v3.Drive> {
  const config = useRuntimeConfig();
  const clientId =
    config.google?.clientId ||
    process.env.SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID;
  const clientSecret =
    config.google?.clientSecret ||
    process.env.SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET;

  if (!clientId || !clientSecret) {
    throw createError({
      statusCode: 500,
      statusMessage: "Google OAuth credentials are not configured on server",
    });
  }

  const tokens = await getStoredDriveTokens(supabase, userId);
  if (!tokens || (!tokens.accessToken && !tokens.refreshToken)) {
    throw createError({
      statusCode: 400,
      statusMessage:
        "Google Drive no está conectado. Por favor conecta tu cuenta de Google Drive.",
    });
  }

  const oauth2Client = new google.auth.OAuth2(clientId, clientSecret);
  oauth2Client.setCredentials({
    access_token: tokens.accessToken,
    refresh_token: tokens.refreshToken,
    expiry_date: tokens.expiryDate,
  });

  // Automatically persist new tokens when refreshed
  oauth2Client.on("tokens", async (newTokens) => {
    try {
      await saveDriveTokens(supabase, userId, {
        accessToken: newTokens.access_token || tokens.accessToken,
        refreshToken: newTokens.refresh_token || tokens.refreshToken,
        expiryDate: newTokens.expiry_date || tokens.expiryDate,
      });
    } catch (e) {
      console.error("[GoogleDriveAuth] Failed to persist refreshed tokens:", e);
    }
  });

  return google.drive({ version: "v3", auth: oauth2Client });
}
