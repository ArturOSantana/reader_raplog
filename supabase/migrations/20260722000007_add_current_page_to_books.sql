-- ============================================================
-- READLOG — Migration: adiciona current_page à tabela books
-- Execute no SQL Editor do Supabase Dashboard
-- ============================================================

ALTER TABLE books
  ADD COLUMN IF NOT EXISTS current_page integer CHECK (current_page >= 0);
