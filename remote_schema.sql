


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgmq";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "extensions";






CREATE TYPE "public"."pomodoro_state" AS ENUM (
    'current',
    'paused',
    'finished',
    'skipped',
    'idle'
);


ALTER TYPE "public"."pomodoro_state" OWNER TO "postgres";


CREATE TYPE "public"."pomodoro_type" AS ENUM (
    'focus',
    'break',
    'long_break'
);


ALTER TYPE "public"."pomodoro_type" OWNER TO "postgres";


CREATE TYPE "public"."task_stage" AS ENUM (
    'backlog',
    'to_do',
    'in_progress',
    'done',
    'archived'
);


ALTER TYPE "public"."task_stage" OWNER TO "postgres";


CREATE TYPE "public"."time_measurement_mode" AS ENUM (
    'pomodoro',
    'flow'
);


ALTER TYPE "public"."time_measurement_mode" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."auto_finish_expired_pomodoros"() RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
    UPDATE public.pomodoros
    SET 
        state = 'finished',
        finished_at = now(),
        timelapse = expected_duration -- Assume it finished completely
    WHERE 
        state = 'current' 
        AND expected_end IS NOT NULL
        AND expected_end < now();
END;
$$;


ALTER FUNCTION "public"."auto_finish_expired_pomodoros"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_pomodoro_timelapse_sql"("p_started_at" timestamp with time zone, "p_toggle_timeline" "jsonb", "p_now" timestamp with time zone DEFAULT "now"()) RETURNS integer
    LANGUAGE "plpgsql" IMMUTABLE
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_elapsed_decimal double precision := 0;
    v_current_segment_start timestamptz := p_started_at;
    v_is_running boolean := true;
    v_event record;
BEGIN
    -- Si no hay timeline, ha estado corriendo desde started_at
    IF p_toggle_timeline IS NULL OR jsonb_array_length(p_toggle_timeline) = 0 THEN
        -- Usar GREATEST por si acaso p_now < p_started_at (relojes desincronizados)
        RETURN floor(GREATEST(0, extract(epoch from (p_now - p_started_at))));
    END IF;
    FOR v_event IN 
        SELECT (value->>'at')::timestamptz as at, (value->>'type') as type
        FROM jsonb_array_elements(p_toggle_timeline)
        ORDER BY (value->>'at')::timestamptz ASC
    LOOP
        IF v_event.type = 'pause' AND v_is_running THEN
            -- GREATEST(0, ...) equivale a Math.max(0, ...)
            v_elapsed_decimal := v_elapsed_decimal + GREATEST(0, extract(epoch from (v_event.at - v_current_segment_start)));
            v_is_running := false;
        ELSIF v_event.type = 'play' AND NOT v_is_running THEN
            v_current_segment_start := v_event.at;
            v_is_running := true;
        END IF;
    END LOOP;
    -- Añadir segmento actual si sigue corriendo
    IF v_is_running THEN
        v_elapsed_decimal := v_elapsed_decimal + GREATEST(0, extract(epoch from (p_now - v_current_segment_start)));
    END IF;
    RETURN floor(v_elapsed_decimal);
END;
$$;


