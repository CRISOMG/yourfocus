import { serverSupabaseServiceRole } from "#supabase/server/serverSupabaseServiceRole";

export default defineEventHandler(async (event) => {
  const cookies = parseCookies(event);
  const supabaseServiceRole = serverSupabaseServiceRole(event);
  const config = useRuntimeConfig(event);

  console.log(config);
  console.log(cookies);

  return {
    hello: "world",
    user: event.context?.auth?.user,
  };
});
