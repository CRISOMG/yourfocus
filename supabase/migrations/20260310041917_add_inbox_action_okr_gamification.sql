alter table "public"."inbox_actions" drop constraint "inbox_actions_action_type_check";

alter table "public"."inbox_actions" add constraint "inbox_actions_action_type_check" CHECK ((action_type = ANY (ARRAY['NONE'::text, 'CREATE_TASK'::text, 'REVIEW_NOTE'::text, 'CREATE_LOG'::text, 'AI_ATOMIZE'::text, 'OKR_PROGRESS'::text]))) not valid;

alter table "public"."inbox_actions" validate constraint "inbox_actions_action_type_check";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_okr_progress_celebration()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_diff numeric;
    v_objective_title text;
    v_user_id uuid;
BEGIN
    -- Only trigger if the current_value has actually increased
    IF NEW.current_value > OLD.current_value THEN
        v_diff := NEW.current_value - OLD.current_value;
        
        -- Get the objective details
        SELECT o.title, o.user_id INTO v_objective_title, v_user_id
        FROM public.objectives o
        WHERE o.id = NEW.objective_id;

        -- Insert into inbox_actions for the UI Toast / Feed & Chat integration
        INSERT INTO public.inbox_actions (
            user_id,
            title,
            description,
            action_type,
            action_payload,
            priority
        ) VALUES (
            v_user_id,
            'Progreso OKR: ' || NEW.title,
            '¡Sumaste ' || v_diff::text || ' de progreso a "' || v_objective_title || '"! 🚀',
            'OKR_PROGRESS',
            jsonb_build_object(
                'key_result_id', NEW.id,
                'objective_id', NEW.objective_id,
                'diff', v_diff,
                'new_value', NEW.current_value,
                'target_value', NEW.target_value
            ),
            1
        );
    END IF;
    RETURN NEW;
END;
$function$
;

CREATE TRIGGER tr_okr_progress_celebration AFTER UPDATE OF current_value ON public.key_results FOR EACH ROW EXECUTE FUNCTION public.handle_okr_progress_celebration();