ALTER FUNCTION "public"."calculate_pomodoro_timelapse_sql"("p_started_at" timestamp with time zone, "p_toggle_timeline" "jsonb", "p_now" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_pomodoro_timelapse_sql"("p_started_at" timestamp with time zone, "p_toggle_timeline" "jsonb", "p_expected_duration" integer, "p_now" timestamp with time zone DEFAULT "now"()) RETURNS double precision
    LANGUAGE "plpgsql" IMMUTABLE
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_elapsed_decimal double precision := 0;
    v_current_segment_start timestamptz := p_started_at;
    v_is_running boolean := true;
    v_event record;
BEGIN
    IF p_toggle_timeline IS NULL OR jsonb_array_length(p_toggle_timeline) = 0 THEN
        RETURN LEAST(floor(GREATEST(0, extract(epoch from (p_now - p_started_at)))), p_expected_duration::double precision);
    END IF;
    FOR v_event IN 
        SELECT (value->>'at')::timestamptz as at, (value->>'type') as type
        FROM jsonb_array_elements(p_toggle_timeline)
        ORDER BY (value->>'at')::timestamptz ASC
    LOOP
        IF (v_event.type = 'pause' OR v_event.type = 'finish') AND v_is_running THEN
            v_elapsed_decimal := v_elapsed_decimal + GREATEST(0, extract(epoch from (v_event.at - v_current_segment_start)));
            v_is_running := false;
        ELSIF (v_event.type = 'play' OR v_event.type = 'start') AND NOT v_is_running THEN
            v_current_segment_start := v_event.at;
            v_is_running := true;
        END IF;
    END LOOP;
    IF v_is_running THEN
        v_elapsed_decimal := v_elapsed_decimal + GREATEST(0, extract(epoch from (p_now - v_current_segment_start)));
    END IF;
    RETURN LEAST(v_elapsed_decimal, p_expected_duration::double precision);
END;
$$;


ALTER FUNCTION "public"."calculate_pomodoro_timelapse_sql"("p_started_at" timestamp with time zone, "p_toggle_timeline" "jsonb", "p_expected_duration" integer, "p_now" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."carry_over_keep_tasks"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
begin
  insert into public.pomodoros_tasks (pomodoro_id, task_id, user_id)
  select NEW.id, t.id, NEW.user_id
  from public.tasks t
  where t.user_id = NEW.user_id
    and t.keep = true
    and (t.done = false or t.done is null)
    and (t.archived = false or t.archived is null)
  on conflict (pomodoro_id, task_id) do nothing;
  return NEW;
end;
$$;


ALTER FUNCTION "public"."carry_over_keep_tasks"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_enqueue_pomodoro_finished_webhook"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pgmq', 'extensions'
    AS $$
DECLARE
    v_webhook_url text;
BEGIN
    -- Check for state change to 'finished'
    IF (OLD.state IS DISTINCT FROM 'finished' AND NEW.state = 'finished') THEN
        
        -- Get user webhook URL
        SELECT settings->>'webhook_url' INTO v_webhook_url
        FROM public.profiles
        WHERE id = NEW.user_id;

        -- If valid URL, enqueue message
        IF v_webhook_url IS NOT NULL AND v_webhook_url <> '' THEN
            PERFORM pgmq.send(
                'pomodoro_webhooks',
                jsonb_build_object(
                    'url', v_webhook_url,
                    'event', 'pomodoro.finished',
                    'payload', jsonb_build_object(
                        'id', NEW.id,
                        'type', NEW.type,
                        'duration', NEW.expected_duration,
                        'started_at', NEW.started_at,
                        'finished_at', NEW.finished_at,
                        'user_id', NEW.user_id
                    ),
                    'timestamp', now()
                )
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_enqueue_pomodoro_finished_webhook"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  INSERT INTO public.profiles (id, username, fullname, avatar_url, has_password)
  VALUES (
    NEW.id,
    COALESCE(
      NEW.raw_user_meta_data->>'username',
      NEW.raw_user_meta_data->>'email',
      NEW.email
    ),
    COALESCE(
      NEW.raw_user_meta_data->>'fullname',
      NEW.raw_user_meta_data->>'full_name',
      NEW.raw_user_meta_data->>'name'
    ),
    COALESCE(
      NEW.raw_user_meta_data->>'avatar_url',
      NEW.raw_user_meta_data->>'picture',
      NEW.raw_user_meta_data->>'avatar'
    ),
    (NEW.encrypted_password IS NOT NULL)
  );
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_task_done_webhook"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_webhook_url text;
BEGIN
    -- Only trigger when done status changes from false (or null) to true
    IF (OLD.done IS DISTINCT FROM true AND NEW.done = true) THEN
        
        -- Get user's webhook_url from profiles
        SELECT settings->>'webhook_url' INTO v_webhook_url
        FROM public.profiles
        WHERE id = NEW.user_id;

        IF v_webhook_url IS NOT NULL AND v_webhook_url <> '' THEN
            -- Send async webhook using pg_net
            PERFORM net.http_post(
                url := v_webhook_url,
                body := jsonb_build_object(
                    'event', 'task.done',
                    'task', jsonb_build_object(
                        'id', NEW.id,
                        'title', NEW.title,
                        'description', NEW.description,
                        'user_id', NEW.user_id,
                        'done_at', NEW.done_at,
                        'created_at', NEW.created_at
                    )
                ),
                headers := '{"Content-Type": "application/json"}'::jsonb
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_task_done_webhook"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_task_keep_reset"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
begin
  if NEW.done = true or NEW.archived = true then
    NEW.keep = false;
  end if;
  return NEW;
end;
$$;


ALTER FUNCTION "public"."handle_task_keep_reset"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_user_password_update"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  UPDATE public.profiles
  SET has_password = (NEW.encrypted_password IS NOT NULL)
  WHERE id = NEW.id;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_user_password_update"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_valid_personal_access_token"() RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  token_id uuid;
  token_type text;
begin
 -- 1. Extraemos solo el tipo primero (es texto, nunca fallará)
  token_type := (auth.jwt() ->> 'type');

  -- 2. Si NO es un token personal (es null o login normal), salimos rápido.
  -- Esto optimiza rendimiento y evita errores de casting.
  if token_type is null or token_type != 'personal_access_token' then
    return true;
  end if;

  -- 3. Solo ahora, que sabemos que DEBERÍA ser un UUID válido, hacemos la consulta y el casting.
  return exists (
    select 1 from api_keys 
    where id = (auth.jwt() ->> 'jti')::uuid 
    and is_active = true
  );
exception 
  -- 4. Capa extra de seguridad: Si el JTI no es un UUID válido, retornamos false en lugar de romper la app con error 500
  when invalid_text_representation then
    return false;
end;
$$;


ALTER FUNCTION "public"."is_valid_personal_access_token"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."match_documents"("query_embedding" "extensions"."vector", "match_count" integer DEFAULT 10, "filter" "jsonb" DEFAULT '{}'::"jsonb") RETURNS TABLE("id" bigint, "content" "text", "metadata" "jsonb", "similarity" double precision)
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'extensions'
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    documents.id,
    documents.content,
    documents.metadata,
    1 - (documents.embedding <=> query_embedding) AS similarity
  FROM documents
  -- Esta línea permite que n8n aplique filtros si los configuras en el nodo
  WHERE documents.metadata @> filter
  ORDER BY documents.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;


ALTER FUNCTION "public"."match_documents"("query_embedding" "extensions"."vector", "match_count" integer, "filter" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_notifications_worker"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pgmq', 'net', 'extensions'
    AS $$
DECLARE
  msg RECORD;
  v_request_id bigint;
  v_service_key text;
  v_base_url text;
BEGIN
  -- 1. Get Service Role Key from Vault
  SELECT decrypted_secret INTO v_service_key 
  FROM vault.decrypted_secrets 
  WHERE name = 'service_role_key' 
  LIMIT 1;

  -- 2. Get Supabase URL (attempt from setting or fallback)
  v_base_url := public.supabase_url();
  
  -- If running from pg_cron, request.base_url might be null.
  -- In that case, we try to use a custom setting if provided, or raise error.
  IF v_base_url IS NULL OR v_base_url = '' THEN
     v_base_url := current_setting('app.settings.supabase_url', true);
  END IF;

  IF v_service_key IS NULL OR v_base_url IS NULL OR v_base_url = '' THEN
    RAISE WARNING 'Worker missing configuration: base_url or service_key. check vault and settings.';
    RETURN;
  END IF;

  -- 3. Read batch from PGMQ
  FOR msg IN 
    SELECT * FROM pgmq.read('notifications_queue', 60, 50)
  LOOP
    
    -- Send HTTP request to process-notification
    SELECT net.http_post(
        url := v_base_url || '/functions/v1/process-notification',
        body := msg.message,
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || v_service_key
        )
    ) INTO v_request_id;

    -- Archive message immediately after dispatching (fire and forget pattern for the worker)
    PERFORM pgmq.archive('notifications_queue', msg.msg_id);
    
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."process_notifications_worker"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_webhooks"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  msg RECORD;
  new_request_id bigint;
  v_user_id uuid;
BEGIN
  -- Read batch of 500 messages (High throughput)
  -- Visibility Timeout 60s
  FOR msg IN 
    SELECT * FROM pgmq.read('pomodoro_webhooks', 60, 500)
  LOOP
    
    -- Extract User ID from payload for tracing
    -- Payload structure: { "payload": { "user_id": "..." } }
    v_user_id := (msg.message->'payload'->>'user_id')::uuid;

    -- Send POST request
    SELECT net.http_post(
        url := msg.message->>'url',
        body := jsonb_build_object(
            'event', msg.message->>'event',
            'payload', msg.message->'payload'
        ),
        headers := '{"Content-Type": "application/json"}'::jsonb
    ) INTO new_request_id;

    -- Log trace
    INSERT INTO public.webhook_trace (pgmq_msg_id, net_request_id, user_id)
    VALUES (msg.msg_id, new_request_id, v_user_id);

    -- Archive message (Move to _archive table)
    PERFORM pgmq.archive('pomodoro_webhooks', msg.msg_id);
    
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."process_webhooks"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_tasks_done_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.done IS DISTINCT FROM OLD.done THEN
    IF NEW.done = true THEN
      NEW.done_at = now();
    ELSE
      NEW.done_at = NULL;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_tasks_done_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_tasks_done_at_insert"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.done = true THEN
    NEW.done_at = now();
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_tasks_done_at_insert"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."supabase_url"() RETURNS "text"
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public'
    AS $$
  select 'https://meneprjtfpcppidpgava.supabase.co'::text;
$$;


ALTER FUNCTION "public"."supabase_url"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."supabase_url"() IS 'Returns the Supabase project URL';



CREATE OR REPLACE FUNCTION "public"."sync_pomodoro_expected_end"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
    DECLARE
        v_duration integer;
        v_timelapse double precision;
        v_remaining_seconds double precision;
    BEGIN
        IF NEW.state = 'finished' THEN
            RETURN NEW;
        END IF;

        v_duration := NEW.expected_duration;
        
        v_timelapse := public.calculate_pomodoro_timelapse_sql(NEW.started_at, NEW.toggle_timeline, v_duration, now());
        v_remaining_seconds := v_duration - v_timelapse;

        IF NEW.state = 'current' THEN
            NEW.expected_end := now() + (v_remaining_seconds || ' seconds')::interval;
        ELSE
            NEW.expected_end := NULL; 
        END IF;

        NEW.timelapse := ROUND(v_timelapse)::integer;
        
        RETURN NEW;
    END;
    $$;


ALTER FUNCTION "public"."sync_pomodoro_expected_end"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_task_keep_to_current_pomodoro"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
declare
  current_pomodoro_id bigint;
begin
  -- Get the current pomodoro for the user
  select id into current_pomodoro_id
  from public.pomodoros
  where user_id = NEW.user_id 
    and state = 'current'
  limit 1;

  if current_pomodoro_id is not null then
    if NEW.keep = true then
      -- Insert if not exists
      insert into public.pomodoros_tasks (pomodoro_id, task_id, user_id)
      values (current_pomodoro_id, NEW.id, NEW.user_id)
      on conflict (pomodoro_id, task_id) do nothing;
    else
      -- Remove if keep is set to false (unassign)
      delete from public.pomodoros_tasks
      where pomodoro_id = current_pomodoro_id
        and task_id = NEW.id;
    end if;
  end if;

  return NEW;
end;
$$;


ALTER FUNCTION "public"."sync_task_keep_to_current_pomodoro"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_send_push_on_pomodoro_finished"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."trigger_send_push_on_pomodoro_finished"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."trigger_send_push_on_pomodoro_finished"() IS 'Sends push notification via Edge Function when a pomodoro state changes to finished';



CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."api_keys" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."api_keys" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."documents" (
    "id" bigint NOT NULL,
    "content" "text",
    "metadata" "jsonb",
    "embedding" "extensions"."vector"(768)
);


ALTER TABLE "public"."documents" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."documents_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."documents_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."documents_id_seq" OWNED BY "public"."documents"."id";



CREATE TABLE IF NOT EXISTS "public"."flows" (
    "id" bigint NOT NULL,
    "time_session_id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "jornada_bloque" "text" NOT NULL,
    "jornada_limit_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."flows" OWNER TO "postgres";


ALTER TABLE "public"."flows" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."flows_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."inbox_actions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "source_notification_id" "uuid",
    "title" "text" NOT NULL,
    "description" "text",
    "action_type" "text" DEFAULT 'NONE'::"text",
    "action_payload" "jsonb" DEFAULT '{}'::"jsonb",
    "status" "text" DEFAULT 'pending'::"text",
    "priority" integer DEFAULT 1,
    "execution_count" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "completed_at" timestamp with time zone,
    CONSTRAINT "inbox_actions_action_type_check" CHECK (("action_type" = ANY (ARRAY['NONE'::"text", 'CREATE_TASK'::"text", 'REVIEW_NOTE'::"text", 'CREATE_LOG'::"text", 'AI_ATOMIZE'::"text"]))),
    CONSTRAINT "inbox_actions_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'completed'::"text", 'dismissed'::"text"])))
);


ALTER TABLE "public"."inbox_actions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."n8n_chat_histories" (
    "id" integer NOT NULL,
    "session_id" character varying(255) NOT NULL,
    "message" "jsonb" NOT NULL
);


ALTER TABLE "public"."n8n_chat_histories" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."n8n_chat_histories_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."n8n_chat_histories_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."n8n_chat_histories_id_seq" OWNED BY "public"."n8n_chat_histories"."id";



CREATE TABLE IF NOT EXISTS "public"."notification_templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "icon" "text",
    "link" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."notification_templates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pomodoros" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "started_at" timestamp with time zone,
    "expected_end" timestamp with time zone,
    "timelapse" integer DEFAULT 0 NOT NULL,
    "user_id" "uuid" NOT NULL,
    "state" "public"."pomodoro_state" DEFAULT 'idle'::"public"."pomodoro_state" NOT NULL,
    "finished_at" timestamp with time zone,
    "toggle_timeline" "jsonb",
    "cycle" bigint,
    "expected_duration" smallint DEFAULT '1500'::smallint NOT NULL,
    "type" "public"."pomodoro_type" DEFAULT 'focus'::"public"."pomodoro_type" NOT NULL,
    "time_session_id" bigint
);


ALTER TABLE "public"."pomodoros" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pomodoros_cycles" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "state" "public"."pomodoro_state",
    "user_id" "uuid",
    "required_tags" "text"[] DEFAULT '{focus,break,focus,long_break}'::"text"[]
);


ALTER TABLE "public"."pomodoros_cycles" OWNER TO "postgres";


ALTER TABLE "public"."pomodoros_cycles" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."pomodoros_cycles_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."pomodoros" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."pomodoros_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."pomodoros_tags" (
    "user_id" "uuid",
    "pomodoro" integer NOT NULL,
    "tag" integer NOT NULL
);


ALTER TABLE "public"."pomodoros_tags" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pomodoros_tasks" (
    "id" bigint NOT NULL,
    "pomodoro_id" bigint NOT NULL,
    "task_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."pomodoros_tasks" OWNER TO "postgres";


ALTER TABLE "public"."pomodoros_tasks" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."pomodoros_tasks_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "username" "text",
    "fullname" "text",
    "avatar_url" "text",
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "has_password" boolean DEFAULT false,
    "settings" "jsonb"
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."push_subscriptions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "subscription" "jsonb" NOT NULL,
    "device_info" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."push_subscriptions" OWNER TO "postgres";


COMMENT ON TABLE "public"."push_subscriptions" IS 'Stores Web Push subscription objects for each user device';



COMMENT ON COLUMN "public"."push_subscriptions"."subscription" IS 'JSON object from PushSubscription.toJSON() containing endpoint, keys.p256dh, keys.auth';



CREATE TABLE IF NOT EXISTS "public"."scheduled_notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "template_id" "uuid",
    "rrule" "text",
    "scheduled_at" timestamp with time zone NOT NULL,
    "last_executed_at" timestamp with time zone,
    "timezone" "text" DEFAULT 'UTC'::"text" NOT NULL,
    "payload_override" "jsonb",
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "action_type" "text" DEFAULT 'NONE'::"text",
    CONSTRAINT "scheduled_notifications_action_type_check" CHECK (("action_type" = ANY (ARRAY['NONE'::"text", 'CREATE_TASK'::"text", 'REVIEW_NOTE'::"text", 'CREATE_LOG'::"text", 'AI_ATOMIZE'::"text"]))),
    CONSTRAINT "scheduled_notifications_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'paused'::"text", 'completed'::"text"])))
);


