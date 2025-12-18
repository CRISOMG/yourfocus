// server/api/tokens/generate.post.ts
import jwt from "jsonwebtoken";
import {
  serverSupabaseUser,
  serverSupabaseServiceRole,
} from "#supabase/server";

export default defineEventHandler(async (event) => {
  // 1. Obtener el usuario que hace la petición (seguridad primero)
  const user = await serverSupabaseUser(event);

  if (!user) {
    throw createError({
      statusCode: 401,
      statusMessage:
        "Unauthorized: Debes estar logueado para generar una API Key",
    });
  }

  // 2. Leer el body para obtener el nombre del token
  const body = await readBody(event);
  const tokenName = body.name || "Token sin nombre";

  // 3. Insertar el registro en la base de datos (Tabla api_keys)
  // Usamos el ServiceRole para asegurarnos de poder escribir, aunque RLS
  // podría permitirlo con el cliente normal, esto es más robusto para operaciones administrativas.
  const supabaseAdmin = serverSupabaseServiceRole(event);

  const { data: apiKeyData, error: dbError } = await supabaseAdmin
    .from("api_keys")
    .insert({
      user_id: user.sub,
      name: tokenName,
      is_active: true,
    })
    .select()
    .single();

  if (dbError) {
    throw createError({
      statusCode: 500,
      statusMessage: `Error creando registro: ${dbError.message}`,
    });
  }

  // 4. Firmar el JWT Personalizado
  // Aquí ocurre la magia. Usamos el secreto de Supabase.
  const jwtSecret = process.env.SUPABASE_JWT_SECRET;

  if (!jwtSecret) {
    throw createError({
      statusCode: 500,
      statusMessage: "JWT Secret no configurado en servidor",
    });
  }

  const payload = {
    // Claims obligatorios para que Supabase lo acepte
    aud: "authenticated",
    role: "authenticated",
    sub: user.sub, // CRUCIAL: Esto hace que auth.uid() funcione en RLS

    // Configuración del token
    exp: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 365, // 1 año de validez
    iat: Math.floor(Date.now() / 1000),

    // Tus claims personalizados para enlazar con la tabla
    jti: apiKeyData.id, // ID de la key en base de datos
    type: "personal_access_token",
  };

  const token = jwt.sign(payload, jwtSecret);

  // 5. Retornar el token al cliente (solo se muestra una vez)
  return {
    token: token,
    id: apiKeyData.id,
    name: apiKeyData.name,
    message: "Guarda este token en un lugar seguro, no podrás verlo de nuevo.",
  };
});
