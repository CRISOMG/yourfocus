-- Function to calculate KR progress when a task is marked as done
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
            JOIN public.tasks_tags tt ON tt.tag = krt.tag_id
            WHERE o.user_id = NEW.user_id
              AND tt.task = NEW.id
              AND kr.metric_type = 'COUNT_ATOMIC'
        LOOP
            UPDATE public.key_results 
            SET current_value = current_value + (1 * v_kr.weight)
            WHERE id = v_kr.id;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$function$;

-- Trigger for task completion
DROP TRIGGER IF EXISTS tr_calculate_kr_progress_on_task_done ON public.tasks;
CREATE TRIGGER tr_calculate_kr_progress_on_task_done 
AFTER UPDATE OF stage, done ON public.tasks 
FOR EACH ROW 
EXECUTE FUNCTION public.calculate_kr_progress_on_task_done();
