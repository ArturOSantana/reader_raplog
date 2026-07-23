-- ============================================================
-- READLOG — Fix: políticas RLS de book_club_meetings
--
-- A migration original usava role IN ('admin', 'moderator'),
-- excluindo 'owner'. Recria as políticas usando is_club_manager,
-- que já cobre owner e admin.
-- ============================================================

DROP POLICY IF EXISTS "meetings: moderator insert" ON book_club_meetings;
DROP POLICY IF EXISTS "meetings: moderator update" ON book_club_meetings;
DROP POLICY IF EXISTS "meetings: moderator delete" ON book_club_meetings;

CREATE POLICY "meetings: manager insert"
  ON book_club_meetings FOR INSERT
  WITH CHECK (
    is_club_manager(club_id, auth.uid())
  );

CREATE POLICY "meetings: manager update"
  ON book_club_meetings FOR UPDATE
  USING (
    is_club_manager(club_id, auth.uid())
  );

CREATE POLICY "meetings: manager delete"
  ON book_club_meetings FOR DELETE
  USING (
    is_club_manager(club_id, auth.uid())
  );
