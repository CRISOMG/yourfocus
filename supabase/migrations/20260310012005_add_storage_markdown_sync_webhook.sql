CREATE UNIQUE INDEX push_subscriptions_user_id_subscription_key ON public.push_subscriptions USING btree (user_id, subscription);

CREATE TRIGGER tr_storage_objects_sync_markdown AFTER INSERT OR DELETE OR UPDATE ON storage.objects FOR EACH ROW EXECUTE FUNCTION supabase_functions.http_request('http://host.docker.internal:54321/functions/v1/sync-markdown', 'POST', '{"Content-Type":"application/json"}', '{}', '5000');


