set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.calculate_kr_progress_on_task_done()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_kr RECORD;
BEGIN
    -- Only trigger when stage changes to 'done'
    IF (NEW.stage = 'done' AND (OLD.stage IS NULL OR OLD.stage != 'done')) OR (NEW.done = true AND (OLD.done IS NULL OR OLD.done = false)) THEN
        FOR v_kr IN
            SELECT kr.id, krt.weight
            FROM public.key_results kr
            JOIN public.objectives o ON kr.objective_id = o.id
            JOIN public.key_result_tags krt ON kr.id = krt.key_result_id
            WHERE o.user_id = NEW.user_id
              AND kr.metric_type = 'COUNT_ATOMIC'
              AND (
                  krt.tag_id = NEW.tag_id
                  OR EXISTS (
                      SELECT 1 FROM public.tasks_tags tt 
                      WHERE tt.task = NEW.id AND tt.tag = krt.tag_id
                  )
              )
        LOOP
            UPDATE public.key_results 
            SET current_value = current_value + (1 * v_kr.weight)
            WHERE id = v_kr.id;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$function$
;


