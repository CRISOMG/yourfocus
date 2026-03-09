create extension if not exists "pg_jsonschema" with schema "extensions";

create type "public"."metric_category" as enum ('COUNT_ATOMIC', 'TIME_INVESTMENT', 'KNOWLEDGE_DENSITY', 'QUALITY_SCORE');

drop trigger if exists "tr_carry_over_keep_tasks" on "public"."pomodoros";

drop trigger if exists "trigger_handle_enqueue_pomodoro_finished_webhook" on "public"."pomodoros";

drop trigger if exists "trigger_push_on_pomodoro_finished" on "public"."pomodoros";

drop trigger if exists "tr_sync_task_keep" on "public"."tasks";

drop trigger if exists "trigger_task_done_webhook" on "public"."tasks";

drop policy "Users can insert their own chat messages" on "public"."n8n_chat_histories";

drop policy "Users can view their own chat messages" on "public"."n8n_chat_histories";

drop policy "Enable insert for authenticated users only" on "public"."pomodoros_cycles";

drop policy "Enable insert for authenticated users only" on "public"."pomodoros_tags";

drop policy "Users can delete their own pomodoro tasks" on "public"."pomodoros_tasks";

drop policy "Users can insert their own pomodoro tasks" on "public"."pomodoros_tasks";

drop policy "Users can view their own pomodoro tasks" on "public"."pomodoros_tasks";

drop policy "Users can manage own push subscriptions" on "public"."push_subscriptions";

drop policy "Enable insert for own tags" on "public"."tags";

drop policy "Enable read access for own tags" on "public"."tags";

drop policy "Enable delete for users based on user_id" on "public"."pomodoros";

drop policy "Enable insert for users based on user_id" on "public"."pomodoros";

drop policy "Enable users to edit their own data only" on "public"."pomodoros";

drop policy "Enable users to update their own data only" on "public"."pomodoros_cycles";

drop policy "Enable delete for users based on user_id" on "public"."pomodoros_tags";

drop policy "Users can manage their own scheduled notifications" on "public"."scheduled_notifications";

drop policy "Enable delete for users based on user_id" on "public"."tasks_tags";

drop policy "Enable insert for users based on user_id" on "public"."tasks_tags";

drop policy "Enable users and PAT to view tasks_tags" on "public"."tasks_tags";

revoke delete on table "public"."pomodoros_tasks" from "anon";

revoke insert on table "public"."pomodoros_tasks" from "anon";

revoke references on table "public"."pomodoros_tasks" from "anon";

revoke select on table "public"."pomodoros_tasks" from "anon";

revoke trigger on table "public"."pomodoros_tasks" from "anon";

revoke truncate on table "public"."pomodoros_tasks" from "anon";

revoke update on table "public"."pomodoros_tasks" from "anon";

revoke delete on table "public"."pomodoros_tasks" from "authenticated";

revoke insert on table "public"."pomodoros_tasks" from "authenticated";

revoke references on table "public"."pomodoros_tasks" from "authenticated";

revoke select on table "public"."pomodoros_tasks" from "authenticated";

revoke trigger on table "public"."pomodoros_tasks" from "authenticated";

revoke truncate on table "public"."pomodoros_tasks" from "authenticated";

revoke update on table "public"."pomodoros_tasks" from "authenticated";

revoke delete on table "public"."pomodoros_tasks" from "service_role";

revoke insert on table "public"."pomodoros_tasks" from "service_role";

revoke references on table "public"."pomodoros_tasks" from "service_role";

revoke select on table "public"."pomodoros_tasks" from "service_role";

revoke trigger on table "public"."pomodoros_tasks" from "service_role";

revoke truncate on table "public"."pomodoros_tasks" from "service_role";

revoke update on table "public"."pomodoros_tasks" from "service_role";

alter table "public"."pomodoros" drop constraint "pomodoros_time_session_id_fkey";

alter table "public"."pomodoros_tasks" drop constraint "pomodoros_tasks_pomodoro_id_fkey";

alter table "public"."pomodoros_tasks" drop constraint "pomodoros_tasks_pomodoro_id_task_id_key";

alter table "public"."pomodoros_tasks" drop constraint "pomodoros_tasks_task_id_fkey";

alter table "public"."pomodoros_tasks" drop constraint "pomodoros_tasks_user_id_fkey";

alter table "public"."push_subscriptions" drop constraint "push_subscriptions_user_id_subscription_key";

alter table "public"."api_keys" drop constraint "api_keys_user_id_fkey";

alter table "public"."pomodoros_cycles" drop constraint "pomodoros_cycles_user_id_fkey";

alter table "public"."pomodoros_tags" drop constraint "pomodoros_tags_user_id_fkey";

alter table "public"."profiles" drop constraint "profiles_id_fkey";

