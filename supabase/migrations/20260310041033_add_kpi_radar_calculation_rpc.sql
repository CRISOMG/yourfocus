set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.get_user_kpi_stats(p_timeframe_days integer DEFAULT 7)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
    v_enfoque int;
    v_agencia int;
    v_curiosidad int;
    v_interes int;
    v_competencia numeric;
    v_lucidez int;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Enfoque: Focus Pomodoros completed in the timeframe
    SELECT count(*) INTO v_enfoque
    FROM public.pomodoros
    WHERE user_id = v_user_id
      AND type = 'focus'
      AND state = 'finished'
      AND created_at >= (now() - (p_timeframe_days || ' days')::interval);

    -- Agencia: Tasks completed (using updated_at or done_at if available)
    SELECT count(*) INTO v_agencia
    FROM public.tasks
    WHERE user_id = v_user_id
      AND (stage = 'done' OR done = true)
      AND updated_at >= (now() - (p_timeframe_days || ' days')::interval);

    -- Curiosidad: Notes (Second Brain markdown) created
    SELECT count(*) INTO v_curiosidad
    FROM public.notes
    WHERE user_id = v_user_id
      AND created_at >= (now() - (p_timeframe_days || ' days')::interval);

    -- Interés: Unique tags used across activities in timeframe
    WITH user_recent_tags AS (
        SELECT tag_id FROM public.tasks WHERE user_id = v_user_id AND updated_at >= (now() - (p_timeframe_days || ' days')::interval) AND tag_id IS NOT NULL
        UNION
        SELECT tag FROM public.pomodoros_tags pt JOIN public.pomodoros p ON pt.pomodoro = p.id WHERE p.user_id = v_user_id AND p.created_at >= (now() - (p_timeframe_days || ' days')::interval)
        UNION
        SELECT tag_id FROM public.notes_tags nt JOIN public.notes n ON nt.note_id = n.id WHERE n.user_id = v_user_id AND n.created_at >= (now() - (p_timeframe_days || ' days')::interval)
    )
    SELECT count(*) INTO v_interes FROM user_recent_tags;

    -- Competencia: Average progress of active Key Results (0-100 score)
    SELECT COALESCE(avg(
        CASE 
            WHEN target_value = 0 THEN 0 
            ELSE LEAST(current_value / target_value, 1.0) * 100 
        END
    ), 0) INTO v_competencia
    FROM public.key_results kr
    JOIN public.objectives o ON kr.objective_id = o.id
    WHERE o.user_id = v_user_id;

    -- Lucidez: Consistency (Distinct active days using time_sessions)
    SELECT count(DISTINCT date_trunc('day', created_at)) INTO v_lucidez
    FROM public.time_sessions
    WHERE user_id = v_user_id
      AND created_at >= (now() - (p_timeframe_days || ' days')::interval);

    RETURN jsonb_build_object(
        'enfoque', v_enfoque,
        'agencia', v_agencia,
        'curiosidad', v_curiosidad,
        'interes', v_interes,
        'competencia', round(v_competencia::numeric, 2),
        'lucidez', v_lucidez
    );
END;
$function$
;


