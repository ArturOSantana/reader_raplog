-- Tabela de perfis de usuários
-- Execute no SQL Editor do Supabase Dashboard

CREATE TABLE IF NOT EXISTS profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name       TEXT,
  bio        TEXT,
  avatar_url TEXT,
  yearly_goal INTEGER CHECK (yearly_goal > 0),
  favorite_genre TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Atualiza updated_at automaticamente
CREATE OR REPLACE FUNCTION update_updated_at_profiles()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_profiles();

-- Row Level Security: usuário só acessa o próprio perfil
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário lê próprio perfil"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Usuário insere próprio perfil"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Usuário atualiza próprio perfil"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);
