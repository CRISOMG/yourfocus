import fs from "node:fs/promises";
import path from "node:path";

export default defineEventHandler(async (event) => {
  const id = getRouterParam(event, "id");

  if (!id) {
    throw createError({
      statusCode: 400,
      statusMessage: "Missing file name",
    });
  }

  try {
    const filename = decodeURIComponent(id);
    const filePath = path.join(process.cwd(), "public", filename);

    // Security check to ensure the file is within the public directory
    // This prevents directory traversal attacks
    if (!filePath.startsWith(path.join(process.cwd(), "public"))) {
      throw createError({
        statusCode: 403,
        statusMessage: "Access denied",
      });
    }

    const content = await fs.readFile(filePath, "utf-8");
    return content;
  } catch (error: any) {
    console.error("Error reading file:", error);
    throw createError({
      statusCode: 404,
      statusMessage: "File not found",
    });
  }
});