alter table "public"."tasks" drop constraint "tasks_user_id_fkey";

alter table "public"."tasks_tags" drop constraint "tasks_tags_user_id_fkey";

alter table "public"."webhook_trace" drop constraint "webhook_trace_user_id_fkey";

drop function if exists "public"."calculate_pomodoro_timelapse_sql"(p_started_at timestamp with time zone, p_toggle_timeline jsonb, p_now timestamp with time zone);

drop function if exists "public"."carry_over_keep_tasks"();

drop function if exists "public"."handle_task_done_webhook"();

drop function if exists "public"."sync_task_keep_to_current_pomodoro"();

alter table "public"."pomodoros_tasks" drop constraint "pomodoros_tasks_pkey";

drop index if exists "public"."idx_pomodoros_tasks_task_id";

drop index if exists "public"."idx_pomodoros_tasks_user_id";

drop index if exists "public"."pomodoros_tasks_pkey";

drop index if exists "public"."pomodoros_tasks_pomodoro_id_task_id_key";

drop index if exists "public"."idx_user_secrets_unique_name";

drop table "public"."pomodoros_tasks";

alter table "public"."pomodoros" alter column "state" drop default;

alter table "public"."pomodoros" alter column "type" drop default;

alter type "public"."pomodoro_type" rename to "pomodoro_type__old_version_to_be_dropped";

