CREATE POLICY "Enable insert for own tags" ON "public"."tags" FOR INSERT TO "authenticated" WITH CHECK ((((select auth.uid()) = "user_id") AND "public"."is_valid_personal_access_token"()));

CREATE POLICY "Enable read access for own tags" ON "public"."tags" FOR SELECT TO "authenticated" USING ((((select auth.uid()) = "user_id") AND "public"."is_valid_personal_access_token"()));
