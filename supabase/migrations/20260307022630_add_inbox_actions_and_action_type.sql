-- Add action_type column to scheduled_notifications
ALTER TABLE "public"."scheduled_notifications"
  ADD COLUMN IF NOT EXISTS "action_type" text DEFAULT 'NONE'
  CHECK (action_type IN ('NONE', 'CREATE_TASK', 'REVIEW_NOTE', 'CREATE_LOG', 'AI_ATOMIZE'));

-- Create inbox_actions table
CREATE TABLE IF NOT EXISTS "public"."inbox_actions" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "user_id" uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    "source_notification_id" uuid REFERENCES public.scheduled_notifications(id) ON DELETE SET NULL,
    "title" text NOT NULL,
    "description" text,
    "action_type" text DEFAULT 'NONE'
        CHECK (action_type IN ('NONE', 'CREATE_TASK', 'REVIEW_NOTE', 'CREATE_LOG', 'AI_ATOMIZE')),
    "action_payload" jsonb DEFAULT '{}',
    "status" text DEFAULT 'pending'
        CHECK (status IN ('pending', 'completed', 'dismissed')),
    "priority" int DEFAULT 1,
    "execution_count" int DEFAULT 0,
    "created_at" timestamptz DEFAULT now(),
    "completed_at" timestamptz
);

ALTER TABLE "public"."inbox_actions" OWNER TO "postgres";

-- Indexes
CREATE INDEX IF NOT EXISTS "ix_inbox_actions_user_id" ON "public"."inbox_actions" USING btree ("user_id");
CREATE INDEX IF NOT EXISTS "ix_inbox_actions_status" ON "public"."inbox_actions" USING btree ("status");

-- Grants
GRANT ALL ON TABLE "public"."inbox_actions" TO "anon";
GRANT ALL ON TABLE "public"."inbox_actions" TO "authenticated";
GRANT ALL ON TABLE "public"."inbox_actions" TO "service_role";

-- RLS
ALTER TABLE "public"."inbox_actions" ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own inbox actions"
  ON "public"."inbox_actions"
  FOR ALL TO "authenticated"
  USING (("user_id" = (select auth.uid())))
  WITH CHECK (("user_id" = (select auth.uid())));
