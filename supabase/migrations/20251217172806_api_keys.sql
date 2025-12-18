create table api_keys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  name text not null, -- Ejemplo: "Integración con Zapier"
  is_active boolean default true,
  created_at timestamptz default now()
);

-- Habilitar RLS
alter table api_keys enable row level security;

-- Política: El usuario puede ver sus propias keys
create policy "Users can view their own keys" 
on api_keys for select 
using (auth.uid() = user_id);

-- Política: Solo el usuario puede borrar (revocar) sus keys
create policy "Users can delete their own keys" 
on api_keys for delete 
using (auth.uid() = user_id);

create or replace function is_valid_personal_access_token()
returns boolean as $$
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
$$ language plpgsql security definer;