create type "public"."pomodoro_type" as enum ('focus', 'break', 'long_break');


  create table "public"."key_result_tags" (
    "id" uuid not null default gen_random_uuid(),
    "key_result_id" uuid not null,
    "tag_id" bigint not null,
    "weight" numeric not null default 1.0,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."key_result_tags" enable row level security;


  create table "public"."key_results" (
    "id" uuid not null default gen_random_uuid(),
    "objective_id" uuid not null,
    "title" text not null,
    "target_value" numeric not null,
    "current_value" numeric not null default 0,
    "metric_type" public.metric_category not null,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."key_results" enable row level security;


  create table "public"."notes" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "storage_path" text not null,
    "title" text,
    "frontmatter" jsonb,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."notes" enable row level security;


  create table "public"."notes_tags" (
    "note_id" uuid not null,
    "tag_id" bigint not null,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."notes_tags" enable row level security;


  create table "public"."objectives" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "title" text not null,
    "description" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."objectives" enable row level security;

drop trigger if exists "trigger_sync_pomodoro_expected_end" on "public"."pomodoros";

alter table "public"."pomodoros" alter column state type "public"."pomodoro_state" using state::text::"public"."pomodoro_state";

alter table "public"."pomodoros" alter column type type "public"."pomodoro_type" using type::text::"public"."pomodoro_type";

alter table "public"."pomodoros" alter column "state" set default 'paused'::public.pomodoro_state;

alter table "public"."pomodoros" alter column "type" set default 'focus'::public.pomodoro_type;

CREATE OR REPLACE TRIGGER "trigger_sync_pomodoro_expected_end" BEFORE INSERT OR UPDATE OF "state", "toggle_timeline", "expected_duration" ON "public"."pomodoros" FOR EACH ROW EXECUTE FUNCTION "public"."sync_pomodoro_expected_end"();

drop type "public"."pomodoro_type__old_version_to_be_dropped";

alter table "public"."documents" alter column "id" drop default;

alter table "public"."documents" alter column "id" add generated by default as identity;

alter table "public"."n8n_chat_histories" alter column "id" drop default;

alter table "public"."n8n_chat_histories" alter column "id" add generated by default as identity;

alter table "public"."n8n_chat_histories" disable row level security;

alter table "public"."pomodoros" alter column "state" set default 'idle'::public.pomodoro_state;

alter table "public"."pomodoros_cycles" alter column "required_tags" set default '{focus,break,focus,long_break}'::text[];

alter table "public"."push_subscriptions" add column "user_agent" text;

alter table "public"."push_subscriptions" alter column "created_at" set not null;

-- Safely convert to JSONB, setting invalid text to NULL
update "public"."push_subscriptions" 
set "device_info" = null 
where "device_info" is not null and "device_info" not like '{%';

alter table "public"."push_subscriptions" alter column "device_info" set data type jsonb using "device_info"::jsonb;

alter table "public"."tasks" add column "estimated_pomodoros" integer default 1;

alter table "public"."user_secrets" alter column "created_at" set not null;

alter table "public"."user_secrets" alter column "is_active" set not null;

alter table "public"."user_secrets" alter column "updated_at" set not null;

alter table "public"."user_secrets" alter column "user_id" set not null;

drop sequence if exists "public"."documents_id_seq";

drop sequence if exists "public"."n8n_chat_histories_id_seq";

CREATE INDEX idx_webhook_trace_msg_id ON public.webhook_trace USING btree (pgmq_msg_id);

CREATE UNIQUE INDEX key_result_tags_key_result_id_tag_id_key ON public.key_result_tags USING btree (key_result_id, tag_id);

CREATE UNIQUE INDEX key_result_tags_pkey ON public.key_result_tags USING btree (id);

CREATE UNIQUE INDEX key_results_pkey ON public.key_results USING btree (id);

CREATE UNIQUE INDEX notes_pkey ON public.notes USING btree (id);

CREATE UNIQUE INDEX notes_tags_pkey ON public.notes_tags USING btree (note_id, tag_id);

CREATE UNIQUE INDEX notes_user_id_storage_path_key ON public.notes USING btree (user_id, storage_path);

CREATE UNIQUE INDEX objectives_pkey ON public.objectives USING btree (id);

CREATE UNIQUE INDEX profiles_username_idx ON public.profiles USING btree (username);

CREATE UNIQUE INDEX user_secrets_user_id_name_key ON public.user_secrets USING btree (user_id, name);

CREATE UNIQUE INDEX idx_user_secrets_unique_name ON public.user_secrets USING btree (user_id, name);

alter table "public"."key_result_tags" add constraint "key_result_tags_pkey" PRIMARY KEY using index "key_result_tags_pkey";

alter table "public"."key_results" add constraint "key_results_pkey" PRIMARY KEY using index "key_results_pkey";

alter table "public"."notes" add constraint "notes_pkey" PRIMARY KEY using index "notes_pkey";

alter table "public"."notes_tags" add constraint "notes_tags_pkey" PRIMARY KEY using index "notes_tags_pkey";

alter table "public"."objectives" add constraint "objectives_pkey" PRIMARY KEY using index "objectives_pkey";

alter table "public"."key_result_tags" add constraint "key_result_tags_key_result_id_fkey" FOREIGN KEY (key_result_id) REFERENCES public.key_results(id) ON DELETE CASCADE not valid;

alter table "public"."key_result_tags" validate constraint "key_result_tags_key_result_id_fkey";

alter table "public"."key_result_tags" add constraint "key_result_tags_key_result_id_tag_id_key" UNIQUE using index "key_result_tags_key_result_id_tag_id_key";

alter table "public"."key_result_tags" add constraint "key_result_tags_tag_id_fkey" FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE not valid;

alter table "public"."key_result_tags" validate constraint "key_result_tags_tag_id_fkey";

alter table "public"."key_results" add constraint "key_results_objective_id_fkey" FOREIGN KEY (objective_id) REFERENCES public.objectives(id) ON DELETE CASCADE not valid;

alter table "public"."key_results" validate constraint "key_results_objective_id_fkey";

alter table "public"."notes" add constraint "notes_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."notes" validate constraint "notes_user_id_fkey";

alter table "public"."notes" add constraint "notes_user_id_storage_path_key" UNIQUE using index "notes_user_id_storage_path_key";

alter table "public"."notes_tags" add constraint "notes_tags_note_id_fkey" FOREIGN KEY (note_id) REFERENCES public.notes(id) ON DELETE CASCADE not valid;

alter table "public"."notes_tags" validate constraint "notes_tags_note_id_fkey";

alter table "public"."notes_tags" add constraint "notes_tags_tag_id_fkey" FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE not valid;

alter table "public"."notes_tags" validate constraint "notes_tags_tag_id_fkey";

alter table "public"."objectives" add constraint "objectives_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."objectives" validate constraint "objectives_user_id_fkey";

alter table "public"."user_secrets" add constraint "user_secrets_user_id_name_key" UNIQUE using index "user_secrets_user_id_name_key";

alter table "public"."api_keys" add constraint "api_keys_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) not valid;

alter table "public"."api_keys" validate constraint "api_keys_user_id_fkey";

alter table "public"."pomodoros_cycles" add constraint "pomodoros_cycles_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) not valid;

alter table "public"."pomodoros_cycles" validate constraint "pomodoros_cycles_user_id_fkey";

alter table "public"."pomodoros_tags" add constraint "pomodoros_tags_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) not valid;

alter table "public"."pomodoros_tags" validate constraint "pomodoros_tags_user_id_fkey";

alter table "public"."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) not valid;

alter table "public"."profiles" validate constraint "profiles_id_fkey";

alter table "public"."tasks" add constraint "tasks_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) not valid;

alter table "public"."tasks" validate constraint "tasks_user_id_fkey";

alter table "public"."tasks_tags" add constraint "tasks_tags_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) not valid;

alter table "public"."tasks_tags" validate constraint "tasks_tags_user_id_fkey";

alter table "public"."webhook_trace" add constraint "webhook_trace_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) not valid;

alter table "public"."webhook_trace" validate constraint "webhook_trace_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.calculate_kr_progress_on_note_tag()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_kr RECORD;
    v_user_id uuid;
BEGIN
    SELECT user_id INTO v_user_id FROM public.notes WHERE id = NEW.note_id;

    FOR v_kr IN
        SELECT kr.id, krt.weight
        FROM public.key_results kr
        JOIN public.objectives o ON kr.objective_id = o.id
        JOIN public.key_result_tags krt ON kr.id = krt.key_result_id
        WHERE o.user_id = v_user_id
          AND krt.tag_id = NEW.tag_id
          AND kr.metric_type = 'KNOWLEDGE_DENSITY'
    LOOP
        UPDATE public.key_results 
        SET current_value = current_value + (1 * v_kr.weight)
        WHERE id = v_kr.id;
    END LOOP;
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.calculate_kr_progress_on_pomodoro_finish()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_kr RECORD;
BEGIN
    IF NEW.state = 'finished' AND (OLD.state IS NULL OR OLD.state != 'finished') THEN
        FOR v_kr IN
            SELECT kr.id, krt.weight, kr.metric_type
            FROM public.key_results kr
            JOIN public.objectives o ON kr.objective_id = o.id
            JOIN public.key_result_tags krt ON kr.id = krt.key_result_id
            JOIN public.pomodoros_tags pt ON pt.tag = krt.tag_id
            WHERE o.user_id = NEW.user_id
              AND pt.pomodoro = NEW.id
        LOOP
            IF v_kr.metric_type = 'COUNT_ATOMIC' THEN
                UPDATE public.key_results 
                SET current_value = current_value + (1 * v_kr.weight)
                WHERE id = v_kr.id;
            ELSIF v_kr.metric_type = 'TIME_INVESTMENT' THEN
                UPDATE public.key_results 
                SET current_value = current_value + ((NEW.timelapse::numeric / 60.0) * v_kr.weight)
                WHERE id = v_kr.id;
            END IF;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.enqueue_webhook(p_user_id uuid, p_event_type text, p_payload jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pgmq', 'extensions'
AS $function$
DECLARE
    v_webhook_url text;
BEGIN
    -- Get user webhook URL
    SELECT settings->>'webhook_url' INTO v_webhook_url
    FROM public.profiles
    WHERE id = p_user_id;

    -- If valid URL, enqueue message
    IF v_webhook_url IS NOT NULL AND v_webhook_url <> '' THEN
        PERFORM pgmq.send(
            'pomodoro_webhooks',
            jsonb_build_object(
                'url', v_webhook_url,
                'event', p_event_type,
                'payload', p_payload,
                'timestamp', now()
            )
        );
    END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_enqueue_task_done_webhook()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pgmq', 'extensions'
AS $function$
DECLARE
  v_tag jsonb;
BEGIN
    -- Only trigger when done status changes from false (or null) to true
    IF (OLD.done IS DISTINCT FROM true AND NEW.done = true) THEN
        
        -- Fetch tag if exists
        IF NEW.tag_id IS NOT NULL THEN
            SELECT jsonb_build_object('id', t.id, 'label', t.label, 'type', t.type)
            INTO v_tag
            FROM public.tags t
            WHERE t.id = NEW.tag_id;
        END IF;

        PERFORM public.enqueue_webhook(
            NEW.user_id,
            'task.done',
            jsonb_build_object(
                'id', NEW.id,
                'title', NEW.title,
                'description', NEW.description,
                'user_id', NEW.user_id,
                'done_at', NEW.done_at,
                'created_at', NEW.created_at,
                'tag', v_tag
            )
        );
    END IF;
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.calculate_pomodoro_timelapse_sql(p_started_at timestamp with time zone, p_toggle_timeline jsonb, p_expected_duration integer, p_now timestamp with time zone DEFAULT now())
 RETURNS double precision
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
DECLARE
    v_elapsed_decimal double precision := 0;
    v_current_segment_start timestamptz := p_started_at;
    v_is_running boolean := true;
    v_event record;
BEGIN
    -- Si no hay timeline, ha estado corriendo desde started_at
    IF p_toggle_timeline IS NULL OR jsonb_array_length(p_toggle_timeline) = 0 THEN
        -- Usar GREATEST por si acaso p_now < p_started_at (relojes desincronizados)
        RETURN LEAST(floor(GREATEST(0, extract(epoch from (p_now - p_started_at)))), p_expected_duration::double precision);
    END IF;
    FOR v_event IN 
        SELECT (value->>'at')::timestamptz as at, (value->>'type') as type
        FROM jsonb_array_elements(p_toggle_timeline)
        ORDER BY (value->>'at')::timestamptz ASC
    LOOP
        IF (v_event.type = 'pause' OR v_event.type = 'finish') AND v_is_running THEN
            -- GREATEST(0, ...) equivale a Math.max(0, ...)
            v_elapsed_decimal := v_elapsed_decimal + GREATEST(0, extract(epoch from (v_event.at - v_current_segment_start)));
            v_is_running := false;
        ELSIF (v_event.type = 'play' OR v_event.type = 'start') AND NOT v_is_running THEN
            v_current_segment_start := v_event.at;
            v_is_running := true;
        END IF;
    END LOOP;
    -- Añadir segmento actual si sigue corriendo
    IF v_is_running THEN
        v_elapsed_decimal := v_elapsed_decimal + GREATEST(0, extract(epoch from (p_now - v_current_segment_start)));
    END IF;
    RETURN LEAST(v_elapsed_decimal, p_expected_duration::double precision);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_enqueue_pomodoro_finished_webhook()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pgmq', 'extensions'
AS $function$
DECLARE
  v_tags jsonb;
BEGIN
    -- Check for state change to 'finished'
    IF (OLD.state IS DISTINCT FROM 'finished' AND NEW.state = 'finished') THEN
        
        -- Fetch tags associated with the pomodoro
        SELECT jsonb_agg(jsonb_build_object('id', t.id, 'label', t.label, 'type', t.type))
        INTO v_tags
        FROM public.pomodoros_tags pt
        JOIN public.tags t ON pt.tag = t.id
        WHERE pt.pomodoro = NEW.id;

        PERFORM public.enqueue_webhook(
            NEW.user_id,
            'pomodoro.finished',
            jsonb_build_object(
                'id', NEW.id,
                'type', NEW.type,
                'duration', NEW.expected_duration,
                'started_at', NEW.started_at,
                'finished_at', NEW.finished_at,
                'user_id', NEW.user_id,
                'tags', COALESCE(v_tags, '[]'::jsonb)
            )
        );
    END IF;
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_user_password_update()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE public.profiles SET has_password = (NEW.encrypted_password IS NOT NULL) WHERE id = NEW.id;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.match_documents(query_embedding extensions.vector, match_count integer DEFAULT 10, filter jsonb DEFAULT '{}'::jsonb)
 RETURNS TABLE(id bigint, content text, metadata jsonb, similarity double precision)
 LANGUAGE plpgsql
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN QUERY
  SELECT documents.id, documents.content, documents.metadata, 1 - (documents.embedding <=> query_embedding) AS similarity
  FROM documents WHERE documents.metadata @> filter ORDER BY documents.embedding <=> query_embedding LIMIT match_count;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.supabase_url()
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
SELECT current_setting('request.base_url', true);
$function$
;

CREATE OR REPLACE FUNCTION public.sync_pomodoro_expected_end()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
    DECLARE
        v_duration integer;
        v_timelapse double precision;
        v_remaining_seconds double precision;
    BEGIN
        -- Only update if state is current or paused
        IF NEW.state = 'finished' THEN
            RETURN NEW;
        END IF;

        v_duration := NEW.expected_duration;
        
        -- Calculate timelapse until "now" (the moment of update)
        v_timelapse := public.calculate_pomodoro_timelapse_sql(NEW.started_at, NEW.toggle_timeline, v_duration, now());
        v_remaining_seconds := v_duration - v_timelapse;


        -- Set expected_end based on remaining time
        IF NEW.state = 'current' THEN
            NEW.expected_end := now() + (v_remaining_seconds || ' seconds')::interval;
        ELSE
            -- If paused, expected_end is essentially "infinity" or just stay as is, 
            -- but for logic clarity, we set it far in the future or keep it stable.
            -- Actually, if paused, it won't expire.
            NEW.expected_end := NULL; 
        END IF;

        NEW.timelapse := LEAST(ROUND(v_timelapse), 32767)::smallint;
        
        RETURN NEW;
    END;
    $function$
;

CREATE OR REPLACE FUNCTION public.trigger_send_push_on_pomodoro_finished()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  service_key text;
begin
  -- Solo disparar cuando el estado cambia a 'finished'
  if NEW.state = 'finished' and (OLD.state is null or OLD.state != 'finished') then
    
    -- Obtener service_role_key del vault
    select decrypted_secret into service_key
    from vault.decrypted_secrets
    where name = 'service_role_key'
    limit 1;
    
    -- Si no hay key configurada, salir silenciosamente
    if service_key is null then
      raise warning 'service_role_key not found in vault. Push notification not sent.';
      return NEW;
    end if;
    
    perform net.http_post(
      url := supabase_url() || '/functions/v1/send-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_key
      ),
      body := jsonb_build_object(
        'type', 'UPDATE',
        'user_id', NEW.user_id,
        'table', 'pomodoros',
        'notification', jsonb_build_object(
          'title', '🍅 Pomodoro terminado!',
          'body', 'Tu sesión de ' || NEW.type || ' ha finalizado.',
          'icon', '/favicon.ico',
          'url', '/'
        ),
        'record', jsonb_build_object(
          'id', NEW.id,
          'user_id', NEW.user_id,
          'state', NEW.state,
          'expected_duration', NEW.expected_duration,
          'type', NEW.type
        )
      )
    );
  end if;
  
  return NEW;
end;
$function$
;

grant delete on table "public"."key_result_tags" to "anon";

grant insert on table "public"."key_result_tags" to "anon";

grant references on table "public"."key_result_tags" to "anon";

grant select on table "public"."key_result_tags" to "anon";

grant trigger on table "public"."key_result_tags" to "anon";

grant truncate on table "public"."key_result_tags" to "anon";

grant update on table "public"."key_result_tags" to "anon";

grant delete on table "public"."key_result_tags" to "authenticated";

grant insert on table "public"."key_result_tags" to "authenticated";

grant references on table "public"."key_result_tags" to "authenticated";

grant select on table "public"."key_result_tags" to "authenticated";

grant trigger on table "public"."key_result_tags" to "authenticated";

grant truncate on table "public"."key_result_tags" to "authenticated";

grant update on table "public"."key_result_tags" to "authenticated";

grant delete on table "public"."key_result_tags" to "service_role";

grant insert on table "public"."key_result_tags" to "service_role";

grant references on table "public"."key_result_tags" to "service_role";

grant select on table "public"."key_result_tags" to "service_role";

grant trigger on table "public"."key_result_tags" to "service_role";

grant truncate on table "public"."key_result_tags" to "service_role";

grant update on table "public"."key_result_tags" to "service_role";

grant delete on table "public"."key_results" to "anon";

grant insert on table "public"."key_results" to "anon";

grant references on table "public"."key_results" to "anon";

grant select on table "public"."key_results" to "anon";

grant trigger on table "public"."key_results" to "anon";

grant truncate on table "public"."key_results" to "anon";

grant update on table "public"."key_results" to "anon";

grant delete on table "public"."key_results" to "authenticated";

grant insert on table "public"."key_results" to "authenticated";

grant references on table "public"."key_results" to "authenticated";

grant select on table "public"."key_results" to "authenticated";

grant trigger on table "public"."key_results" to "authenticated";

grant truncate on table "public"."key_results" to "authenticated";

grant update on table "public"."key_results" to "authenticated";

grant delete on table "public"."key_results" to "service_role";

grant insert on table "public"."key_results" to "service_role";

grant references on table "public"."key_results" to "service_role";

grant select on table "public"."key_results" to "service_role";

grant trigger on table "public"."key_results" to "service_role";

grant truncate on table "public"."key_results" to "service_role";

grant update on table "public"."key_results" to "service_role";

grant delete on table "public"."notes" to "anon";

grant insert on table "public"."notes" to "anon";

grant references on table "public"."notes" to "anon";

grant select on table "public"."notes" to "anon";

grant trigger on table "public"."notes" to "anon";

grant truncate on table "public"."notes" to "anon";

grant update on table "public"."notes" to "anon";

grant delete on table "public"."notes" to "authenticated";

grant insert on table "public"."notes" to "authenticated";

grant references on table "public"."notes" to "authenticated";

grant select on table "public"."notes" to "authenticated";

grant trigger on table "public"."notes" to "authenticated";

grant truncate on table "public"."notes" to "authenticated";

grant update on table "public"."notes" to "authenticated";

grant delete on table "public"."notes" to "service_role";

grant insert on table "public"."notes" to "service_role";

grant references on table "public"."notes" to "service_role";

grant select on table "public"."notes" to "service_role";

grant trigger on table "public"."notes" to "service_role";

grant truncate on table "public"."notes" to "service_role";

grant update on table "public"."notes" to "service_role";

grant delete on table "public"."notes_tags" to "anon";

grant insert on table "public"."notes_tags" to "anon";

grant references on table "public"."notes_tags" to "anon";

grant select on table "public"."notes_tags" to "anon";

grant trigger on table "public"."notes_tags" to "anon";

grant truncate on table "public"."notes_tags" to "anon";

grant update on table "public"."notes_tags" to "anon";

grant delete on table "public"."notes_tags" to "authenticated";

grant insert on table "public"."notes_tags" to "authenticated";

grant references on table "public"."notes_tags" to "authenticated";

grant select on table "public"."notes_tags" to "authenticated";

grant trigger on table "public"."notes_tags" to "authenticated";

grant truncate on table "public"."notes_tags" to "authenticated";

grant update on table "public"."notes_tags" to "authenticated";

grant delete on table "public"."notes_tags" to "service_role";

grant insert on table "public"."notes_tags" to "service_role";

grant references on table "public"."notes_tags" to "service_role";

grant select on table "public"."notes_tags" to "service_role";

grant trigger on table "public"."notes_tags" to "service_role";

grant truncate on table "public"."notes_tags" to "service_role";

grant update on table "public"."notes_tags" to "service_role";

grant delete on table "public"."objectives" to "anon";

grant insert on table "public"."objectives" to "anon";

grant references on table "public"."objectives" to "anon";

grant select on table "public"."objectives" to "anon";

grant trigger on table "public"."objectives" to "anon";

grant truncate on table "public"."objectives" to "anon";

grant update on table "public"."objectives" to "anon";

grant delete on table "public"."objectives" to "authenticated";

grant insert on table "public"."objectives" to "authenticated";

grant references on table "public"."objectives" to "authenticated";

grant select on table "public"."objectives" to "authenticated";

grant trigger on table "public"."objectives" to "authenticated";

grant truncate on table "public"."objectives" to "authenticated";

grant update on table "public"."objectives" to "authenticated";

grant delete on table "public"."objectives" to "service_role";

grant insert on table "public"."objectives" to "service_role";

grant references on table "public"."objectives" to "service_role";

grant select on table "public"."objectives" to "service_role";

grant trigger on table "public"."objectives" to "service_role";

grant truncate on table "public"."objectives" to "service_role";

grant update on table "public"."objectives" to "service_role";


  create policy "Users can manage tags of their key_results"
  on "public"."key_result_tags"
  as permissive
  for all
  to authenticated
using ((key_result_id IN ( SELECT key_results.id
   FROM public.key_results
  WHERE (key_results.objective_id IN ( SELECT objectives.id
           FROM public.objectives
          WHERE (objectives.user_id = ( SELECT auth.uid() AS uid)))))))
with check ((key_result_id IN ( SELECT key_results.id
   FROM public.key_results
  WHERE (key_results.objective_id IN ( SELECT objectives.id
           FROM public.objectives
          WHERE (objectives.user_id = ( SELECT auth.uid() AS uid)))))));



  create policy "Users can manage key_results of their objectives"
  on "public"."key_results"
  as permissive
  for all
  to authenticated
using ((objective_id IN ( SELECT objectives.id
   FROM public.objectives
  WHERE (objectives.user_id = ( SELECT auth.uid() AS uid)))))
with check ((objective_id IN ( SELECT objectives.id
   FROM public.objectives
  WHERE (objectives.user_id = ( SELECT auth.uid() AS uid)))));



  create policy "Users can manage their own notes"
  on "public"."notes"
  as permissive
  for all
  to authenticated
using ((( SELECT auth.uid() AS uid) = user_id))
with check ((( SELECT auth.uid() AS uid) = user_id));



  create policy "Users can manage tags of their notes"
  on "public"."notes_tags"
  as permissive
  for all
  to authenticated
using ((note_id IN ( SELECT notes.id
   FROM public.notes
  WHERE (notes.user_id = ( SELECT auth.uid() AS uid)))))
with check ((note_id IN ( SELECT notes.id
   FROM public.notes
  WHERE (notes.user_id = ( SELECT auth.uid() AS uid)))));



  create policy "Users can manage their own objectives"
  on "public"."objectives"
  as permissive
  for all
  to authenticated
using ((( SELECT auth.uid() AS uid) = user_id))
with check ((( SELECT auth.uid() AS uid) = user_id));



  create policy "Enable insert for users based on user_id"
  on "public"."pomodoros_tags"
  as permissive
  for insert
  to public
with check ((( SELECT auth.uid() AS uid) = user_id));



  create policy "Users can manage their own push subscriptions"
  on "public"."push_subscriptions"
  as permissive
  for all
  to authenticated
using ((user_id = ( SELECT auth.uid() AS uid)))
with check ((user_id = ( SELECT auth.uid() AS uid)));



  create policy "Enable delete for users based on user_id"
  on "public"."pomodoros"
  as permissive
  for delete
  to public
using ((( SELECT auth.uid() AS uid) = user_id));



  create policy "Enable insert for users based on user_id"
  on "public"."pomodoros"
  as permissive
  for insert
  to public
with check ((( SELECT auth.uid() AS uid) = user_id));



  create policy "Enable users to edit their own data only"
  on "public"."pomodoros"
  as permissive
  for update
  to authenticated
using ((( SELECT auth.uid() AS uid) = user_id));



  create policy "Enable users to update their own data only"
  on "public"."pomodoros_cycles"
  as permissive
  for update
  to authenticated
using ((( SELECT auth.uid() AS uid) = user_id));



  create policy "Enable delete for users based on user_id"
  on "public"."pomodoros_tags"
  as permissive
  for delete
  to public
using ((( SELECT auth.uid() AS uid) = user_id));



  create policy "Users can manage their own scheduled notifications"
  on "public"."scheduled_notifications"
  as permissive
  for all
  to authenticated
using ((user_id = ( SELECT auth.uid() AS uid)))
with check ((user_id = ( SELECT auth.uid() AS uid)));



  create policy "Enable delete for users based on user_id"
  on "public"."tasks_tags"
  as permissive
  for delete
  to public
using ((( SELECT auth.uid() AS uid) = user_id));



  create policy "Enable insert for users based on user_id"
  on "public"."tasks_tags"
  as permissive
  for insert
  to public
with check ((( SELECT auth.uid() AS uid) = user_id));



  create policy "Enable users and PAT to view tasks_tags"
  on "public"."tasks_tags"
  as permissive
  for select
  to authenticated
using (((( SELECT auth.uid() AS uid) = user_id) AND public.is_valid_personal_access_token()));


CREATE TRIGGER tr_calculate_kr_progress_on_note_tag AFTER INSERT ON public.notes_tags FOR EACH ROW EXECUTE FUNCTION public.calculate_kr_progress_on_note_tag();

CREATE TRIGGER tr_calculate_kr_progress_on_pomodoro_finish AFTER UPDATE OF state ON public.pomodoros FOR EACH ROW EXECUTE FUNCTION public.calculate_kr_progress_on_pomodoro_finish();

CREATE TRIGGER trigger_enqueue_pomodoro_finished_webhook AFTER UPDATE ON public.pomodoros FOR EACH ROW EXECUTE FUNCTION public.handle_enqueue_pomodoro_finished_webhook();

CREATE TRIGGER trigger_enqueue_task_done_webhook AFTER UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.handle_enqueue_task_done_webhook();

drop trigger if exists "on_auth_user_updated_password" on "auth"."users";

CREATE TRIGGER on_auth_user_updated_password AFTER UPDATE OF encrypted_password ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_user_password_update();


drop policy if exists "Allow access to own pomodoro sync channel" on "realtime"."messages";

create policy "Allow access to own pomodoro sync channel"
  on "realtime"."messages"
  as permissive
  for all
  to public
using (((( SELECT auth.role() AS role) = 'authenticated'::text) AND (realtime.topic() = ('pomodoro_sync:'::text || (( SELECT auth.uid() AS uid))::text))));



drop policy if exists "Allow broadcasting presences on all channels for authenticated " on "realtime"."messages";

create policy "Allow broadcasting presences on all channels for authenticated "
  on "realtime"."messages"
  as permissive
  for insert
  to authenticated
with check ((extension = 'presence'::text));



drop policy if exists "Allow listening for presences from a pomodoro_sync" on "realtime"."messages";

create policy "Allow listening for presences from a pomodoro_sync"
  on "realtime"."messages"
  as permissive
  for select
  to public
using (((extension = 'presence'::text) AND (realtime.topic() = ('pomodoro_sync:'::text || (( SELECT auth.uid() AS uid))::text))));



drop policy if exists "Allow listening for presences on all channels for authenticated" on "realtime"."messages";

create policy "Allow listening for presences on all channels for authenticated"
  on "realtime"."messages"
  as permissive
  for select
  to authenticated
using ((extension = 'presence'::text));



drop policy if exists "Publish presence to a specific channel" on "realtime"."messages";

create policy "Publish presence to a specific channel"
  on "realtime"."messages"
  as permissive
  for insert
  to public
with check (((extension = 'presence'::text) AND (realtime.topic() = ('pomodoro_sync:'::text || (( SELECT auth.uid() AS uid))::text))));



  create policy "Allow authenticated user to insert their avatar"
  on "storage"."objects"
  as permissive
  for insert
  to authenticated
with check (((bucket_id = 'avatars'::text) AND ((auth.uid())::text = split_part(name, '/'::text, 1))));



  create policy "Allow authenticated user to select their avatar"
  on "storage"."objects"
  as permissive
  for select
  to authenticated
using (((bucket_id = 'avatars'::text) AND ((auth.uid())::text = split_part(name, '/'::text, 1))));



  create policy "Avatar Delete User"
  on "storage"."objects"
  as permissive
  for delete
  to authenticated
using (((bucket_id = 'avatars'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));



  create policy "Avatar Public Read"
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'avatars'::text));



  create policy "Avatar Update User"
  on "storage"."objects"
  as permissive
  for update
  to authenticated
using (((bucket_id = 'avatars'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));



  create policy "Avatar Upload User"
  on "storage"."objects"
  as permissive
  for insert
  to authenticated
with check (((bucket_id = 'avatars'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));



  create policy "Avatars are viewable by everyone"
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'avatars'::text));



