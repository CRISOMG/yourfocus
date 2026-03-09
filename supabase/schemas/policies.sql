ALTER TABLE "public"."tags" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Auth users and PAT can insert tags" ON "public"."tags";
-- Removed duplicate policy
DROP POLICY IF EXISTS "Auth users and PAT can read tags" ON "public"."tags";
-- Removed duplicate policy
CREATE POLICY "Enable delete for own tags" ON "public"."tags" FOR DELETE TO "authenticated" USING (((select auth.uid()) = "user_id"));
CREATE POLICY "Enable insert for own tags" ON "public"."tags" FOR INSERT TO "authenticated" WITH CHECK ((((select auth.uid()) = "user_id") AND "public"."is_valid_personal_access_token"()));
CREATE POLICY "Enable read access for own tags" ON "public"."tags" FOR SELECT TO "authenticated" USING ((((select auth.uid()) = "user_id") AND "public"."is_valid_personal_access_token"()));
CREATE POLICY "Enable update for own tags" ON "public"."tags" FOR UPDATE TO "authenticated" USING (((select auth.uid()) = "user_id")) WITH CHECK (((select auth.uid()) = "user_id"));


ALTER TABLE "public"."tasks" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authenticated users can create their own tasks" ON "public"."tasks";
CREATE POLICY "Authenticated users can create their own tasks" ON "public"."tasks" FOR INSERT TO "authenticated" WITH CHECK ((((select auth.uid()) = "user_id") AND "public"."is_valid_personal_access_token"()));
DROP POLICY IF EXISTS "Authenticated users can delete their own tasks" ON "public"."tasks";
CREATE POLICY "Authenticated users can delete their own tasks" ON "public"."tasks" FOR DELETE TO "authenticated" USING ((((select auth.uid()) = "user_id") AND "public"."is_valid_personal_access_token"()));
DROP POLICY IF EXISTS "Authenticated users can read their own tasks" ON "public"."tasks";
CREATE POLICY "Authenticated users can read their own tasks" ON "public"."tasks" FOR SELECT TO "authenticated" USING ((((select auth.uid()) = "user_id") AND "public"."is_valid_personal_access_token"()));
DROP POLICY IF EXISTS "Authenticated users can update their own tasks" ON "public"."tasks";
CREATE POLICY "Authenticated users can update their own tasks" ON "public"."tasks" FOR UPDATE TO "authenticated" USING ((((select auth.uid()) = "user_id") AND "public"."is_valid_personal_access_token"())) WITH CHECK ((((select auth.uid()) = "user_id") AND "public"."is_valid_personal_access_token"()));


ALTER TABLE "public"."pomodoros" ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable delete for users based on user_id" 
ON "public"."pomodoros" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));

CREATE POLICY "Enable insert for users based on user_id" ON "public"."pomodoros" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));

DROP POLICY IF EXISTS "Enable users and personal access tokens to view their own data " ON "public"."pomodoros";
DROP POLICY IF EXISTS "Enable users and PAT to view pomodoros" ON "public"."pomodoros";
CREATE POLICY "Enable users and PAT to view pomodoros" ON "public"."pomodoros" FOR SELECT TO "authenticated" USING ((((select auth.uid()) = "user_id") AND "public"."is_valid_personal_access_token"()));

CREATE POLICY "Enable users to edit their own data only" ON "public"."pomodoros" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"()) = "user_id"));

-- Redundant policy removed: "Enable users to view their own data only"

ALTER TABLE "public"."pomodoros_cycles" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable insert for authenticated users only" 
ON "public"."pomodoros_cycles" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = (select auth.uid())));
DROP POLICY IF EXISTS "Enable users and personal access tokens to view their own data " ON "public"."pomodoros_cycles";
DROP POLICY IF EXISTS "Enable users and PAT to view cycles" ON "public"."pomodoros_cycles";
CREATE POLICY "Enable users and PAT to view cycles" ON "public"."pomodoros_cycles" FOR SELECT TO "authenticated" USING ((((select auth.uid()) = "user_id") AND "public"."is_valid_personal_access_token"()));

CREATE POLICY "Enable users to update their own data only" ON "public"."pomodoros_cycles" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));
-- Redundant policy removed: "Enable users to view their own data only"


ALTER TABLE "public"."pomodoros_tags" ENABLE ROW LEVEL SECURITY;
-- Redundant policy removed: "Enable insert for authenticated users only"
CREATE POLICY "Enable insert for users based on user_id" 
ON "public"."pomodoros_tags" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));

