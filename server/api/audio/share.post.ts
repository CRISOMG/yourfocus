import { serverSupabaseUser, serverSupabaseClient } from "#supabase/server";
import type { Database } from "~~/app/types/database.types";

interface ShareAudioBody {
  audioPath: string;
  expiresIn?: number; // In seconds. Default: 604800 (7 days). If 0 or -1, use long-term (e.g. 5 years)
  download?: boolean;
}

const BUCKET_NAME = "yourfocus";
const DEFAULT_EXPIRY_SECONDS = 7 * 24 * 60 * 60; // 7 days
const MAX_LONG_EXPIRY_SECONDS = 5 * 365 * 24 * 60 * 60; // ~5 years for "permanent/sin exp"

export default defineEventHandler(async (event) => {
  const user = await serverSupabaseUser(event);

  if (!user) {
    throw createError({
      statusCode: 401,
      statusMessage: "Unauthorized",
    });
  }

  const userId = (user as any).id || (user as any).sub;
  const body = await readBody<ShareAudioBody>(event);

  if (!body?.audioPath) {
    throw createError({
      statusCode: 400,
      statusMessage: "audioPath is required",
    });
  }

  const { audioPath, download = false } = body;

  // Security check: ensure user can only generate links for their own folder
  // Path format: `${userId}/bitacora/...`
  const pathParts = audioPath.split("/");
  if (pathParts[0] !== userId) {
    throw createError({
      statusCode: 403,
      statusMessage: "Forbidden: You cannot access files outside your personal storage",
    });
  }

  // Calculate TTL
  let expiry = DEFAULT_EXPIRY_SECONDS;
  if (typeof body.expiresIn === "number") {
    if (body.expiresIn <= 0) {
      expiry = MAX_LONG_EXPIRY_SECONDS;
    } else {
      expiry = body.expiresIn;
    }
  }

  const supabase = await serverSupabaseClient<Database>(event);

  const { data, error } = await supabase.storage
    .from(BUCKET_NAME)
    .createSignedUrl(audioPath, expiry, {
      download: download ? true : false,
    });

  if (error || !data?.signedUrl) {
    console.error("[Audio Share API] Error creating signed URL:", error);
    throw createError({
      statusCode: 500,
      statusMessage: "Failed to generate signed URL",
      data: error?.message,
    });
  }

  return {
    signedUrl: data.signedUrl,
    expiresIn: expiry,
    audioPath,
  };
});
