CREATE POLICY "Enable insert for authenticated users only" 
ON "public"."pomodoros_cycles" 
FOR INSERT TO "authenticated" 
WITH CHECK (("user_id" = (select auth.uid())));