DROP POLICY IF EXISTS "Enable users and personal access tokens to view their own data " ON "public"."pomodoros_tags";
DROP POLICY IF EXISTS "Enable users and PAT to view pomodoros_tags" ON "public"."pomodoros_tags";
CREATE POLICY "Enable users and PAT to view pomodoros_tags" 
ON "public"."pomodoros_tags" FOR SELECT TO "authenticated" USING ((((select auth.uid()) = "user_id") AND "public"."is_valid_personal_access_token"()));

-- Redundant policy removed: "Enable users to view their own data only"
CREATE POLICY "Enable delete for users based on user_id" 
ON "public"."pomodoros_tags" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));


ALTER TABLE "public"."tasks_tags" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable insert for users based on user_id" 
ON "public"."tasks_tags" FOR INSERT 
WITH CHECK ((SELECT auth.uid()) = "user_id");

CREATE POLICY "Enable users and PAT to view tasks_tags" 
ON "public"."tasks_tags" FOR SELECT TO "authenticated" 
USING ((((select auth.uid()) = "user_id") AND "public"."is_valid_personal_access_token"()));

CREATE POLICY "Enable delete for users based on user_id" 
ON "public"."tasks_tags" FOR DELETE 
USING ((SELECT auth.uid()) = "user_id");


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public profiles are viewable by everyone." ON "public"."profiles" FOR SELECT USING (true);
CREATE POLICY "Users can update their own profile." ON "public"."profiles" FOR UPDATE USING (((select auth.uid()) = "id"));
CREATE POLICY "Users can insert their own profile." ON "public"."profiles" FOR INSERT WITH CHECK (((select auth.uid()) = "id"));


ALTER TABLE "public"."api_keys" ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can delete their own keys" ON "public"."api_keys" FOR DELETE USING (((select auth.uid()) = "user_id"));
CREATE POLICY "Users can view their own keys" ON "public"."api_keys" FOR SELECT USING (((select auth.uid()) = "user_id"));
GRANT ALL ON TABLE "public"."api_keys" TO "anon";
GRANT ALL ON TABLE "public"."api_keys" TO "authenticated";
GRANT ALL ON TABLE "public"."api_keys" TO "service_role";


-- #region OKR Policies
alter table public.objectives enable row level security;
create policy "Users can manage their own objectives" on public.objectives for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

alter table public.key_results enable row level security;
create policy "Users can manage key_results of their objectives" on public.key_results for all to authenticated using (objective_id in (select id from public.objectives where user_id = (select auth.uid()))) with check (objective_id in (select id from public.objectives where user_id = (select auth.uid())));

alter table public.key_result_tags enable row level security;
create policy "Users can manage tags of their key_results" on public.key_result_tags for all to authenticated using (key_result_id in (select id from public.key_results where objective_id in (select id from public.objectives where user_id = (select auth.uid())))) with check (key_result_id in (select id from public.key_results where objective_id in (select id from public.objectives where user_id = (select auth.uid()))));
-- #endregion

-- #region Zettelkasten Notes Policies
alter table public.notes enable row level security;
create policy "Users can manage their own notes" on public.notes for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

alter table public.notes_tags enable row level security;
create policy "Users can manage tags of their notes" on public.notes_tags for all to authenticated using (note_id in (select id from public.notes where user_id = (select auth.uid()))) with check (note_id in (select id from public.notes where user_id = (select auth.uid())));
-- #endregion


create policy "Allow access to own pomodoro sync channel"
on realtime.messages
for all
using (
  -- Check if the user is authenticated
  (select auth.role()) = 'authenticated' and
  -- Check if the topic ends with the user's ID (sub)
  realtime.topic() = 'pomodoro_sync:' || (select auth.uid())::text
);

  create policy "Allow broadcasting presences on all channels for authenticated "
  on "realtime"."messages"
  as permissive
  for insert
  to authenticated
with check ((extension = 'presence'::text));



  create policy "Allow listening for presences from a pomodoro_sync"
  on "realtime"."messages"
  as permissive
  for select
  to public
using (((extension = 'presence'::text) AND (realtime.topic() = ('pomodoro_sync:'::text || ((select auth.uid()))::text))));



  create policy "Allow listening for presences on all channels for authenticated"
  on "realtime"."messages"
  as permissive
  for select
  to authenticated
using ((extension = 'presence'::text));



  create policy "Publish presence to a specific channel"
  on "realtime"."messages"
  as permissive
  for insert
  to public