ALTER TABLE "public"."scheduled_notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tags" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "type" "text",
    "label" "text" NOT NULL,
    "user_id" "uuid"
);


ALTER TABLE "public"."tags" OWNER TO "postgres";


ALTER TABLE "public"."tags" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."tags_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."task_templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "default_description" "text",
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."task_templates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."task_templates_tags" (
    "template_id" "uuid" NOT NULL,
    "tag_id" bigint NOT NULL
);


ALTER TABLE "public"."task_templates_tags" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tasks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "done" boolean DEFAULT false,
    "tag_id" integer,
    "pomodoro_id" integer,
    "archived" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "done_at" timestamp with time zone,
    "keep" boolean DEFAULT false,
    "stage" "public"."task_stage" DEFAULT 'backlog'::"public"."task_stage"
);


ALTER TABLE "public"."tasks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tasks_tags" (
    "user_id" "uuid",
    "task" "uuid" NOT NULL,
    "tag" integer NOT NULL
);


ALTER TABLE "public"."tasks_tags" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."time_sessions" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "mode" "public"."time_measurement_mode" NOT NULL,
    "state" "public"."pomodoro_state" DEFAULT 'idle'::"public"."pomodoro_state" NOT NULL,
    "started_at" timestamp with time zone,
    "finished_at" timestamp with time zone,
    "timelapse" integer DEFAULT 0 NOT NULL,
    "toggle_timeline" "jsonb" DEFAULT '[]'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."time_sessions" OWNER TO "postgres";


