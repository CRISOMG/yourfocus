set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_storage_sync_markdown()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_url text;
  v_payload jsonb;
  v_request_id bigint;
  v_service_key text;
BEGIN
  -- 1. Intentar obtener de PostgREST el request info (funciona cuando se sube por API/App)
  v_url := public.supabase_url();
  
  -- 2. Fallback a custom setting de postgres (ej. alter database SET app.settings.supabase_url TO ...)
  IF v_url IS NULL OR v_url = '' THEN
     v_url := current_setting('app.settings.supabase_url', true);
  END IF;

  -- 3. Fallback de desarrollo local por defecto
  IF v_url IS NULL OR v_url = '' THEN
     v_url := 'http://host.docker.internal:54321';
  END IF;

  -- Obtener Service Role Key para poder llamar a Edge Functions que verifican JWT
  SELECT decrypted_secret INTO v_service_key 
  FROM vault.decrypted_secrets 
  WHERE name = 'service_role_key' 
  LIMIT 1;

  -- Construir el Payload del webhook estándar de Supabase
  v_payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', row_to_json(NEW),
    'old_record', row_to_json(OLD)
  );

  -- Disparar la Edge Function usando pg_net nativo
  SELECT net.http_post(
      url := v_url || '/functions/v1/sync-markdown',
      body := v_payload,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || COALESCE(v_service_key, 'MISSING_KEY')
      )
  ) INTO v_request_id;

  RETURN NEW;
END;
$function$
;

drop trigger if exists "tr_storage_objects_sync_markdown" on "storage"."objects";

CREATE TRIGGER tr_storage_objects_sync_markdown AFTER INSERT OR DELETE OR UPDATE ON storage.objects FOR EACH ROW EXECUTE FUNCTION public.handle_storage_sync_markdown();


