// server/api/audio/export-drive.post.ts
import { Readable } from "node:stream";
import path from "node:path";
import { serverSupabaseUser, serverSupabaseClient } from "#supabase/server";
import type { Database } from "~~/app/types/database.types";
import {
  assertDriveAuthorized,
  createDriveOAuthClient,
} from "~~/server/utils/google-drive-auth";

interface ExportDriveBody {
  audioPath: string;
}

const BUCKET_NAME = "yourfocus";

export default defineEventHandler(async (event) => {
  const user = await serverSupabaseUser(event);
  assertDriveAuthorized(user);

  const userId = (user as any).id || (user as any).sub;
  const body = await readBody<ExportDriveBody>(event);

  if (!body?.audioPath) {
    throw createError({
      statusCode: 400,
      statusMessage: "audioPath is required",
    });
  }

  const { audioPath } = body;

  // Security: prevent path traversal and enforce user sandbox
  if (audioPath.includes("..")) {
    throw createError({
      statusCode: 400,
      statusMessage: "Invalid audioPath: path traversal sequences are not allowed",
    });
  }

  const pathParts = audioPath.split("/");
  if (pathParts[0] !== userId) {
    throw createError({
      statusCode: 403,
      statusMessage: "Forbidden: You cannot access files outside your personal storage",
    });
  }

  const supabase = await serverSupabaseClient<Database>(event);

  // Download file from Supabase storage
  const { data: fileBlob, error: downloadError } = await supabase.storage
    .from(BUCKET_NAME)
    .download(audioPath);

  if (downloadError || !fileBlob) {
    console.error("[Export Drive] Error downloading file from storage:", downloadError);
    throw createError({
      statusCode: 404,
      statusMessage: "No se pudo obtener el archivo de audio del almacenamiento",
    });
  }

  // Obtain authenticated Google Drive client
  const drive = await createDriveOAuthClient(supabase, userId);

  const config = useRuntimeConfig();
  const folderId = config.google?.folderId || process.env.DRIVE_FOLDER_ID;

  const fileName = path.basename(audioPath) || "audio.mp3";

  let mimeType = "audio/mpeg";
  if (fileName.endsWith(".webm")) {
    mimeType = "audio/webm";
  } else if (fileName.endsWith(".mp3")) {
    mimeType = "audio/mpeg";
  } else if (fileName.endsWith(".wav")) {
    mimeType = "audio/wav";
  } else if (fileName.endsWith(".ogg")) {
    mimeType = "audio/ogg";
  }

  const arrayBuffer = await fileBlob.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);
  const stream = Readable.from(buffer);

  try {
    const driveResponse = await drive.files.create({
      requestBody: {
        name: fileName,
        parents: folderId ? [folderId] : undefined,
      },
      media: {
        mimeType,
        body: stream,
      },
      fields: "id, name, mimeType, webViewLink, webContentLink, size",
    });

    return {
      success: true,
      fileId: driveResponse.data.id,
      name: driveResponse.data.name,
      webViewLink: driveResponse.data.webViewLink,
      folderId,
    };
  } catch (err: any) {
    console.error("[Export Drive] Error uploading to Google Drive:", err?.message || err);
    throw createError({
      statusCode: 500,
      statusMessage: `Error al subir archivo a Google Drive: ${err?.message || "Error desconocido"}`,
    });
  }
});