ALTER TABLE "public"."time_sessions" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."time_sessions_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."user_secrets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "name" "text" NOT NULL,
    "key_value" "text" NOT NULL,
    "iv" "text" NOT NULL,
    "tag" "text" NOT NULL,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."user_secrets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."webhook_trace" (
    "id" bigint NOT NULL,
    "pgmq_msg_id" bigint,
    "net_request_id" bigint,
    "processed_at" timestamp with time zone DEFAULT "now"(),
    "user_id" "uuid"
);


ALTER TABLE "public"."webhook_trace" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_webhook_status" WITH ("security_invoker"='on') AS
 SELECT "a"."msg_id",
    "a"."enqueued_at",
    ("a"."message" ->> 'event'::"text") AS "event_type",
    ("a"."message" ->> 'url'::"text") AS "target_url",
    "a"."message" AS "full_payload",
    "t"."processed_at",
    "t"."user_id",
    "r"."status_code",
    "r"."error_msg",
    "r"."content" AS "response_body"
   FROM (("pgmq"."a_pomodoro_webhooks" "a"
     JOIN "public"."webhook_trace" "t" ON (("a"."msg_id" = "t"."pgmq_msg_id")))
     LEFT JOIN "net"."_http_response" "r" ON (("t"."net_request_id" = "r"."id")))
  ORDER BY "a"."enqueued_at" DESC;


ALTER VIEW "public"."v_webhook_status" OWNER TO "postgres";


ALTER TABLE "public"."webhook_trace" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."webhook_trace_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE ONLY "public"."documents" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."documents_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."n8n_chat_histories" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."n8n_chat_histories_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."api_keys"
    ADD CONSTRAINT "api_keys_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."flows"
    ADD CONSTRAINT "flows_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inbox_actions"
    ADD CONSTRAINT "inbox_actions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."n8n_chat_histories"
    ADD CONSTRAINT "n8n_chat_histories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_templates"
    ADD CONSTRAINT "notification_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pomodoros_cycles"
    ADD CONSTRAINT "pomodoros_cycles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pomodoros"
    ADD CONSTRAINT "pomodoros_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pomodoros_tags"
    ADD CONSTRAINT "pomodoros_tags_pkey" PRIMARY KEY ("tag", "pomodoro");



