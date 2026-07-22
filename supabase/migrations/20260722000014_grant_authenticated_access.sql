-- ============================================================
-- Garante que o role `authenticated` tem permissão de acesso
-- às tabelas usadas pelo app (necessário quando
-- auto_expose_new_tables não está habilitado).
-- ============================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE profiles          TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE friends           TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE friend_requests   TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE social_feed       TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE feed_likes        TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE book_clubs        TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE book_club_members TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE book_club_meetings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE meeting_rsvps     TO authenticated;
