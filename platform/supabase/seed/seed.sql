-- ============================================================
-- Lumen Platform — Seed: dados de bootstrap
-- ============================================================

-- ── Feature Flags (spec §19) ──────────────────────────────
insert into feature_flags (key, description, enabled, rollout_percent, target_roles) values
  ('ai_suggestions',      'Sugestões de livros por IA (V2)',                   false, 0,   '{}'),
  ('goodreads_import',    'Importação via CSV do Goodreads (V2)',               false, 0,   '{"premium"}'),
  ('wrapped_annual',      'Estatísticas anuais estilo Wrapped (V2)',            false, 0,   '{}'),
  ('mfa_users',           'MFA opcional para usuários (V2)',                    false, 0,   '{"premium"}'),
  ('passkey_auth',        'Autenticação por Passkey/WebAuthn (V2)',             false, 0,   '{}'),
  ('push_advanced',       'Push Notifications avançadas (V2)',                  false, 0,   '{}'),
  ('product_analytics',   'Analytics de produto com eventos granulares',        false, 0,   '{"admin","super_admin"}'),
  ('public_api',          'API pública OAuth (V3)',                             false, 0,   '{}'),
  ('verified_authors',    'Autores verificados (V3)',                           false, 0,   '{}'),
  ('gift_code',           'Gift Code para assinatura Premium (V3)',             false, 0,   '{}'),
  ('multi_language',      'Suporte multi-idioma (V3)',                          false, 0,   '{}'),
  ('new_feed_algo',       'Novo algoritmo de feed social (teste A/B)',          false, 5,   '{}'),
  ('club_polls',          'Enquetes em clubes de leitura',                      false, 0,   '{}'),
  ('reading_challenges',  'Desafios e maratonas de leitura (V3)',               false, 0,   '{}'),
  ('book_marketplace',    'Marketplace de listas (V3)',                         false, 0,   '{}')
on conflict (key) do nothing;

-- ── Conquistas / Achievements (spec §22 V1) ──────────────
insert into achievements (key, name, description, icon, xp_reward) values
  -- Primeiros passos
  ('first_book',        'Primeiro Livro',       'Adicionou seu primeiro livro à biblioteca',      '📖',  50),
  ('first_session',     'Primeira Sessão',      'Completou sua primeira sessão de leitura',       '⏱',   50),
  ('first_note',        'Primeiro Destaque',    'Fez sua primeira anotação',                      '✍️',  30),
  ('first_review',      'Primeira Resenha',     'Escreveu sua primeira resenha',                  '⭐',   50),
  ('first_club',        'Primeiro Clube',       'Entrou em um clube de leitura',                  '🏛️',  80),
  -- Streaks (spec §1: core loop)
  ('streak_3',          'Em Ritmo',             'Manteve 3 dias de streak',                       '🔥',  30),
  ('streak_7',          'Semana Completa',       'Manteve 7 dias de streak',                      '🔥', 100),
  ('streak_30',         'Mês de Leitura',       'Manteve 30 dias de streak',                      '🔥', 300),
  ('streak_100',        'Centenário',           'Manteve 100 dias de streak',                     '🔥', 500),
  ('streak_365',        'Leitor do Ano',        'Manteve 365 dias de streak',                     '🔥',1000),
  -- Livros lidos
  ('books_5',           '5 Livros',             'Concluiu 5 livros',                              '📚',  100),
  ('books_10',          '10 Livros',            'Concluiu 10 livros',                             '📚',  200),
  ('books_25',          '25 Livros',            'Concluiu 25 livros',                             '📚',  400),
  ('books_50',          '50 Livros',            'Concluiu 50 livros',                             '📚',  600),
  ('books_100',         'Centena de Livros',    'Concluiu 100 livros',                            '📚', 1000),
  -- Páginas lidas
  ('pages_100',         '100 Páginas',          'Leu 100 páginas no total',                       '📄',   30),
  ('pages_1000',        '1.000 Páginas',        'Leu 1.000 páginas no total',                     '📄',  100),
  ('pages_10000',       '10.000 Páginas',       'Leu 10.000 páginas no total',                    '📄',  300),
  ('pages_50000',       '50.000 Páginas',       'Leu 50.000 páginas no total',                    '📄',  500),
  -- Tempo de leitura
  ('hours_10',          '10 Horas',             'Acumulou 10 horas de leitura',                   '⏳',   80),
  ('hours_50',          '50 Horas',             'Acumulou 50 horas de leitura',                   '⏳',  200),
  ('hours_100',         '100 Horas',            'Acumulou 100 horas de leitura',                  '⏳',  400),
  ('hours_500',         '500 Horas',            'Acumulou 500 horas de leitura',                  '⏳',  800),
  -- Social
  ('club_active',       'Participante Ativo',   'Fez 10 check-ins em clubes',                     '👥',   80),
  ('club_owner',        'Fundador',             'Criou um clube de leitura',                      '🏛️', 150),
  ('reviews_10',        'Crítico Literário',    'Escreveu 10 resenhas',                           '⭐',  200),
  ('followed_10',       'Influente',            'Ganhou 10 seguidores',                           '👤',  100),
  -- Diversidade de leituras
  ('genre_3',           'Leitor Eclético',      'Leu livros de 3 gêneros diferentes',             '🎭',  100),
  ('genre_6',           'Explorador',           'Leu livros de 6 gêneros diferentes',             '🌍',  200),
  ('author_5',          'Fã Dedicado',          'Leu 5 livros do mesmo autor',                    '✒️',  150),
  -- Metas
  ('goal_week',         'Meta Semanal',         'Atingiu a meta de leitura semanal pela 1ª vez',  '🎯',   80),
  ('goal_month',        'Meta Mensal',          'Atingiu a meta de leitura mensal pela 1ª vez',   '🎯',  150),
  ('goal_year',         'Meta Anual',           'Atingiu a meta de livros anuais',                '🎯',  500),
  -- Especiais
  ('early_adopter',     'Early Adopter',        'Entrou na plataforma durante o beta',            '🚀',  200),
  ('night_owl',         'Coruja da Noite',      'Leu entre meia-noite e 4h da manhã',             '🦉',   50),
  ('speed_reader',      'Leitor Rápido',        'Leu mais de 60 páginas em uma sessão',           '⚡',   80),
  ('marathon',          'Maratonista',          'Sessão de leitura com mais de 3 horas',          '🏃',  120)
on conflict (key) do nothing;