with check (((extension = 'presence'::text) AND (realtime.topic() = ('pomodoro_sync:'::text || ((select auth.uid()))::text))));




CREATE POLICY "Allow authenticated user to insert their avatar" ON "storage"."objects" FOR INSERT TO "authenticated" WITH CHECK ((("bucket_id" = 'avatars'::"text") AND (("auth"."uid"())::"text" = "split_part"("name", '/'::"text", 1))));



CREATE POLICY "Allow authenticated user to select their avatar" ON "storage"."objects" FOR SELECT TO "authenticated" USING ((("bucket_id" = 'avatars'::"text") AND (("auth"."uid"())::"text" = "split_part"("name", '/'::"text", 1))));
CREATE POLICY "Avatars are viewable by everyone" ON "storage"."objects" FOR SELECT USING (("bucket_id" = 'avatars'::"text"));


-- #region TIME_SESSIONS and FLOWS policies
ALTER TABLE public.time_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own time_sessions"
  ON public.time_sessions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own time_sessions"
  ON public.time_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own time_sessions"
  ON public.time_sessions FOR UPDATE
  USING (auth.uid() = user_id);

ALTER TABLE public.flows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own flows"
  ON public.flows FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own flows"
  ON public.flows FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own flows"
  ON public.flows FOR UPDATE
  USING (auth.uid() = user_id);
-- #endregion

-- #region TASK_TEMPLATES policies
ALTER TABLE public.task_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_templates_tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own templates"
  ON public.task_templates FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own templates"
  ON public.task_templates FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own templates"
  ON public.task_templates FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own templates"
  ON public.task_templates FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view tags of their own templates"
  ON public.task_templates_tags FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.task_templates
      WHERE task_templates.id = task_templates_tags.template_id
      AND task_templates.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert tags for their own templates"
  ON public.task_templates_tags FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.task_templates
      WHERE task_templates.id = task_templates_tags.template_id
      AND task_templates.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update tags for their own templates"
  ON public.task_templates_tags FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.task_templates
      WHERE task_templates.id = task_templates_tags.template_id
      AND task_templates.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.task_templates
      WHERE task_templates.id = task_templates_tags.template_id
      AND task_templates.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete tags for their own templates"
  ON public.task_templates_tags FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.task_templates
      WHERE task_templates.id = task_templates_tags.template_id
      AND task_templates.user_id = auth.uid()
    )
  );
-- #endregion

-- #region New Tables Policies
-- documents
ALTER TABLE "public"."documents" ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role can manage documents" ON "public"."documents" TO service_role USING (true) WITH CHECK (true);

-- n8n_chat_histories
-- (No RLS needed/enabled for this internal table, or managed elsewhere)

-- push_subscriptions
ALTER TABLE "public"."push_subscriptions" ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own push subscriptions" ON "public"."push_subscriptions" FOR ALL TO "authenticated" USING (("user_id" = (select auth.uid()))) WITH CHECK (("user_id" = (select auth.uid())));

-- user_secrets
ALTER TABLE "public"."user_secrets" ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own or community secrets" ON "public"."user_secrets" FOR SELECT TO "authenticated" USING ((("user_id" = (select auth.uid())) OR ("user_id" IS NULL AND (select auth.role()) = 'authenticated')));
CREATE POLICY "Users can insert own secrets" ON "public"."user_secrets" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = (select auth.uid())));
CREATE POLICY "Users can update own secrets" ON "public"."user_secrets" FOR UPDATE TO "authenticated" USING (("user_id" = (select auth.uid())));
CREATE POLICY "Users can delete own secrets" ON "public"."user_secrets" FOR DELETE TO "authenticated" USING (("user_id" = (select auth.uid())));
-- #endregion

-- #region Scheduled Notifications Policies
ALTER TABLE "public"."notification_templates" ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view notification_templates" ON "public"."notification_templates" FOR SELECT USING (true);

ALTER TABLE "public"."scheduled_notifications" ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own scheduled notifications" ON "public"."scheduled_notifications" FOR ALL TO "authenticated" USING (("user_id" = (select auth.uid()))) WITH CHECK (("user_id" = (select auth.uid())));

-- inbox_actions
ALTER TABLE "public"."inbox_actions" ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own inbox actions" ON "public"."inbox_actions" FOR ALL TO "authenticated" USING (("user_id" = (select auth.uid()))) WITH CHECK (("user_id" = (select auth.uid())));
-- #endregion
