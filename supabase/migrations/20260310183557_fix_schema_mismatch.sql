drop policy "Users can insert own flows" on "public"."flows";

drop policy "Users can update own flows" on "public"."flows";

drop policy "Users can view own flows" on "public"."flows";

drop policy "Users can insert own time_sessions" on "public"."time_sessions";

drop policy "Users can update own time_sessions" on "public"."time_sessions";

drop policy "Users can view own time_sessions" on "public"."time_sessions";

alter table "public"."flows" drop constraint "flows_user_id_fkey";

alter table "public"."time_sessions" drop constraint "time_sessions_user_id_fkey";

drop index if exists "public"."idx_unique_active_time_session";

alter table "public"."n8n_chat_histories" enable row level security;

alter table "public"."time_sessions" alter column "toggle_timeline" set default '[]'::jsonb;

CREATE UNIQUE INDEX idx_unique_active_pomodoro_per_user ON public.pomodoros USING btree (user_id) WHERE (state <> ALL (ARRAY['finished'::public.pomodoro_state, 'skipped'::public.pomodoro_state]));

CREATE UNIQUE INDEX idx_unique_active_time_session_per_user ON public.time_sessions USING btree (user_id, mode) WHERE (state <> ALL (ARRAY['finished'::public.pomodoro_state, 'skipped'::public.pomodoro_state]));

alter table "public"."flows" add constraint "flows_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) not valid;

alter table "public"."flows" validate constraint "flows_user_id_fkey";

alter table "public"."time_sessions" add constraint "time_sessions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) not valid;

alter table "public"."time_sessions" validate constraint "time_sessions_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.calculate_kr_progress_on_pomodoro_finish()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_kr RECORD;
    v_seconds_invested INTEGER;
    v_minutes_invested INTEGER;
BEGIN
    IF NEW.state = 'finished' AND (OLD.state IS NULL OR OLD.state != 'finished') THEN
        -- Use the existing robust duration calculation function
        -- It handles pauses/plays in toggle_timeline
        v_seconds_invested := public.calculate_pomodoro_timelapse_sql(
            NEW.started_at, 
            NEW.toggle_timeline, 
            NEW.expected_duration,
            COALESCE(NEW.finished_at, now())
        );
        
        -- Convert to whole minutes
        v_minutes_invested := FLOOR(v_seconds_invested::numeric / 60.0)::INTEGER;

        FOR v_kr IN
            SELECT kr.id, krt.weight, kr.metric_type
            FROM public.key_results kr
            JOIN public.key_result_tags krt ON kr.id = krt.key_result_id
            JOIN public.pomodoros_tags pt ON pt.tag = krt.tag_id
            WHERE pt.pomodoro = NEW.id
        LOOP
            IF v_kr.metric_type = 'COUNT_ATOMIC' THEN
                -- In a pomodoro finish, COUNT_ATOMIC counts as 1 per pomodoro finish
                -- Only if it actually did something (e.g. at least 1 minute or whatever the rule is)
                -- Usually, if it's finished, it counts.
                UPDATE public.key_results 
                SET current_value = current_value + (1 * v_kr.weight)
                WHERE id = v_kr.id;
            ELSIF v_kr.metric_type = 'TIME_INVESTMENT' AND v_minutes_invested > 0 THEN
                -- Sumamos minutos íntegros multiplicado por el peso del tag
                UPDATE public.key_results 
                SET current_value = current_value + (v_minutes_invested * v_kr.weight)
                WHERE id = v_kr.id;
            END IF;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$function$
;


  create policy "Users can manage own flows"
  on "public"."flows"
  as permissive
  for all
  to public
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "Users can manage own time_sessions"
  on "public"."time_sessions"
  as permissive
  for all
  to public
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "Allow broadcasting presences on all channels for authenticated"
  on "realtime"."messages"
  as permissive
  for insert
  to authenticated
with check ((extension = 'presence'::text));


CREATE TRIGGER protect_buckets_delete BEFORE DELETE ON storage.buckets FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();

CREATE TRIGGER protect_objects_delete BEFORE DELETE ON storage.objects FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();


