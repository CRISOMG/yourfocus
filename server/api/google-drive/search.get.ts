// server/api/search.get.ts
import { google } from "googleapis";
import { defineEventHandler, getQuery, createError } from "h3";
import { serverSupabaseUser } from "#supabase/server";

async function getContent({ drive, fileId }: { drive?: any; fileId: string }) {
  try {
    // 2. Obtener el contenido del archivo
    // 'alt: media' es la clave para decir "dame el contenido, no los metadatos"
    const response = await drive.files.get(
      {
        fileId: fileId,
        alt: "media",
      },
      {
        // Importante: indicamos que esperamos un stream o texto, no un JSON
        responseType: "stream",
      },
    );

    // 3. Convertir el Stream a Texto (String) para enviarlo al frontend
    return new Promise((resolve, reject) => {
      let data = "";
      response.data
        .on("data", (chunk) => (data += chunk))
        .on("end", () => {
          // Devolvemos un objeto JSON con el contenido MD
          resolve({
            content: data,
          });
        })
        .on("error", (err) => reject(err));
    });
  } catch (error: any) {
    throw createError({
      statusCode: 500,
      statusMessage: "Error al descargar archivo",
      data: error.message,
    });
  }
}
// https://drive.google.com/file/d/1pO5i4lNei11B3OOwsQRjqKiVuq-SXSSu/view?usp=drive_link
export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig();
  const user = await serverSupabaseUser(event);

  if (!user) {
    throw createError({
      statusCode: 401,
      statusMessage: "Unauthorized: Debes estar logueado para buscar archivos",
    });
  }

  // 1. Obtener parámetros de la URL (ej: /api/search?name=informe&userId=qwerty)
  const query = getQuery(event);
  const targetName = query.name as string;
  const targetUserId = user.sub;
  const targetFileId = query.fileId as string;

  // 2. Autenticación (Igual que en el ejemplo anterior)
  const privateKey = config.google.privateKey.replace(/\\n/g, "\n");
  const auth = new google.auth.GoogleAuth({
    credentials: {
      client_email: config.google.clientEmail,
      private_key: privateKey,
      project_id: config.google.projectId,
    },
    scopes: ["https://www.googleapis.com/auth/drive"],
  });

  const drive = google.drive({ version: "v3", auth });

  // 3. CONSTRUCCIÓN DE LA QUERY AVANZADA (parámetro 'q')
  // Empezamos filtrando archivos que no estén en la papelera
  const searchTerms: string[] = ["trashed = false"];

  // A. Buscar por Nombre (usamos 'contains' para búsqueda parcial o '=' para exacta)
  if (targetName) {
    searchTerms.push(`name contains '${targetName}'`);
  }

  // B. Buscar por ID (Si se proporciona)
  if (targetFileId) {
    searchTerms.push(`id = '${targetFileId}'`);
  }

  // C. Buscar por Custom Properties { user_id = 'qwerty' }
  // La sintaxis exacta es: properties has { key='KEY' and value='VALUE' }
  //   if (targetUserId) {
  //     searchTerms.push(
  //       `properties has { key='user_id' and value='${targetUserId}' }`,
  //     );
  //   }

  // Unimos todo con ' and '
  const finalQuery = searchTerms.join(" and ");

  console.log("Query enviada a Google:", finalQuery);
  // Ejemplo de output: "trashed = false and name contains 'factura' and properties has { key='user_id' and value='qwerty' }"

  try {
    const response = await drive.files.list({
      q: finalQuery,
      // Solicitamos campos específicos, incluyendo 'properties' para verificar
      //   fields: "files(id, name, webViewLink, properties)",
      //   pageSize: 10,
    });

    const files = response.data.files || [];

    if (files.length === 0) {
      return {
        success: false,
        content: "No se encontraron archivos",
      };
    }
    const file = files[0];
    if (!file?.id) {
      return {
        success: false,
        content: "No se encontraron archivos con el ID proporcionado",
      };
    }
    const { content } = await getContent({ drive, fileId: file.id });

    return {
      success: true,
      count: files.length,
      files: files,
      content: content,
    };
  } catch (error: any) {
    return createError({
      statusCode: 500,
      statusMessage: error.message,
    });
  }
});
