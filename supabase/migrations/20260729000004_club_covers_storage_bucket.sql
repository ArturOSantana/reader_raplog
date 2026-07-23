-- Cria o bucket público `club-covers` para capas dos clubes de leitura.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'club-covers',
  'club-covers',
  true,
  2097152, -- 2 MiB
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- Política: somente o dono do clube pode fazer upload na pasta do clube (clubId/)
-- A verificação de ownership é feita via RLS da tabela book_clubs.
create policy "club-covers: upload pelo dono"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'club-covers'
    and exists (
      select 1 from public.book_clubs
      where id::text = (storage.foldername(name))[1]
        and admin_id = auth.uid()
    )
  );

-- Política: leitura pública
create policy "club-covers: leitura pública"
  on storage.objects for select
  to public
  using (bucket_id = 'club-covers');
