-- ── notification_items ────────────────────────────────────────────────────────
-- Central de notificações: inbox persistido por usuário.
-- Categorias: reading | streak | goals | clubs | friends | calendar | achievements | system

create table if not exists notification_items (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users(id) on delete cascade,
  category    text        not null check (category in (
                            'reading', 'streak', 'goals', 'clubs',
                            'friends', 'calendar', 'achievements', 'system'
                          )),
  title       text        not null,
  body        text        not null,
  is_read     boolean     not null default false,
  created_at  timestamptz not null default now()
);

-- Índice para busca rápida por usuário + não lidos
create index if not exists notification_items_user_unread_idx
  on notification_items(user_id, is_read)
  where is_read = false;

-- Índice para listagem por data
create index if not exists notification_items_user_created_idx
  on notification_items(user_id, created_at desc);

-- RLS
alter table notification_items enable row level security;

create policy "Usuário vê apenas suas notificações"
  on notification_items for select
  using (auth.uid() = user_id);

create policy "Usuário cria suas próprias notificações"
  on notification_items for insert
  with check (auth.uid() = user_id);

create policy "Usuário atualiza suas notificações"
  on notification_items for update
  using (auth.uid() = user_id);

create policy "Usuário exclui suas notificações"
  on notification_items for delete
  using (auth.uid() = user_id);

-- Limpeza automática: mantém apenas os últimos 200 itens por usuário
-- (executado no momento do insert via trigger)
create or replace function trim_notification_items()
returns trigger
language plpgsql
security definer
as $$
begin
  delete from notification_items
  where user_id = new.user_id
    and id not in (
      select id from notification_items
      where user_id = new.user_id
      order by created_at desc
      limit 200
    );
  return new;
end;
$$;

create or replace trigger trim_notifications_after_insert
  after insert on notification_items
  for each row execute function trim_notification_items();