ALTER TABLE ONLY "public"."pomodoros_tasks"
    ADD CONSTRAINT "pomodoros_tasks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pomodoros_tasks"
    ADD CONSTRAINT "pomodoros_tasks_pomodoro_id_task_id_key" UNIQUE ("pomodoro_id", "task_id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_username_key" UNIQUE ("username");



ALTER TABLE ONLY "public"."push_subscriptions"
    ADD CONSTRAINT "push_subscriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."push_subscriptions"
    ADD CONSTRAINT "push_subscriptions_user_id_subscription_key" UNIQUE ("user_id", "subscription");



ALTER TABLE ONLY "public"."scheduled_notifications"
    ADD CONSTRAINT "scheduled_notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tags"
    ADD CONSTRAINT "tags_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_templates"
    ADD CONSTRAINT "task_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_templates_tags"
    ADD CONSTRAINT "task_templates_tags_pkey" PRIMARY KEY ("template_id", "tag_id");



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tasks_tags"
    ADD CONSTRAINT "tasks_tags_pkey" PRIMARY KEY ("tag", "task");



ALTER TABLE ONLY "public"."time_sessions"
    ADD CONSTRAINT "time_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_secrets"
    ADD CONSTRAINT "user_secrets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."webhook_trace"
    ADD CONSTRAINT "webhook_trace_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_api_keys_user_id" ON "public"."api_keys" USING "btree" ("user_id");



CREATE INDEX "idx_pomodoros_cycle_id" ON "public"."pomodoros" USING "btree" ("cycle");



CREATE INDEX "idx_pomodoros_cycles_user_id" ON "public"."pomodoros_cycles" USING "btree" ("user_id");



CREATE INDEX "idx_pomodoros_tags_pomodoro_id" ON "public"."pomodoros_tags" USING "btree" ("pomodoro");



CREATE INDEX "idx_pomodoros_tags_user_id" ON "public"."pomodoros_tags" USING "btree" ("user_id");



CREATE INDEX "idx_pomodoros_tasks_task_id" ON "public"."pomodoros_tasks" USING "btree" ("task_id");



CREATE INDEX "idx_pomodoros_tasks_user_id" ON "public"."pomodoros_tasks" USING "btree" ("user_id");



CREATE INDEX "idx_pomodoros_user_id" ON "public"."pomodoros" USING "btree" ("user_id");



CREATE INDEX "idx_push_subscriptions_user_id" ON "public"."push_subscriptions" USING "btree" ("user_id");



CREATE INDEX "idx_tags_user_id" ON "public"."tags" USING "btree" ("user_id");



CREATE INDEX "idx_tasks_pomodoro_id" ON "public"."tasks" USING "btree" ("pomodoro_id");



CREATE INDEX "idx_tasks_tag_id" ON "public"."tasks" USING "btree" ("tag_id");



CREATE INDEX "idx_tasks_tags_task_id" ON "public"."tasks_tags" USING "btree" ("task");



CREATE INDEX "idx_tasks_tags_user_id" ON "public"."tasks_tags" USING "btree" ("user_id");



CREATE INDEX "idx_tasks_user_id" ON "public"."tasks" USING "btree" ("user_id");



CREATE UNIQUE INDEX "idx_unique_active_pomodoro_per_user" ON "public"."pomodoros" USING "btree" ("user_id") WHERE ("state" <> ALL (ARRAY['finished'::"public"."pomodoro_state", 'skipped'::"public"."pomodoro_state"]));



CREATE UNIQUE INDEX "idx_unique_active_time_session_per_user" ON "public"."time_sessions" USING "btree" ("user_id", "mode") WHERE ("state" <> ALL (ARRAY['finished'::"public"."pomodoro_state", 'skipped'::"public"."pomodoro_state"]));



CREATE UNIQUE INDEX "idx_user_secrets_unique_name" ON "public"."user_secrets" USING "btree" ("user_id", "name") WHERE ("user_id" IS NOT NULL);



CREATE INDEX "idx_user_secrets_user_id" ON "public"."user_secrets" USING "btree" ("user_id");



CREATE INDEX "idx_webhook_trace_user_id" ON "public"."webhook_trace" USING "btree" ("user_id");



CREATE INDEX "ix_inbox_actions_status" ON "public"."inbox_actions" USING "btree" ("status");



CREATE INDEX "ix_inbox_actions_user_id" ON "public"."inbox_actions" USING "btree" ("user_id");



CREATE INDEX "ix_scheduled_notifications_scheduled_at" ON "public"."scheduled_notifications" USING "btree" ("scheduled_at");



CREATE INDEX "ix_scheduled_notifications_status" ON "public"."scheduled_notifications" USING "btree" ("status");



CREATE INDEX "ix_scheduled_notifications_user_id" ON "public"."scheduled_notifications" USING "btree" ("user_id");



CREATE INDEX "n8n_chat_histories_session_id_idx" ON "public"."n8n_chat_histories" USING "btree" ("session_id");



CREATE UNIQUE INDEX "tags_label_system_idx" ON "public"."tags" USING "btree" ("label") WHERE ("user_id" IS NULL);



CREATE UNIQUE INDEX "tags_label_user_idx" ON "public"."tags" USING "btree" ("label", "user_id") WHERE ("user_id" IS NOT NULL);



CREATE UNIQUE INDEX "tags_type_system_idx" ON "public"."tags" USING "btree" ("type") WHERE ("user_id" IS NULL);



CREATE OR REPLACE TRIGGER "tasks_done_at_insert_trigger" BEFORE INSERT ON "public"."tasks" FOR EACH ROW EXECUTE FUNCTION "public"."set_tasks_done_at_insert"();



CREATE OR REPLACE TRIGGER "tasks_done_at_trigger" BEFORE UPDATE OF "done" ON "public"."tasks" FOR EACH ROW EXECUTE FUNCTION "public"."set_tasks_done_at"();



CREATE OR REPLACE TRIGGER "tr_carry_over_keep_tasks" AFTER INSERT ON "public"."pomodoros" FOR EACH ROW EXECUTE FUNCTION "public"."carry_over_keep_tasks"();



CREATE OR REPLACE TRIGGER "tr_reset_task_keep" BEFORE INSERT OR UPDATE OF "done", "archived" ON "public"."tasks" FOR EACH ROW EXECUTE FUNCTION "public"."handle_task_keep_reset"();



CREATE OR REPLACE TRIGGER "tr_sync_task_keep" AFTER UPDATE OF "keep" ON "public"."tasks" FOR EACH ROW WHEN (("old"."keep" IS DISTINCT FROM "new"."keep")) EXECUTE FUNCTION "public"."sync_task_keep_to_current_pomodoro"();



CREATE OR REPLACE TRIGGER "trigger_handle_enqueue_pomodoro_finished_webhook" AFTER UPDATE ON "public"."pomodoros" FOR EACH ROW EXECUTE FUNCTION "public"."handle_enqueue_pomodoro_finished_webhook"();



CREATE OR REPLACE TRIGGER "trigger_push_on_pomodoro_finished" AFTER UPDATE ON "public"."pomodoros" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_send_push_on_pomodoro_finished"();



CREATE OR REPLACE TRIGGER "trigger_sync_pomodoro_expected_end" BEFORE INSERT OR UPDATE OF "state", "toggle_timeline", "expected_duration" ON "public"."pomodoros" FOR EACH ROW EXECUTE FUNCTION "public"."sync_pomodoro_expected_end"();



CREATE OR REPLACE TRIGGER "trigger_task_done_webhook" AFTER UPDATE ON "public"."tasks" FOR EACH ROW EXECUTE FUNCTION "public"."handle_task_done_webhook"();



CREATE OR REPLACE TRIGGER "update_profile_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."api_keys"
    ADD CONSTRAINT "api_keys_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."flows"
    ADD CONSTRAINT "flows_time_session_id_fkey" FOREIGN KEY ("time_session_id") REFERENCES "public"."time_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."flows"
    ADD CONSTRAINT "flows_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."inbox_actions"
    ADD CONSTRAINT "inbox_actions_source_notification_id_fkey" FOREIGN KEY ("source_notification_id") REFERENCES "public"."scheduled_notifications"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."inbox_actions"
    ADD CONSTRAINT "inbox_actions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pomodoros"
    ADD CONSTRAINT "pomodoros_cycle_fkey" FOREIGN KEY ("cycle") REFERENCES "public"."pomodoros_cycles"("id");



ALTER TABLE ONLY "public"."pomodoros_cycles"
    ADD CONSTRAINT "pomodoros_cycles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pomodoros_tags"
    ADD CONSTRAINT "pomodoros_tags_pomodoro_fkey" FOREIGN KEY ("pomodoro") REFERENCES "public"."pomodoros"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pomodoros_tags"
    ADD CONSTRAINT "pomodoros_tags_tag_fkey" FOREIGN KEY ("tag") REFERENCES "public"."tags"("id");



ALTER TABLE ONLY "public"."pomodoros_tags"
    ADD CONSTRAINT "pomodoros_tags_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pomodoros_tasks"
    ADD CONSTRAINT "pomodoros_tasks_pomodoro_id_fkey" FOREIGN KEY ("pomodoro_id") REFERENCES "public"."pomodoros"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pomodoros_tasks"
    ADD CONSTRAINT "pomodoros_tasks_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pomodoros_tasks"
    ADD CONSTRAINT "pomodoros_tasks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pomodoros"
    ADD CONSTRAINT "pomodoros_time_session_id_fkey" FOREIGN KEY ("time_session_id") REFERENCES "public"."time_sessions"("id");



ALTER TABLE ONLY "public"."pomodoros"
    ADD CONSTRAINT "pomodoros_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."push_subscriptions"
    ADD CONSTRAINT "push_subscriptions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."scheduled_notifications"
    ADD CONSTRAINT "scheduled_notifications_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "public"."notification_templates"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."scheduled_notifications"
    ADD CONSTRAINT "scheduled_notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tags"
    ADD CONSTRAINT "tags_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_templates_tags"
    ADD CONSTRAINT "task_templates_tags_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "public"."tags"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_templates_tags"
    ADD CONSTRAINT "task_templates_tags_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "public"."task_templates"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_templates"
    ADD CONSTRAINT "task_templates_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_pomodoro_id_fkey" FOREIGN KEY ("pomodoro_id") REFERENCES "public"."pomodoros"("id");



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "public"."tags"("id");



ALTER TABLE ONLY "public"."tasks_tags"
    ADD CONSTRAINT "tasks_tags_tag_fkey" FOREIGN KEY ("tag") REFERENCES "public"."tags"("id");



ALTER TABLE ONLY "public"."tasks_tags"
    ADD CONSTRAINT "tasks_tags_task_fkey" FOREIGN KEY ("task") REFERENCES "public"."tasks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tasks_tags"
    ADD CONSTRAINT "tasks_tags_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."time_sessions"
    ADD CONSTRAINT "time_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."user_secrets"
    ADD CONSTRAINT "user_secrets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."webhook_trace"
    ADD CONSTRAINT "webhook_trace_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Authenticated users can create their own tasks" ON "public"."tasks" FOR INSERT TO "authenticated" WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND "public"."is_valid_personal_access_token"()));



