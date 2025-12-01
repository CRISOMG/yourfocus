export default defineNuxtRouteMiddleware(() => {
  const supabase = useSupabaseClient();
  const user = useSupabaseUser();

  supabase.auth.onAuthStateChange((event, session) => {
    // console.log("event", event);
    // console.log("session", session);
    // console.log("user", user.value);
    // if (event === "INITIAL_SESSION") {
    //   supabase.auth.refreshSession();
    // }
  });
});
