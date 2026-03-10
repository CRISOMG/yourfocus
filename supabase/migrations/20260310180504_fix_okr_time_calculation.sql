-- Update OKR Engine to calculate pomodoro progress using toggle_timeline and integer minutes

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
        
        -- Convert to whole minutes (using floor to be conservative, or round)
        -- The user asked for "minutos totales" as "numeros enteros"
        v_minutes_invested := FLOOR(v_seconds_invested::numeric / 60.0)::INTEGER;

        IF v_minutes_invested > 0 OR 1=1 THEN -- We still want to count the atomic even if 0 minutes
            FOR v_kr IN
                SELECT kr.id, krt.weight, kr.metric_type
                FROM public.key_results kr
                JOIN public.key_result_tags krt ON kr.id = krt.key_result_id
                JOIN public.pomodoros_tags pt ON pt.tag = krt.tag_id
                WHERE pt.pomodoro = NEW.id
            LOOP
                IF v_kr.metric_type = 'COUNT_ATOMIC' THEN
                    UPDATE public.key_results 
                    SET current_value = current_value + (1 * v_kr.weight)
                    WHERE id = v_kr.id;
                ELSIF v_kr.metric_type = 'TIME_INVESTMENT' AND v_minutes_invested > 0 THEN
                    UPDATE public.key_results 
                    SET current_value = current_value + (v_minutes_invested * v_kr.weight)
                    WHERE id = v_kr.id;
                END IF;
            END LOOP;
        END IF;
    END IF;
    RETURN NEW;
END;
$function$;

-- Saneamiento de datos: Convertir valores actuales a enteros (FLOOR)
UPDATE public.key_results
SET current_value = FLOOR(current_value)
WHERE metric_type = 'TIME_INVESTMENT';