CREATE POLICY "Authenticated users can delete their own tasks" ON "public"."tasks" FOR DELETE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND "public"."is_valid_personal_access_token"()));



CREATE POLICY "Authenticated users can read their own tasks" ON "public"."tasks" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND "public"."is_valid_personal_access_token"()));



CREATE POLICY "Authenticated users can update their own tasks" ON "public"."tasks" FOR UPDATE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND "public"."is_valid_personal_access_token"())) WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND "public"."is_valid_personal_access_token"()));



CREATE POLICY "Enable delete for own tags" ON "public"."tags" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Enable delete for users based on user_id" ON "public"."pomodoros" FOR DELETE USING ((( SELECT ( SELECT "auth"."uid"() AS "uid") AS "uid") = "user_id"));



CREATE POLICY "Enable delete for users based on user_id" ON "public"."pomodoros_tags" FOR DELETE USING ((( SELECT ( SELECT "auth"."uid"() AS "uid") AS "uid") = "user_id"));



CREATE POLICY "Enable delete for users based on user_id" ON "public"."tasks_tags" FOR DELETE USING ((( SELECT ( SELECT "auth"."uid"() AS "uid") AS "uid") = "user_id"));



CREATE POLICY "Enable insert for authenticated users only" ON "public"."pomodoros_cycles" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Enable insert for authenticated users only" ON "public"."pomodoros_tags" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Enable insert for own tags" ON "public"."tags" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Enable insert for users based on user_id" ON "public"."pomodoros" FOR INSERT WITH CHECK ((( SELECT ( SELECT "auth"."uid"() AS "uid") AS "uid") = "user_id"));



CREATE POLICY "Enable insert for users based on user_id" ON "public"."tasks_tags" FOR INSERT WITH CHECK ((( SELECT ( SELECT "auth"."uid"() AS "uid") AS "uid") = "user_id"));



CREATE POLICY "Enable read access for own tags" ON "public"."tags" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Enable update for own tags" ON "public"."tags" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Enable users and PAT to view cycles" ON "public"."pomodoros_cycles" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND "public"."is_valid_personal_access_token"()));



