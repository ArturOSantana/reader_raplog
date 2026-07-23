-- Cria o bucket público `avatars` para fotos de perfil.
-- O arquivo é acessado por URL pública, então o bucket é configurado como público.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  2097152, -- 2 MiB
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- Política: usuário autenticado pode fazer upload apenas na própria pasta (userId/)
create policy "avatars: upload próprio"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Política: leitura pública (bucket já é público, mas RLS ainda se aplica)
create policy "avatars: leitura pública"
  on storage.objects for select
  to public
  using (bucket_id = 'avatars');
