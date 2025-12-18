create table tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  title text not null,
  description text,
  done boolean default false,
  tag_id integer references public.tags(id) not null,
  pomodoro_id integer references public.pomodoros(id) not null,
  archived boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Habilitar RLS
alter table tasks enable row level security;

-- 1. SELECT: Correcto (Usa USING)
create policy "Authenticated users can read their own tasks" 
on tasks for select 
to authenticated
using (auth.uid() = user_id AND is_valid_personal_access_token());

-- 2. INSERT: Corregido (Cambio de USING a WITH CHECK)
create policy "Authenticated users can create their own tasks" 
on tasks for insert 
to authenticated
with check (auth.uid() = user_id AND is_valid_personal_access_token());

-- 3. UPDATE: Blindado (Agregado WITH CHECK)
create policy "Authenticated users can update their own tasks" 
on tasks for update 
to authenticated
using (auth.uid() = user_id AND is_valid_personal_access_token())      -- Puedo tocar lo que es mío
with check (auth.uid() = user_id AND is_valid_personal_access_token()); -- Sigue siendo mío después del cambio

-- 4. DELETE: Correcto (Usa USING)
create policy "Authenticated users can delete their own tasks" 
on tasks for delete 
to authenticated
using (auth.uid() = user_id AND is_valid_personal_access_token());



create policy "Auth users and PAT can read tags" 
on tags for select 
to authenticated
using (auth.uid() = user_id AND is_valid_personal_access_token());


create policy "Auth users and PAT can insert tags" 
on tags for insert 
to authenticated
with check (auth.uid() = user_id AND is_valid_personal_access_token());