CREATE POLICY "Enable users and PAT to view pomodoros" ON "public"."pomodoros" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND "public"."is_valid_personal_access_token"()));



CREATE POLICY "Enable users and PAT to view pomodoros_tags" ON "public"."pomodoros_tags" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND "public"."is_valid_personal_access_token"()));



CREATE POLICY "Enable users and PAT to view tasks_tags" ON "public"."tasks_tags" FOR SELECT TO "authenticated" USING (((( SELECT ( SELECT "auth"."uid"() AS "uid") AS "uid") = "user_id") AND "public"."is_valid_personal_access_token"()));



CREATE POLICY "Enable users to edit their own data only" ON "public"."pomodoros" FOR UPDATE TO "authenticated" USING ((( SELECT ( SELECT "auth"."uid"() AS "uid") AS "uid") = "user_id"));



CREATE POLICY "Enable users to update their own data only" ON "public"."pomodoros_cycles" FOR UPDATE TO "authenticated" USING ((( SELECT ( SELECT "auth"."uid"() AS "uid") AS "uid") = "user_id"));



CREATE POLICY "Public profiles are viewable by everyone." ON "public"."profiles" FOR SELECT USING (true);



CREATE POLICY "Service role can manage documents" ON "public"."documents" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Users can delete own secrets" ON "public"."user_secrets" FOR DELETE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Users can delete tags for their own templates" ON "public"."task_templates_tags" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."task_templates"
  WHERE (("task_templates"."id" = "task_templates_tags"."template_id") AND ("task_templates"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can delete their own keys" ON "public"."api_keys" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can delete their own pomodoro tasks" ON "public"."pomodoros_tasks" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can delete their own templates" ON "public"."task_templates" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own secrets" ON "public"."user_secrets" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Users can insert tags for their own templates" ON "public"."task_templates_tags" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."task_templates"
  WHERE (("task_templates"."id" = "task_templates_tags"."template_id") AND ("task_templates"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can insert their own chat messages" ON "public"."n8n_chat_histories" FOR INSERT WITH CHECK ((("session_id")::"text" = (( SELECT "auth"."uid"() AS "uid"))::"text"));



CREATE POLICY "Users can insert their own pomodoro tasks" ON "public"."pomodoros_tasks" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can insert their own profile." ON "public"."profiles" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Users can insert their own templates" ON "public"."task_templates" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can manage own flows" ON "public"."flows" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can manage own inbox actions" ON "public"."inbox_actions" TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Users can manage own push subscriptions" ON "public"."push_subscriptions" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can manage own time_sessions" ON "public"."time_sessions" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can manage their own scheduled notifications" ON "public"."scheduled_notifications" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own secrets" ON "public"."user_secrets" FOR UPDATE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Users can update tags for their own templates" ON "public"."task_templates_tags" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."task_templates"
  WHERE (("task_templates"."id" = "task_templates_tags"."template_id") AND ("task_templates"."user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."task_templates"
  WHERE (("task_templates"."id" = "task_templates_tags"."template_id") AND ("task_templates"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can update their own profile." ON "public"."profiles" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Users can update their own templates" ON "public"."task_templates" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view notification_templates" ON "public"."notification_templates" FOR SELECT USING (true);



CREATE POLICY "Users can view own or community secrets" ON "public"."user_secrets" FOR SELECT TO "authenticated" USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR (("user_id" IS NULL) AND (( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"))));



CREATE POLICY "Users can view tags of their own templates" ON "public"."task_templates_tags" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."task_templates"
  WHERE (("task_templates"."id" = "task_templates_tags"."template_id") AND ("task_templates"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can view their own chat messages" ON "public"."n8n_chat_histories" FOR SELECT USING ((("session_id")::"text" = (( SELECT "auth"."uid"() AS "uid"))::"text"));



CREATE POLICY "Users can view their own keys" ON "public"."api_keys" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view their own pomodoro tasks" ON "public"."pomodoros_tasks" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view their own templates" ON "public"."task_templates" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view their own webhook traces" ON "public"."webhook_trace" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."api_keys" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."documents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."flows" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inbox_actions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."n8n_chat_histories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notification_templates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pomodoros" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pomodoros_cycles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pomodoros_tags" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pomodoros_tasks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."push_subscriptions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."scheduled_notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tags" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."task_templates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."task_templates_tags" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tasks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tasks_tags" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."time_sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_secrets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."webhook_trace" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";












GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";




































































































































































































































































































































































































































































































































GRANT ALL ON FUNCTION "public"."auto_finish_expired_pomodoros"() TO "anon";
GRANT ALL ON FUNCTION "public"."auto_finish_expired_pomodoros"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."auto_finish_expired_pomodoros"() TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_pomodoro_timelapse_sql"("p_started_at" timestamp with time zone, "p_toggle_timeline" "jsonb", "p_now" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_pomodoro_timelapse_sql"("p_started_at" timestamp with time zone, "p_toggle_timeline" "jsonb", "p_now" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_pomodoro_timelapse_sql"("p_started_at" timestamp with time zone, "p_toggle_timeline" "jsonb", "p_now" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_pomodoro_timelapse_sql"("p_started_at" timestamp with time zone, "p_toggle_timeline" "jsonb", "p_expected_duration" integer, "p_now" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_pomodoro_timelapse_sql"("p_started_at" timestamp with time zone, "p_toggle_timeline" "jsonb", "p_expected_duration" integer, "p_now" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_pomodoro_timelapse_sql"("p_started_at" timestamp with time zone, "p_toggle_timeline" "jsonb", "p_expected_duration" integer, "p_now" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."carry_over_keep_tasks"() TO "anon";
GRANT ALL ON FUNCTION "public"."carry_over_keep_tasks"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."carry_over_keep_tasks"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_enqueue_pomodoro_finished_webhook"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_enqueue_pomodoro_finished_webhook"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_enqueue_pomodoro_finished_webhook"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_task_done_webhook"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_task_done_webhook"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_task_done_webhook"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_task_keep_reset"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_task_keep_reset"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_task_keep_reset"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_user_password_update"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_user_password_update"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_user_password_update"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_valid_personal_access_token"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_valid_personal_access_token"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_valid_personal_access_token"() TO "service_role";






GRANT ALL ON FUNCTION "public"."process_notifications_worker"() TO "anon";
GRANT ALL ON FUNCTION "public"."process_notifications_worker"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_notifications_worker"() TO "service_role";



GRANT ALL ON FUNCTION "public"."process_webhooks"() TO "anon";
GRANT ALL ON FUNCTION "public"."process_webhooks"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_webhooks"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_tasks_done_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_tasks_done_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_tasks_done_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_tasks_done_at_insert"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_tasks_done_at_insert"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_tasks_done_at_insert"() TO "service_role";



GRANT ALL ON FUNCTION "public"."supabase_url"() TO "anon";
GRANT ALL ON FUNCTION "public"."supabase_url"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."supabase_url"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_pomodoro_expected_end"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_pomodoro_expected_end"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_pomodoro_expected_end"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_task_keep_to_current_pomodoro"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_task_keep_to_current_pomodoro"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_task_keep_to_current_pomodoro"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_send_push_on_pomodoro_finished"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_send_push_on_pomodoro_finished"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_send_push_on_pomodoro_finished"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";




































GRANT ALL ON TABLE "public"."api_keys" TO "anon";
GRANT ALL ON TABLE "public"."api_keys" TO "authenticated";
GRANT ALL ON TABLE "public"."api_keys" TO "service_role";



GRANT ALL ON TABLE "public"."documents" TO "anon";
GRANT ALL ON TABLE "public"."documents" TO "authenticated";
GRANT ALL ON TABLE "public"."documents" TO "service_role";



GRANT ALL ON SEQUENCE "public"."documents_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."documents_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."documents_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."flows" TO "anon";
GRANT ALL ON TABLE "public"."flows" TO "authenticated";
GRANT ALL ON TABLE "public"."flows" TO "service_role";



GRANT ALL ON SEQUENCE "public"."flows_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."flows_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."flows_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."inbox_actions" TO "anon";
GRANT ALL ON TABLE "public"."inbox_actions" TO "authenticated";
GRANT ALL ON TABLE "public"."inbox_actions" TO "service_role";



GRANT ALL ON TABLE "public"."n8n_chat_histories" TO "anon";
GRANT ALL ON TABLE "public"."n8n_chat_histories" TO "authenticated";
GRANT ALL ON TABLE "public"."n8n_chat_histories" TO "service_role";



GRANT ALL ON SEQUENCE "public"."n8n_chat_histories_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."n8n_chat_histories_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."n8n_chat_histories_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."notification_templates" TO "anon";
GRANT ALL ON TABLE "public"."notification_templates" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_templates" TO "service_role";



GRANT ALL ON TABLE "public"."pomodoros" TO "anon";
GRANT ALL ON TABLE "public"."pomodoros" TO "authenticated";
GRANT ALL ON TABLE "public"."pomodoros" TO "service_role";



GRANT ALL ON TABLE "public"."pomodoros_cycles" TO "anon";
GRANT ALL ON TABLE "public"."pomodoros_cycles" TO "authenticated";
GRANT ALL ON TABLE "public"."pomodoros_cycles" TO "service_role";



GRANT ALL ON SEQUENCE "public"."pomodoros_cycles_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."pomodoros_cycles_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."pomodoros_cycles_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."pomodoros_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."pomodoros_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."pomodoros_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."pomodoros_tags" TO "anon";
GRANT ALL ON TABLE "public"."pomodoros_tags" TO "authenticated";
GRANT ALL ON TABLE "public"."pomodoros_tags" TO "service_role";



GRANT ALL ON TABLE "public"."pomodoros_tasks" TO "anon";
GRANT ALL ON TABLE "public"."pomodoros_tasks" TO "authenticated";
GRANT ALL ON TABLE "public"."pomodoros_tasks" TO "service_role";



GRANT ALL ON SEQUENCE "public"."pomodoros_tasks_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."pomodoros_tasks_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."pomodoros_tasks_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."push_subscriptions" TO "anon";
GRANT ALL ON TABLE "public"."push_subscriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."push_subscriptions" TO "service_role";



GRANT ALL ON TABLE "public"."scheduled_notifications" TO "anon";
GRANT ALL ON TABLE "public"."scheduled_notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."scheduled_notifications" TO "service_role";



GRANT ALL ON TABLE "public"."tags" TO "anon";
GRANT ALL ON TABLE "public"."tags" TO "authenticated";
GRANT ALL ON TABLE "public"."tags" TO "service_role";



GRANT ALL ON SEQUENCE "public"."tags_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."tags_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."tags_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."task_templates" TO "anon";
GRANT ALL ON TABLE "public"."task_templates" TO "authenticated";
GRANT ALL ON TABLE "public"."task_templates" TO "service_role";



GRANT ALL ON TABLE "public"."task_templates_tags" TO "anon";
GRANT ALL ON TABLE "public"."task_templates_tags" TO "authenticated";
GRANT ALL ON TABLE "public"."task_templates_tags" TO "service_role";



GRANT ALL ON TABLE "public"."tasks" TO "anon";
GRANT ALL ON TABLE "public"."tasks" TO "authenticated";
GRANT ALL ON TABLE "public"."tasks" TO "service_role";



GRANT ALL ON TABLE "public"."tasks_tags" TO "anon";
GRANT ALL ON TABLE "public"."tasks_tags" TO "authenticated";
GRANT ALL ON TABLE "public"."tasks_tags" TO "service_role";



GRANT ALL ON TABLE "public"."time_sessions" TO "anon";
GRANT ALL ON TABLE "public"."time_sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."time_sessions" TO "service_role";



GRANT ALL ON SEQUENCE "public"."time_sessions_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."time_sessions_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."time_sessions_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."user_secrets" TO "anon";
GRANT ALL ON TABLE "public"."user_secrets" TO "authenticated";
GRANT ALL ON TABLE "public"."user_secrets" TO "service_role";



GRANT ALL ON TABLE "public"."webhook_trace" TO "anon";
GRANT ALL ON TABLE "public"."webhook_trace" TO "authenticated";
GRANT ALL ON TABLE "public"."webhook_trace" TO "service_role";



GRANT ALL ON TABLE "public"."v_webhook_status" TO "anon";
GRANT ALL ON TABLE "public"."v_webhook_status" TO "authenticated";
GRANT ALL ON TABLE "public"."v_webhook_status" TO "service_role";



GRANT ALL ON SEQUENCE "public"."webhook_trace_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."webhook_trace_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."webhook_trace_id_seq" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































