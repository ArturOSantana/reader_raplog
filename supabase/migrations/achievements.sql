-- ============================================================
-- READLOG -- Achievements & User Achievements
-- Execute no SQL Editor do Supabase Dashboard
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- achievements
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS achievements (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key         TEXT UNIQUE NOT NULL,
  name        TEXT NOT NULL,
  description TEXT NOT NULL,
  icon        TEXT,
  xp_reward   INTEGER NOT NULL DEFAULT 0 CHECK (xp_reward >= 0),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "achievements: authenticated read" ON achievements;
CREATE POLICY "achievements: authenticated read"
  ON achievements FOR SELECT
  USING (auth.role() = 'authenticated');

-- ────────────────────────────────────────────────────────────
-- user_achievements
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_achievements (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  achievement_id UUID NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
  unlocked_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, achievement_id)
);

CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id        ON user_achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_achievement_id ON user_achievements(achievement_id);

ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_achievements: owner select" ON user_achievements;
DROP POLICY IF EXISTS "user_achievements: owner insert" ON user_achievements;
DROP POLICY IF EXISTS "user_achievements: owner delete" ON user_achievements;

CREATE POLICY "user_achievements: owner select" ON user_achievements FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "user_achievements: owner insert" ON user_achievements FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "user_achievements: owner delete" ON user_achievements FOR DELETE USING (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- SEED: conquistas padrao (idempotente)
-- ────────────────────────────────────────────────────────────
INSERT INTO achievements (key, name, description, xp_reward) VALUES
  ('first_session', 'Primeira Sessao',      'Registrou a primeira sessao de leitura.',           50),
  ('first_book',    'Primeiro Livro',       'Marcou o primeiro livro como lido.',                100),
  ('pages_100',     '100 Paginas',          'Leu 100 paginas no total.',                          75),
  ('pages_500',     '500 Paginas',          'Leu 500 paginas no total.',                         150),
  ('pages_1000',    '1000 Paginas',         'Leu 1000 paginas no total.',                        300),
  ('streak_3',      'Sequencia de 3 Dias',  'Leu por 3 dias consecutivos.',                       75),
  ('streak_7',      'Semana Completa',      'Leu por 7 dias consecutivos.',                      150),
  ('streak_30',     'Mes Completo',         'Leu por 30 dias consecutivos.',                     500),
  ('books_5',       '5 Livros Lidos',       'Concluiu 5 livros.',                                200),
  ('books_10',      '10 Livros Lidos',      'Concluiu 10 livros.',                               400),
  ('hours_10',      '10 Horas de Leitura',  'Acumulou 10 horas de leitura registradas.',         100),
  ('hours_100',     '100 Horas de Leitura', 'Acumulou 100 horas de leitura registradas.',        600),
  ('night_owl',     'Leitor Noturno',       'Registrou uma sessao entre meia-noite e 4h.',        50),
  ('speed_reader',  'Leitor Veloz',         'Leu mais de 60 paginas em uma unica sessao.',        75),
  ('annotator',     'Anotador',             'Criou 10 anotacoes ou destaques.',                  100)
ON CONFLICT (key) DO NOTHING;
