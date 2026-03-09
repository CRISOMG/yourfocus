
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
$$ SET search_path = public;


ALTER FUNCTION "public"."auto_finish_expired_pomodoros"() OWNER TO "postgres";


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
$$ SET search_path = public;


ALTER FUNCTION "public"."calculate_pomodoro_timelapse_sql"("p_started_at" timestamp with time zone, "p_toggle_timeline" "jsonb", "p_expected_duration" integer, "p_now" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."supabase_url"() RETURNS "text"
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public'
    AS $$
SELECT current_setting('request.base_url', true);
$$;


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
$$ SET search_path = public;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";








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
$$ SET search_path = public;


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
$$ SET search_path = public;


ALTER FUNCTION "public"."is_valid_personal_access_token"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_pomodoro_expected_end"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
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
    $$ SET search_path = public;


ALTER FUNCTION "public"."sync_pomodoro_expected_end"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ SET search_path = public;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";



CREATE OR REPLACE TRIGGER "update_profile_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();

CREATE OR REPLACE TRIGGER "trigger_sync_pomodoro_expected_end" BEFORE INSERT OR UPDATE OF "state", "toggle_timeline", "expected_duration" ON "public"."pomodoros" FOR EACH ROW EXECUTE FUNCTION "public"."sync_pomodoro_expected_end"();
GRANT ALL ON FUNCTION "public"."auto_finish_expired_pomodoros"() TO "anon";
GRANT ALL ON FUNCTION "public"."auto_finish_expired_pomodoros"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."auto_finish_expired_pomodoros"() TO "service_role";

GRANT ALL ON FUNCTION "public"."calculate_pomodoro_timelapse_sql"("p_started_at" timestamp with time zone, "p_toggle_timeline" "jsonb", "p_expected_duration" integer, "p_now" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_pomodoro_timelapse_sql"("p_started_at" timestamp with time zone, "p_toggle_timeline" "jsonb", "p_expected_duration" integer, "p_now" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_pomodoro_timelapse_sql"("p_started_at" timestamp with time zone, "p_toggle_timeline" "jsonb", "p_expected_duration" integer, "p_now" timestamp with time zone) TO "service_role";

GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";







GRANT ALL ON FUNCTION "public"."handle_user_password_update"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_user_password_update"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_user_password_update"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_valid_personal_access_token"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_valid_personal_access_token"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_valid_personal_access_token"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_pomodoro_expected_end"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_pomodoro_expected_end"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_pomodoro_expected_end"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";




-- Function to reset keep on done/archive
create or replace function public.handle_task_keep_reset()
returns trigger as $$
begin
  if NEW.done = true or NEW.archived = true then
    NEW.keep = false;
  end if;
  return NEW;
end;
$$ language plpgsql SET search_path = public;

create trigger tr_reset_task_keep
before insert or update of done, archived on public.tasks
for each row
execute function public.handle_task_keep_reset();


-- pomodoros_tasks functions removed in favor of temporal logic

CREATE OR REPLACE FUNCTION public.set_tasks_done_at()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;
-- Also for initial inserts if done starts as true
CREATE OR REPLACE FUNCTION public.set_tasks_done_at_insert()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.done = true THEN
    NEW.done_at = now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- Trigger to call the function
CREATE TRIGGER tasks_done_at_trigger
BEFORE UPDATE OF done ON "public"."tasks"
FOR EACH ROW
EXECUTE FUNCTION public.set_tasks_done_at();


CREATE TRIGGER tasks_done_at_insert_trigger
BEFORE INSERT ON "public"."tasks"
FOR EACH ROW
EXECUTE FUNCTION public.set_tasks_done_at_insert();

-- carry over tasks and sync triggers removed in favor of temporal logic
CREATE OR REPLACE TRIGGER "on_auth_user_created" AFTER INSERT ON "auth"."users" FOR EACH ROW EXECUTE FUNCTION public."handle_new_user"();

DROP TRIGGER IF EXISTS on_auth_user_updated_password ON auth.users;
CREATE TRIGGER on_auth_user_updated_password
AFTER UPDATE OF encrypted_password ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_user_password_update();
-- #region New Functions
CREATE OR REPLACE FUNCTION "public"."match_documents"("query_embedding" "extensions"."vector", "match_count" integer DEFAULT 10, "filter" "jsonb" DEFAULT '{}'::"jsonb") RETURNS TABLE("id" bigint, "content" "text", "metadata" "jsonb", "similarity" double precision)
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'extensions'
    AS $$
BEGIN
  RETURN QUERY
  SELECT documents.id, documents.content, documents.metadata, 1 - (documents.embedding <=> query_embedding) AS similarity
  FROM documents WHERE documents.metadata @> filter ORDER BY documents.embedding <=> query_embedding LIMIT match_count;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."handle_user_password_update"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER SET "search_path" TO 'public'
    AS $$
BEGIN
  UPDATE public.profiles SET has_password = (NEW.encrypted_password IS NOT NULL) WHERE id = NEW.id;
  RETURN NEW;
END;
$$;

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
-- #region OKR Progress Calculation
CREATE OR REPLACE FUNCTION public.calculate_kr_progress_on_pomodoro_finish()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_calculate_kr_progress_on_pomodoro_finish ON public.pomodoros;
CREATE TRIGGER tr_calculate_kr_progress_on_pomodoro_finish
AFTER UPDATE OF state ON public.pomodoros
FOR EACH ROW
EXECUTE FUNCTION public.calculate_kr_progress_on_pomodoro_finish();

CREATE OR REPLACE FUNCTION public.calculate_kr_progress_on_note_tag()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_calculate_kr_progress_on_note_tag ON public.notes_tags;
CREATE TRIGGER tr_calculate_kr_progress_on_note_tag
AFTER INSERT ON public.notes_tags
FOR EACH ROW
EXECUTE FUNCTION public.calculate_kr_progress_on_note_tag();
-- #endregion

-- #endregion
