import { serverSupabaseClient, serverSupabaseUser } from "#supabase/server";

export default defineEventHandler(async (event) => {
  const user = await serverSupabaseUser(event);

  if (!user) {
    throw createError({
      statusCode: 401,
      statusMessage:
        "Unauthorized: You must be logged in to test push notifications.",
    });
  }

  const body = await readBody(event);
  const supabase = await serverSupabaseClient(event);

  let payload: any = {
    user_id: user?.id || user.sub,
    notification: body.notification || {
      title: "¡Prueba Exitosa! 🎉",
      body: "Las notificaciones push están configuradas y llegando perfectamente a tu dispositivo.",
      url: "/",
    },
  };

  if (body.mockCreateTask) {
    // Insert a fake inbox_action to test the UI dispatcher
    const { data: inboxAction, error: insertError } = await supabase
      .from("inbox_actions")
      .insert({
        user_id: user?.id || user?.sub,
        action_type: "CREATE_TASK",
        action_payload: { template_id: "dd3e7e91-d537-4871-a6e8-0e8289af33e9" },
        status: "pending",
        title: "Crear Tarea Prueba",
      })
      .select()
      .single();

    if (insertError) {
      console.error("Failed to mock inbox_action:", insertError);
    } else {
      payload = {
        user_id: user?.id || user?.sub,
        notification: {
          title: "Crear tarea de rutina",
          body: "Toca para abrir el modal del template",
          url: `/?action_id=${inboxAction.id}`,
        },
        action_id: inboxAction.id,
      };
    }
  }

  console.log(
    "Invoking edge function send-push with payload:",
    JSON.stringify(payload),
  );

  // Invoke the edge function from the secure server environment
  const { data, error } = await supabase.functions.invoke("send-push", {
    body: payload,
  });

  if (error) {
    console.error("Error from send-push edge function:", error);
    throw createError({
      statusCode: 500,
      statusMessage:
        "Error invoking push service: " +
        (error.message || JSON.stringify(error)),
      data: error,
    });
  }

  return { success: true, data };
});
